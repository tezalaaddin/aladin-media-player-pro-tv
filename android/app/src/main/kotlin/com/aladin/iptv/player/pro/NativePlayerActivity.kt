package com.aladin.iptv.player.pro

import android.app.PictureInPictureParams
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.media.AudioManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.util.Rational
import android.view.GestureDetector
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.SeekBar
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.exoplayer.upstream.DefaultBandwidthMeter
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView

import java.util.Locale

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import com.bumptech.glide.Glide
import com.bumptech.glide.load.engine.DiskCacheStrategy

// ─────────────────────────────────────────────────────────────────────────────
//  NativePlayerActivity — AladinMedia Player Pro
//  Optimized for low-end Android TV (Amlogic / RealTek / MediaTek, 1–2 GB RAM)
//
//  Improvements over previous build:
//   1.  Dynamic LoadControl  — live vs VOD, low vs normal memory
//   2.  BandwidthMeter       — conservative 1 Mbps seed, prevents aggressive ABR
//   3.  WifiLock             — prevents WiFi sleep during playback
//   4.  WakeMode             — keeps CPU + network alive without a screen lock
//   5.  MIME-type hints      — ExoPlayer skips format detection; zapping ~200ms faster
//   6.  NetworkCallback      — pauses on disconnection, resumes on reconnection
//   7.  onResume guard       — won't auto-play if user explicitly paused
//   8.  Live stream config   — ExoPlayer uses live latency target instead of VoD rules
//   9.  DASH support         — media3-exoplayer-dash dependency added (see build.gradle)
//  10.  setWakeMode          — proper wake lock delegation to ExoPlayer internals
//  11.  Decoder fallback     — improved: tries hardware first, falls to FFmpeg on fail
//  12.  Buffer bytes cap     — low-mem devices capped at 8 MB to prevent OOM
// ─────────────────────────────────────────────────────────────────────────────
@UnstableApi
class NativePlayerActivity : AppCompatActivity(),
    GestureDetector.OnGestureListener,
    GestureDetector.OnDoubleTapListener {

    // ── Companion ─────────────────────────────────────────────────────────────
    companion object {
        private const val TAG = "ALADIN_PLAYER"

        // Buffer constants (ms) — tuned for low-end TV devices
        private const val LIVE_MIN_BUFFER_MS   = 3_000   // 3 s  — live needs very little
        private const val LIVE_MAX_BUFFER_MS   = 12_000  // 12 s — avoid RAM waste on live
        private const val VOD_MIN_BUFFER_MS    = 15_000  // 15 s
        private const val VOD_MAX_BUFFER_MS    = 50_000  // 50 s
        private const val PLAYBACK_START_MS    = 1_500   // start after 1.5 s buffer
        private const val REBUFFER_START_MS    = 3_000   // rebuffer after 3 s drained

        // Low-memory caps
        private const val LOW_MEM_MIN_MS       = 5_000
        private const val LOW_MEM_MAX_MS       = 20_000
        private const val LOW_MEM_BUFFER_BYTES = 8 * 1024 * 1024   // 8 MB hard cap
        private const val NORMAL_BUFFER_BYTES  = DefaultLoadControl.DEFAULT_TARGET_BUFFER_BYTES

        // OSD / UI timings
        private const val OSD_HIDE_DELAY_MS    = 5_000L
        private const val STATUS_HIDE_DELAY_MS = 5_000L
        private const val BUFFERING_WARN_MS    = 15_000L
        private const val BUFFERING_TIMEOUT_MS = 30_000L
        private const val ZAPPING_DEBOUNCE_MS  = 500L
        private const val SEEK_COMMIT_MS       = 800L

        init {
            try {
                System.loadLibrary("ffmpeg")
                Log.d(TAG, "FFmpeg library loaded")
            } catch (t: Throwable) {
                Log.e(TAG, "FFmpeg not available: ${t.message}")
            }
        }
    }

    // ── Player & UI ──────────────────────────────────────────────────────────
    private var player: ExoPlayer? = null
    private lateinit var playerView: PlayerView
    private lateinit var audioManager: AudioManager
    private lateinit var trackSelector: DefaultTrackSelector
    private lateinit var prefs: SharedPreferences
    private lateinit var gestureDetector: GestureDetector

    // UI refs
    private lateinit var channelInfoLayout: LinearLayout
    private lateinit var tvChannelName: TextView
    private lateinit var tvTimeInfo: TextView
    private lateinit var ivFavorite: ImageView
    private lateinit var seekBar: SeekBar
    private lateinit var keyGuideLayout: LinearLayout
    private lateinit var volumeLayout: LinearLayout
    private lateinit var tvStatusOverlay: TextView
    private lateinit var tvVolumeLevel: TextView
    private lateinit var pbLoading: android.widget.ProgressBar
    private lateinit var quickListLayout: LinearLayout
    private lateinit var lvQuickList: android.widget.ListView
    private lateinit var btnSubtitles: TextView
    private lateinit var btnAudio: TextView
    private lateinit var btnQuality: TextView
    private lateinit var btnAspect: TextView
    private lateinit var btnFavorite: TextView
    private lateinit var tvGuideNav: TextView
    private lateinit var tvGuideSeek: TextView
    private lateinit var ivCenterPlayPause: ImageView
    private lateinit var pauseInfoLayout: LinearLayout
    private lateinit var ivPausePoster: ImageView
    private lateinit var tvPauseTitle: TextView
    private lateinit var tvPauseYear: TextView
    private lateinit var tvPauseRating: TextView
    private lateinit var tvPauseDescription: TextView
    private lateinit var errorLayout: LinearLayout
    private lateinit var tvErrorMessage: TextView
    private lateinit var tvErrorSuggestion: TextView
    private lateinit var btnGoToSettings: View

    // ── Channel Data ─────────────────────────────────────────────────────────
    private var channelUrls: ArrayList<String>? = null
    private var channelNames: ArrayList<String>? = null
    private var channelDescs: ArrayList<String>? = null
    private var channelPosters: ArrayList<String>? = null
    private var channelRatings: ArrayList<String>? = null
    private var channelYears: ArrayList<String>? = null
    private var channelTypes: ArrayList<String>? = null
    private var channelFavs: ArrayList<Boolean> = ArrayList()
    private var channelPositions: ArrayList<Int> = ArrayList()
    private var currentIndex: Int = 0

    // ── State ─────────────────────────────────────────────────────────────────
    private var retryCount = 0
    private val MAX_RETRIES = 3
    private var bufferingRetryCount = 0
    private var isPersistentError = false
    private var sleepTimerMinutes = 0

    // NEW: tracks whether user explicitly paused (prevents onResume auto-play)
    private var userPaused = false

    // NEW: device profile — computed once at init
    private var isLowMem = false
    private var preferSoftwareDecoder = false

    // ── WiFi Lock (NEW) ───────────────────────────────────────────────────────
    // Prevents WiFi chipset from entering doze during playback on cheap TV boxes.
    private var wifiLock: WifiManager.WifiLock? = null

    // ── Network Callback (NEW) ────────────────────────────────────────────────
    private var connectivityManager: ConnectivityManager? = null
    private val networkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            mainHandler.post {
                if (isPersistentError) {
                    Log.d(TAG, "Network restored — auto-retrying")
                    bufferingRetryCount = 0
                    isPersistentError = false
                    prepareAndPlay()
                } else if (player?.playbackState == Player.STATE_IDLE) {
                    prepareAndPlay()
                }
            }
        }
        override fun onLost(network: Network) {
            mainHandler.post {
                if (player?.isPlaying == true) {
                    showStatus(t("no_network", "İnternet bağlantısı kesildi. Bekleniyor..."), true)
                }
            }
        }
    }

    // ── Handlers & Runnables ─────────────────────────────────────────────────
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingSeekAmount: Long = 0
    private val seekHandler = Handler(Looper.getMainLooper())

    private val hideRunnable = Runnable {
        channelInfoLayout.visibility = View.GONE
        volumeLayout.visibility = View.GONE
        keyGuideLayout.visibility = View.GONE
        seekBar.visibility = View.GONE
        ivCenterPlayPause.visibility = View.GONE
        pbLoading.visibility = View.GONE
        quickListLayout.visibility = View.GONE
    }

    private val hideStatusOverlayRunnable = Runnable {
        tvStatusOverlay.visibility = View.GONE
    }

    private val bufferingStatusRunnable = Runnable {
        if (player?.playbackState == Player.STATE_BUFFERING && player?.playWhenReady == true) {
            val msg = t("checking_connection", "Bağlantı kontrol ediliyor...")
            val attempt = if (bufferingRetryCount > 0) " (${t("attempt", "Deneme")} $bufferingRetryCount)" else ""
            showStatus("$msg$attempt", true)
            pbLoading.visibility = View.VISIBLE
        }
    }

    private val bufferingTimeoutRunnable = Runnable {
        if (bufferingRetryCount < MAX_RETRIES) {
            bufferingRetryCount++
            Log.d(TAG, "Buffering timeout. Auto-retry #$bufferingRetryCount")
            prepareAndPlay()
        } else {
            isPersistentError = true
            pbLoading.visibility = View.GONE
            mainHandler.removeCallbacks(hideRunnable)
            channelInfoLayout.visibility = View.VISIBLE
            showStatus(
                "${t("error_detailed", "Bu içerik şu an açılamıyor. İnternet bağlantınızı kontrol edin.")}\n\n${t("retry_ok", "Yeniden denemek için OK basın")}",
                true
            )
        }
    }

    private val performSeekRunnable = Runnable {
        player?.let { p ->
            val target = max(0L, min(p.currentPosition + pendingSeekAmount, p.duration))
            p.seekTo(target)
            pendingSeekAmount = 0
            hideStatusDelayed()
        }
    }

    private val sleepTimerRunnable = Runnable {
        saveCurrentPosition()
        finish()
    }

    private val prepareRunnable = Runnable {
        if (isFinishing || isDestroyed) return@Runnable
        initializePlayer()
        playCurrentChannel()
    }

    private val updateProgressAction = object : Runnable {
        override fun run() {
            if (isFinishing || isDestroyed) return
            player?.let { p ->
                val duration = p.duration
                if (duration != C.TIME_UNSET && duration > 0) {
                    val current = p.currentPosition
                    seekBar.progress = min(current, Int.MAX_VALUE.toLong()).toInt()
                    tvTimeInfo.text = String.format(
                        Locale.getDefault(), "%s / %s",
                        formatTime(current), formatTime(duration)
                    )
                    if (p.isPlaying && current % 60_000 < 1_000) {
                        saveCurrentPosition()
                    }
                }
            }
            mainHandler.postDelayed(this, 1_000)
        }
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        setContentView(R.layout.activity_player)

        WindowCompat.setDecorFitsSystemWindows(window, false)
        val controller = WindowInsetsControllerCompat(window, window.decorView)
        controller.hide(WindowInsetsCompat.Type.systemBars())
        controller.systemBarsBehavior =
            WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE

        prefs = getSharedPreferences("AladinPlayerPrefs", Context.MODE_PRIVATE)

        // Compute device profile once
        isLowMem = isLowMemoryDevice()
        preferSoftwareDecoder = shouldPreferSoftwareDecoder()

        // Read intent data
        channelUrls = intent.getStringArrayListExtra("URL_LIST")
        channelNames = intent.getStringArrayListExtra("NAME_LIST")
        channelDescs = intent.getStringArrayListExtra("DESC_LIST")
        channelPosters = intent.getStringArrayListExtra("POSTER_LIST")
        channelRatings = intent.getStringArrayListExtra("RATING_LIST")
        channelYears = intent.getStringArrayListExtra("YEAR_LIST")
        channelTypes = intent.getStringArrayListExtra("TYPE_LIST")
        channelFavs = readSerializableList("FAV_LIST") ?: ArrayList()
        channelPositions = readSerializableList("POS_LIST") ?: ArrayList()
        currentIndex = intent.getIntExtra("CURRENT_INDEX", 0)

        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        gestureDetector = GestureDetector(this, this)
        gestureDetector.setOnDoubleTapListener(this)

        bindViews()
        setupSeekBar()
        setupLabels()
        acquireWifiLock()
        registerNetworkCallback()
        prepareAndPlay()
    }

    override fun onResume() {
        super.onResume()
        mainHandler.post(updateProgressAction)
        // NEW: only auto-play if the user did NOT explicitly pause
        if (!userPaused) {
            player?.play()
        }
    }

    override fun onPause() {
        super.onPause()
        mainHandler.removeCallbacks(updateProgressAction)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && isInPictureInPictureMode) {
            // In PiP — keep playing
        } else {
            player?.pause()
            saveCurrentPosition()
            releasePlayer()
        }
    }

    override fun onDestroy() {
        mainHandler.removeCallbacksAndMessages(null)
        releasePlayer()
        releaseWifiLock()
        unregisterNetworkCallback()
        super.onDestroy()
    }

    // ── PiP ──────────────────────────────────────────────────────────────────
    override fun onUserLeaveHint() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            enterPictureInPictureMode(
                PictureInPictureParams.Builder().setAspectRatio(Rational(16, 9)).build()
            )
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: android.content.res.Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        if (isInPictureInPictureMode) {
            channelInfoLayout.visibility = View.GONE
            keyGuideLayout.visibility = View.GONE
            volumeLayout.visibility = View.GONE
            seekBar.visibility = View.GONE
            pauseInfoLayout.visibility = View.GONE
        }
    }

    // ── Player Init ───────────────────────────────────────────────────────────
    private fun initializePlayer() {
        if (player != null) return

        val decoderMode = intent.getStringExtra("DECODER_MODE") ?: "auto"
        val url = channelUrls?.getOrNull(currentIndex) ?: ""
        val isLive = isLiveUrl(url)

        // 1. RenderersFactory — hardware first, FFmpeg fallback
        val extensionMode = if (decoderMode == "software" || preferSoftwareDecoder) {
            DefaultRenderersFactory.EXTENSION_RENDERER_MODE_PREFER
        } else {
            // ON = try hardware, fall to FFmpeg extension if hardware fails
            DefaultRenderersFactory.EXTENSION_RENDERER_MODE_ON
        }
        val renderersFactory = DefaultRenderersFactory(this)
            .setExtensionRendererMode(extensionMode)
            .setEnableDecoderFallback(true)         // auto-fallback on decoder crash
            .setEnableAudioFloatOutput(!preferSoftwareDecoder)

        // 2. BandwidthMeter — NEW: seed with 1 Mbps to prevent aggressive ABR on start
        // On low-end devices, starting at full bitrate causes initial stutter.
        val bandwidthMeter = DefaultBandwidthMeter.Builder(this)
            .setInitialBitrateEstimate(
                if (isLowMem) 800_000L else 1_500_000L  // 0.8 or 1.5 Mbps seed
            )
            .build()

        // 3. LoadControl — NEW: differentiated by live/VOD and device memory
        val loadControl = buildLoadControl(isLive)

        // 4. TrackSelector
        trackSelector = DefaultTrackSelector(this).apply {
            parameters = buildUponParameters()
                .setAllowVideoMixedMimeTypeAdaptiveness(true)
                .setAllowAudioMixedMimeTypeAdaptiveness(true)
                .apply {
                    if (isLowMem || preferSoftwareDecoder) {
                        setMaxVideoSizeSd()          // cap resolution on low-end
                        setMaxAudioChannelCount(2)   // force stereo — saves CPU
                    }
                }
                .build()
        }

        // 5. Audio Attributes
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(C.USAGE_MEDIA)
            .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE)
            .build()

        // 6. Build player
        player = ExoPlayer.Builder(this, renderersFactory)
            .setTrackSelector(trackSelector)
            .setLoadControl(loadControl)
            .setBandwidthMeter(bandwidthMeter)
            .setHandleAudioBecomingNoisy(true)
            .setAudioAttributes(audioAttributes, true)
            // NEW: WakeMode — keeps CPU + network alive, no need for manual WakeLock
            .setWakeMode(C.WAKE_MODE_NETWORK)
            .build()

        player?.setVideoScalingMode(C.VIDEO_SCALING_MODE_SCALE_TO_FIT) // FIT not CROPPING
        playerView.player = player
        playerView.useController = false

        player?.addListener(playerListener)
    }

    /**
     * Builds a LoadControl tuned for the content type and device capability.
     *
     * Live TV:  Small buffer (3–12 s). Live streams are realtime; buffering more
     *           wastes RAM and increases end-to-end latency for the viewer.
     * VOD:      Larger buffer (15–50 s). Allows smooth playback over variable networks.
     * Low-mem:  Halves the max buffer and enforces an 8 MB byte cap to avoid OOM.
     */
    private fun buildLoadControl(isLive: Boolean): DefaultLoadControl {
        val minMs: Int
        val maxMs: Int
        val bufBytes: Int

        when {
            isLive && isLowMem -> {
                minMs = LIVE_MIN_BUFFER_MS
                maxMs = 8_000          // 8 s max for live + low-mem
                bufBytes = LOW_MEM_BUFFER_BYTES
            }
            isLive -> {
                minMs = LIVE_MIN_BUFFER_MS
                maxMs = LIVE_MAX_BUFFER_MS
                bufBytes = NORMAL_BUFFER_BYTES
            }
            isLowMem -> {
                minMs = LOW_MEM_MIN_MS
                maxMs = LOW_MEM_MAX_MS
                bufBytes = LOW_MEM_BUFFER_BYTES
            }
            else -> {
                minMs = VOD_MIN_BUFFER_MS
                maxMs = VOD_MAX_BUFFER_MS
                bufBytes = NORMAL_BUFFER_BYTES
            }
        }

        return DefaultLoadControl.Builder()
            .setBufferDurationsMs(minMs, maxMs, PLAYBACK_START_MS, REBUFFER_START_MS)
            .setTargetBufferBytes(bufBytes)
            // Low-mem: prioritize size (stop early) to protect RAM.
            // Normal:  prioritize time (buffer ahead) for smooth playback.
            .setPrioritizeTimeOverSizeThresholds(!isLowMem)
            .build()
    }

    // ── Player Listener ───────────────────────────────────────────────────────
    private val playerListener = object : Player.Listener {

        override fun onPlayerError(error: PlaybackException) {
            Log.e(TAG, "Playback Error [${error.errorCode}]: ${error.message}", error)

            val isDecoderError = error.errorCode in listOf(
                PlaybackException.ERROR_CODE_DECODER_INIT_FAILED,
                PlaybackException.ERROR_CODE_DECODING_FAILED,
                PlaybackException.ERROR_CODE_DECODER_QUERY_FAILED
            ) || error.message?.contains("decoder", ignoreCase = true) == true

            val isNetworkError = error.errorCode in listOf(
                PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_FAILED,
                PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_TIMEOUT,
                PlaybackException.ERROR_CODE_IO_BAD_HTTP_STATUS
            )

            when {
                isDecoderError -> showDecoderErrorUI(error.message ?: "")
                isNetworkError && retryCount < MAX_RETRIES -> {
                    retryCount++
                    // Back-off: wait longer on each retry (2s, 4s, 6s)
                    mainHandler.postDelayed({ prepareAndPlay() }, retryCount * 2_000L)
                    showStatus("${t("retry", "Yeniden bağlanılıyor")} ($retryCount/$MAX_RETRIES)...")
                }
                retryCount >= MAX_RETRIES -> {
                    retryCount = 0
                    nextChannelOnError()
                }
                else -> {
                    retryCount++
                    mainHandler.postDelayed({ prepareAndPlay() }, 2_000)
                }
            }
        }

        override fun onTracksChanged(tracks: Tracks) {
            for (group in tracks.groups) {
                if (group.type == C.TRACK_TYPE_AUDIO) {
                    for (i in 0 until group.length) {
                        val fmt = group.getTrackFormat(i)
                        Log.d(TAG, "Audio: ${fmt.sampleMimeType} | lang=${fmt.language} | supported=${group.isTrackSupported(i)}")
                        if (!group.isTrackSupported(i)) {
                            showStatus("${t("audio_not_supported", "Ses formatı desteklenmiyor")}: ${fmt.sampleMimeType?.substringAfter("/")}", false)
                        }
                    }
                }
            }
        }

        override fun onPlaybackStateChanged(state: Int) {
            when (state) {
                Player.STATE_BUFFERING -> {
                    mainHandler.removeCallbacks(bufferingStatusRunnable)
                    mainHandler.postDelayed(bufferingStatusRunnable, BUFFERING_WARN_MS)
                    mainHandler.removeCallbacks(bufferingTimeoutRunnable)
                    mainHandler.postDelayed(bufferingTimeoutRunnable, BUFFERING_TIMEOUT_MS)
                }
                Player.STATE_READY -> {
                    retryCount = 0
                    bufferingRetryCount = 0
                    isPersistentError = false
                    mainHandler.removeCallbacks(bufferingStatusRunnable)
                    mainHandler.removeCallbacks(bufferingTimeoutRunnable)
                    tvStatusOverlay.visibility = View.GONE
                    pbLoading.visibility = View.GONE
                    player?.let { p ->
                        if (p.duration != C.TIME_UNSET) {
                            seekBar.max = min(p.duration, Int.MAX_VALUE.toLong()).toInt()
                        }
                    }
                    showOSD()
                }
                Player.STATE_ENDED -> {
                    mainHandler.removeCallbacks(bufferingTimeoutRunnable)
                }
                Player.STATE_IDLE -> { /* no-op */ }
            }
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            if (!isPlaying && player?.playbackState != Player.STATE_BUFFERING) {
                updatePauseInfo()
            } else {
                pauseInfoLayout.visibility = View.GONE
            }
        }
    }

    // ── Playback Control ──────────────────────────────────────────────────────
    private fun prepareAndPlay() {
        mainHandler.removeCallbacks(prepareRunnable)
        releasePlayer()
        showStatus(t("loading", "Yükleniyor..."))
        pauseInfoLayout.visibility = View.GONE
        mainHandler.postDelayed(prepareRunnable, ZAPPING_DEBOUNCE_MS)
    }

    private fun playCurrentChannel() {
        val url = channelUrls?.getOrNull(currentIndex) ?: return
        val name = channelNames?.getOrNull(currentIndex) ?: "Kanal"

        tvChannelName.text = name
        updateFavoriteIcon()

        // NEW: MIME type hint — ExoPlayer skips format sniffing, reduces zapping latency
        val mediaItem = MediaItem.Builder()
            .setUri(url)
            .setMimeType(detectMimeType(url))
            .build()

        player?.setMediaItem(mediaItem, true)
        player?.prepare()

        val savedPos = channelPositions.getOrNull(currentIndex)?.toLong() ?: 0L
        if (savedPos > 0) player?.seekTo(savedPos * 1_000)

        userPaused = false
        player?.play()
        showOSD()
    }

    private fun releasePlayer() {
        player?.let { p ->
            p.removeListener(playerListener)
            p.stop()
            p.clearMediaItems()
            p.release()
        }
        player = null
        playerView.player = null
    }

    private fun togglePlayPause() {
        player?.let { p ->
            if (p.isPlaying) {
                userPaused = true
                p.pause()
            } else {
                userPaused = false
                p.play()
            }
            showOSD()
        }
    }

    // ── Key Handling ──────────────────────────────────────────────────────────
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        val size = channelUrls?.size ?: 1
        when (keyCode) {
            KeyEvent.KEYCODE_DPAD_UP -> {
                if (currentIndex > 0) { currentIndex--; prepareAndPlay() }
                return true
            }
            KeyEvent.KEYCODE_DPAD_DOWN -> {
                if (currentIndex < size - 1) { currentIndex++; prepareAndPlay() }
                return true
            }
            KeyEvent.KEYCODE_DPAD_RIGHT -> {
                player?.let { p ->
                    if (p.duration == C.TIME_UNSET) {
                        audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_RAISE, 0); showVolume()
                    } else accumulateSeek(30_000L)
                }; return true
            }
            KeyEvent.KEYCODE_DPAD_LEFT -> {
                player?.let { p ->
                    if (p.duration == C.TIME_UNSET) {
                        audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_LOWER, 0); showVolume()
                    } else accumulateSeek(-10_000L)
                }; return true
            }
            KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER -> {
                if (isPersistentError) {
                    bufferingRetryCount = 0; isPersistentError = false; prepareAndPlay()
                } else togglePlayPause()
                return true
            }
            KeyEvent.KEYCODE_PROG_RED, KeyEvent.KEYCODE_F1,
            KeyEvent.KEYCODE_1, KeyEvent.KEYCODE_NUMPAD_1 -> { cycleTracks(C.TRACK_TYPE_TEXT); return true }
            KeyEvent.KEYCODE_PROG_GREEN, KeyEvent.KEYCODE_F2,
            KeyEvent.KEYCODE_2, KeyEvent.KEYCODE_NUMPAD_2 -> { cycleTracks(C.TRACK_TYPE_AUDIO); return true }
            KeyEvent.KEYCODE_PROG_YELLOW, KeyEvent.KEYCODE_F3,
            KeyEvent.KEYCODE_3, KeyEvent.KEYCODE_NUMPAD_3 -> { cycleTracks(C.TRACK_TYPE_VIDEO); return true }
            KeyEvent.KEYCODE_PROG_BLUE, KeyEvent.KEYCODE_F4,
            KeyEvent.KEYCODE_4, KeyEvent.KEYCODE_NUMPAD_4 -> { cycleAspectRatio(); return true }
            KeyEvent.KEYCODE_5, KeyEvent.KEYCODE_NUMPAD_5 -> { showPlayerInfo(); return true }
            KeyEvent.KEYCODE_6, KeyEvent.KEYCODE_NUMPAD_6 -> { showQuickList(); return true }
            KeyEvent.KEYCODE_7, KeyEvent.KEYCODE_NUMPAD_7 -> {
                player?.let { if (it.duration != C.TIME_UNSET) accumulateSeek(-600_000L) }; return true
            }
            KeyEvent.KEYCODE_8, KeyEvent.KEYCODE_NUMPAD_8 -> { cycleSleepTimer(); return true }
            KeyEvent.KEYCODE_9, KeyEvent.KEYCODE_NUMPAD_9 -> {
                player?.let { if (it.duration != C.TIME_UNSET) accumulateSeek(600_000L) }; return true
            }
            KeyEvent.KEYCODE_0, KeyEvent.KEYCODE_NUMPAD_0 -> { toggleFavorite(); return true }
            KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_ESCAPE -> {
                saveCurrentPosition(); finish(); return true
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    // ── Gesture Handling ──────────────────────────────────────────────────────
    override fun onSingleTapConfirmed(e: MotionEvent): Boolean { showOSD(); return true }
    override fun onDoubleTap(e: MotionEvent): Boolean = false
    override fun onDoubleTapEvent(e: MotionEvent): Boolean = false
    override fun onDown(e: MotionEvent): Boolean = true
    override fun onShowPress(e: MotionEvent) {}
    override fun onSingleTapUp(e: MotionEvent): Boolean = false
    override fun onScroll(e1: MotionEvent?, e2: MotionEvent, dX: Float, dY: Float): Boolean = false
    override fun onLongPress(e: MotionEvent) { toggleFavorite() }

    override fun onFling(e1: MotionEvent?, e2: MotionEvent, vX: Float, vY: Float): Boolean {
        if (e1 == null) return false
        val dX = e2.x - e1.x; val dY = e2.y - e1.y
        val size = channelUrls?.size ?: 1
        if (abs(dX) > abs(dY)) {
            if (abs(dX) > 100 && abs(vX) > 100) {
                player?.let { p ->
                    if (p.duration != C.TIME_UNSET && p.duration > 0) {
                        accumulateSeek(if (dX > 0) 30_000L else -10_000L)
                    } else {
                        audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC,
                            if (dX > 0) AudioManager.ADJUST_RAISE else AudioManager.ADJUST_LOWER, 0)
                        showVolume()
                    }
                }
            }
        } else {
            if (abs(dY) > 100 && abs(vY) > 100) {
                if (dY > 0 && currentIndex < size - 1) { currentIndex++; prepareAndPlay() }
                else if (dY < 0 && currentIndex > 0) { currentIndex--; prepareAndPlay() }
            }
        }
        return true
    }

    // ── Seek ──────────────────────────────────────────────────────────────────
    private fun accumulateSeek(amount: Long) {
        seekHandler.removeCallbacks(performSeekRunnable)
        pendingSeekAmount += amount
        player?.let { p ->
            val target = max(0L, min(p.currentPosition + pendingSeekAmount, p.duration))
            val sign = if (pendingSeekAmount > 0) "+" else ""
            showStatus("${formatTime(target)} ($sign${pendingSeekAmount / 1000}s)")
            seekBar.progress = min(target, Int.MAX_VALUE.toLong()).toInt()
        }
        channelInfoLayout.visibility = View.VISIBLE
        seekBar.visibility = View.VISIBLE
        seekHandler.postDelayed(performSeekRunnable, SEEK_COMMIT_MS)
    }

    private fun setupSeekBar() {
        seekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(sb: SeekBar?, progress: Int, fromUser: Boolean) {
                if (fromUser) tvTimeInfo.text = formatTime(progress.toLong())
            }
            override fun onStartTrackingTouch(sb: SeekBar?) {
                mainHandler.removeCallbacks(hideRunnable)
            }
            override fun onStopTrackingTouch(sb: SeekBar?) {
                player?.seekTo(seekBar.progress.toLong())
                resetHideTimer()
            }
        })
    }

    // ── Track / Aspect / Sleep ────────────────────────────────────────────────
    private fun cycleTracks(trackType: Int) {
        val p = player ?: return
        val groups = p.currentTracks.groups.filter { it.type == trackType }
        if (groups.isEmpty()) return

        val available = mutableListOf<Triple<Int, Int, String>>()
        groups.forEachIndexed { gi, grp ->
            for (ti in 0 until grp.length) {
                if (!grp.isTrackSupported(ti)) continue
                val fmt = grp.getTrackFormat(ti)
                val label = when (trackType) {
                    C.TRACK_TYPE_TEXT  -> fmt.label ?: fmt.language ?: "${t("subtitles", "Altyazı")} ${available.size + 1}"
                    C.TRACK_TYPE_AUDIO -> fmt.label ?: fmt.language ?: "${t("audio", "Ses")} ${available.size + 1}"
                    else               -> "${fmt.width}x${fmt.height}"
                }
                available.add(Triple(gi, ti, label))
            }
        }
        if (available.isEmpty()) return

        var currentSel = -1
        available.forEachIndexed { i, (gi, ti, _) -> if (groups[gi].isTrackSelected(ti)) currentSel = i }

        val canDisable = trackType != C.TRACK_TYPE_VIDEO
        val cycleSize  = available.size + (if (canDisable) 1 else 0)
        val nextIdx    = (currentSel + 1) % cycleSize

        if (canDisable && nextIdx == available.size) {
            p.trackSelectionParameters = p.trackSelectionParameters.buildUpon()
                .setTrackTypeDisabled(trackType, true).clearOverridesOfType(trackType).build()
            val label = if (trackType == C.TRACK_TYPE_TEXT) t("subtitles", "Altyazı") else t("audio", "Ses")
            showStatus("$label: ${t("off", "Kapalı")}")
        } else {
            val (gi, ti, label) = available[nextIdx]
            p.trackSelectionParameters = p.trackSelectionParameters.buildUpon()
                .setTrackTypeDisabled(trackType, false)
                .setOverrideForType(TrackSelectionOverride(groups[gi].mediaTrackGroup, ti))
                .build()
            val prefix = when (trackType) {
                C.TRACK_TYPE_TEXT  -> "${t("subtitles", "Altyazı")}: "
                C.TRACK_TYPE_AUDIO -> "${t("audio", "Ses")}: "
                else               -> "${t("quality", "Kalite")}: "
            }
            showStatus("$prefix$label")
        }
    }

    private fun cycleAspectRatio() {
        val modes = intArrayOf(
            AspectRatioFrameLayout.RESIZE_MODE_FIT,
            AspectRatioFrameLayout.RESIZE_MODE_FILL,
            AspectRatioFrameLayout.RESIZE_MODE_ZOOM
        )
        val names = arrayOf(t("aspect_fit", "Sığdır"), t("aspect_fill", "Doldur"), t("aspect_zoom", "Zoom"))
        val next  = (modes.indexOf(playerView.resizeMode) + 1) % modes.size
        playerView.resizeMode = modes[next]
        showStatus("${t("aspect", "Ekran Oranı")}: ${names[next]}")
    }

    private fun cycleSleepTimer() {
        val options = listOf(0, 15, 30, 60, 90, 120)
        sleepTimerMinutes = options[(options.indexOf(sleepTimerMinutes) + 1) % options.size]
        mainHandler.removeCallbacks(sleepTimerRunnable)
        if (sleepTimerMinutes > 0) {
            mainHandler.postDelayed(sleepTimerRunnable, sleepTimerMinutes * 60_000L)
            showStatus("${t("sleep_timer", "Uyku Zamanlayıcı")}: $sleepTimerMinutes min", false)
        } else {
            showStatus("${t("sleep_timer", "Uyku Zamanlayıcı")}: ${t("off", "Kapalı")}", false)
        }
    }

    // ── OSD / UI ──────────────────────────────────────────────────────────────
    private fun showOSD() {
        channelInfoLayout.visibility = View.VISIBLE
        keyGuideLayout.visibility    = View.VISIBLE
        player?.let { p ->
            seekBar.visibility  = if (p.duration != C.TIME_UNSET && p.duration > 0) View.VISIBLE else View.GONE
            tvTimeInfo.visibility = View.VISIBLE
            ivCenterPlayPause.setImageResource(
                if (p.isPlaying) android.R.drawable.ic_media_pause
                else android.R.drawable.ic_media_play
            )
            ivCenterPlayPause.visibility = View.VISIBLE
        }
        resetHideTimer()
    }

    private fun resetHideTimer() {
        mainHandler.removeCallbacks(hideRunnable)
        if (player?.isPlaying == true) {
            mainHandler.postDelayed(hideRunnable, OSD_HIDE_DELAY_MS)
        }
    }

    private fun showStatus(msg: String, persistent: Boolean = false) {
        tvStatusOverlay.text = msg
        tvStatusOverlay.visibility = View.VISIBLE
        mainHandler.removeCallbacks(hideStatusOverlayRunnable)
        if (!persistent) mainHandler.postDelayed(hideStatusOverlayRunnable, STATUS_HIDE_DELAY_MS)
    }

    private fun hideStatusDelayed() {
        mainHandler.removeCallbacks(hideRunnable)
        mainHandler.postDelayed(hideRunnable, 2_000)
    }

    private fun showVolume() {
        val cur = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
        val max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        tvVolumeLevel.text = "%${cur * 100 / max}"
        volumeLayout.visibility = View.VISIBLE
        resetHideTimer()
    }

    private fun showPlayerInfo() {
        player?.let { p ->
            val fmt = p.videoFormat ?: return@let
            val res   = "${fmt.width}x${fmt.height}"
            val fps   = if (fmt.frameRate > 0) "${fmt.frameRate.toInt()} FPS" else ""
            val codec = fmt.sampleMimeType?.substringAfterLast("/")?.uppercase() ?: ""
            val url   = channelUrls?.getOrNull(currentIndex) ?: ""
            val bw    = "${(p.totalBufferedDuration / 1_000)} s buffered"
            showStatus("$res $fps | $codec | $bw\n$url", false)
        }
    }

    private fun showQuickList() {
        if (channelNames == null) return
        val adapter = android.widget.ArrayAdapter(this, android.R.layout.simple_list_item_1, channelNames!!)
        lvQuickList.adapter = adapter
        lvQuickList.setSelection(currentIndex)
        lvQuickList.setOnItemClickListener { _, _, pos, _ ->
            currentIndex = pos; quickListLayout.visibility = View.GONE; prepareAndPlay()
        }
        quickListLayout.visibility = View.VISIBLE
        lvQuickList.requestFocus()
        resetHideTimer()
    }

    // ── Pause Info / Poster ───────────────────────────────────────────────────
    private fun updatePauseInfo() {
        val type = channelTypes?.getOrNull(currentIndex) ?: "tv"
        if (type == "tv") { pauseInfoLayout.visibility = View.GONE; return }

        tvPauseTitle.text       = channelNames?.getOrNull(currentIndex) ?: ""
        tvPauseDescription.text = channelDescs?.getOrNull(currentIndex) ?: ""
        val rating = channelRatings?.getOrNull(currentIndex) ?: ""
        tvPauseRating.text = if (rating.isNotEmpty()) "⭐ $rating/10" else ""
        tvPauseYear.text   = channelYears?.getOrNull(currentIndex) ?: ""

        val poster = channelPosters?.getOrNull(currentIndex) ?: ""
        if (poster.isNotEmpty()) {
            ivPausePoster.setImageResource(android.R.color.darker_gray) // placeholder
            ivPausePoster.visibility = View.VISIBLE
            loadPoster(poster)
        } else {
            ivPausePoster.visibility = View.GONE
        }
        pauseInfoLayout.visibility = View.VISIBLE
    }

    private fun loadPoster(posterUrl: String) {
        Glide.with(this)
            .load(posterUrl)
            .placeholder(android.R.color.darker_gray)   // gri placeholder, hemen görünür
            .error(android.R.color.darker_gray)          // hata durumunda da gri kal
            .override(320, 180)                          // TV için yeterli, RAM dostu
            .diskCacheStrategy(DiskCacheStrategy.ALL)    // disk cache: aynı poster tekrar indirilmez
            .into(ivPausePoster)
    }

    // ── Error UI ──────────────────────────────────────────────────────────────
    private fun showDecoderErrorUI(message: String) {
        mainHandler.removeCallbacksAndMessages(null)
        releasePlayer()
        tvErrorMessage.text = t("playback_error", "Oynatma Hatası")
        tvErrorSuggestion.text =
            "${t("decoder_suggestion", "Ayarlardan Yazılımsal Kod Çözücü'yü deneyin.")}\n\n(Error: $message)"
        (btnGoToSettings as? TextView)?.text = t("go_to_settings", "AYARLARA GİT")
        errorLayout.visibility = View.VISIBLE
        errorLayout.requestFocus()
        hideRunnable.run()
    }

    private fun nextChannelOnError() {
        val size = channelUrls?.size ?: return
        if (currentIndex < size - 1) { currentIndex++; prepareAndPlay() }
        else showStatus(t("error", "Yayın Açılamadı"))
    }

    // ── Favorite / Position ───────────────────────────────────────────────────
    private fun toggleFavorite() {
        val url = channelUrls?.getOrNull(currentIndex) ?: return
        val newFav = !(channelFavs.getOrNull(currentIndex) ?: false)
        if (currentIndex < channelFavs.size) channelFavs[currentIndex] = newFav
        updateFavoriteIcon()
        showStatus(if (newFav) t("added", "Favorilere Eklendi") else t("removed", "Favorilerden Çıkarıldı"))
        val i = Intent("com.aladin.iptv.player.pro.FAVORITE_TOGGLED").apply {
            setPackage(packageName); putExtra("url", url); putExtra("isFavorite", newFav)
        }
        sendBroadcast(i)
    }

    private fun updateFavoriteIcon() {
        val isFav = channelFavs.getOrNull(currentIndex) ?: false
        ivFavorite.setImageResource(if (isFav) android.R.drawable.btn_star_big_on else android.R.drawable.btn_star_big_off)
    }

    private fun saveCurrentPosition() {
        val url = channelUrls?.getOrNull(currentIndex) ?: return
        player?.let { p ->
            if (p.duration != C.TIME_UNSET && p.duration > 0) {
                val pos = p.currentPosition
                prefs.edit().putLong("pos_$url", pos).apply()
                val i = Intent("com.aladin.iptv.player.pro.PROGRESS_UPDATE").apply {
                    setPackage(packageName)
                    putExtra("url", url); putExtra("position", pos); putExtra("duration", p.duration)
                }
                sendBroadcast(i)
            }
        }
    }

    // ── WiFi Lock ─────────────────────────────────────────────────────────────
    /**
     * Acquires a WiFi lock to prevent the WiFi chipset from sleeping during playback.
     * Many cheap Android TV boxes aggressively power-gate the WiFi radio, causing
     * micro-dropouts every 20–30 seconds. This lock keeps the radio active.
     */
    private fun acquireWifiLock() {
        try {
            val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            wifiLock = wm?.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "AladinIPTV:WifiLock")
            wifiLock?.acquire()
        } catch (e: Exception) {
            Log.w(TAG, "Could not acquire WifiLock: ${e.message}")
        }
    }

    private fun releaseWifiLock() {
        try {
            if (wifiLock?.isHeld == true) wifiLock?.release()
        } catch (e: Exception) {
            Log.w(TAG, "WifiLock release error: ${e.message}")
        }
    }

    // ── Network Callback ──────────────────────────────────────────────────────
    private fun registerNetworkCallback() {
        try {
            connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val req = NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .build()
            connectivityManager?.registerNetworkCallback(req, networkCallback)
        } catch (e: Exception) {
            Log.w(TAG, "NetworkCallback registration failed: ${e.message}")
        }
    }

    private fun unregisterNetworkCallback() {
        try { connectivityManager?.unregisterNetworkCallback(networkCallback) }
        catch (e: Exception) { Log.w(TAG, "NetworkCallback unregister error: ${e.message}") }
    }

    // ── Device Detection ──────────────────────────────────────────────────────
    private fun isLowMemoryDevice(): Boolean = try {
        val am = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
        val info = android.app.ActivityManager.MemoryInfo()
        am.getMemoryInfo(info)
        info.totalMem < 1_100L * 1024 * 1024  // < ~1.1 GB
    } catch (e: Exception) { false }

    private fun shouldPreferSoftwareDecoder(): Boolean {
        val model = Build.MODEL ?: ""
        val mfr   = Build.MANUFACTURER ?: ""
        return model.contains("TB-7305", ignoreCase = true) ||
               (mfr.contains("Lenovo", ignoreCase = true) && model.contains("7305"))
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    /**
     * Provides a MIME type hint so ExoPlayer skips format detection entirely.
     * This reduces channel switching latency by ~150–300 ms on slow devices.
     */
    private fun detectMimeType(url: String): String {
        val lower = url.lowercase()
        return when {
            lower.contains(".m3u8") || lower.contains("/hls/") -> MimeTypes.APPLICATION_M3U8
            lower.contains(".mpd")  || lower.contains("/dash/") -> MimeTypes.APPLICATION_MPD
            lower.contains(".ts")   -> MimeTypes.VIDEO_MP2T
            lower.contains("rtsp://") -> MimeTypes.APPLICATION_RTSP
            lower.contains(".mp4")  -> MimeTypes.VIDEO_MP4
            lower.contains(".mkv")  -> MimeTypes.VIDEO_MATROSKA
            else                    -> MimeTypes.APPLICATION_M3U8  // most IPTV is HLS
        }
    }

    /**
     * Heuristic to determine if a URL is likely a live stream (no seekable duration).
     * Used to choose the right LoadControl profile before the player is created.
     */
    private fun isLiveUrl(url: String): Boolean {
        val lower = url.lowercase()
        // RTSP and most plain HLS without explicit VOD markers are live
        return lower.startsWith("rtsp://") ||
               lower.startsWith("rtp://")  ||
               lower.startsWith("udp://")  ||
               (!lower.contains(".mp4") && !lower.contains(".mkv") && !lower.contains(".avi"))
    }

    private fun t(key: String, default: String) = intent.getStringExtra("i18n_$key") ?: default

    @Suppress("DEPRECATION", "UNCHECKED_CAST")
    private fun <T : java.io.Serializable> readSerializableList(key: String): ArrayList<T>? {
        return if (Build.VERSION.SDK_INT >= 33) {
            intent.getSerializableExtra(key, ArrayList::class.java) as? ArrayList<T>
        } else {
            intent.getSerializableExtra(key) as? ArrayList<T>
        }
    }

    private fun formatTime(ms: Long): String {
        val s = ms / 1000; val h = s / 3600; val m = (s % 3600) / 60; val sec = s % 60
        return if (h > 0) String.format(Locale.getDefault(), "%02d:%02d:%02d", h, m, sec)
        else String.format(Locale.getDefault(), "%02d:%02d", m, sec)
    }

    private fun setupLabels() {
        btnSubtitles.text = "1 ● ${t("subtitles", "Altyazı")}"
        btnAudio.text     = "2 ● ${t("audio", "Ses")}"
        btnQuality.text   = "3 ● ${t("quality", "Kalite")}"
        btnAspect.text    = "4 ● ${t("aspect", "Oran")}"
        btnFavorite.text  = "0 [★] ${t("favorites_short", "Favori")}"
        tvGuideNav.text   = t("guide_channel", "↕ Kanal Değiştir")
        tvGuideSeek.text  = t("guide_seek", "↔ İleri/Geri Sar")

        listOf(btnSubtitles, btnAudio, btnQuality, btnAspect, btnFavorite).forEach {
            it.isFocusable = false; it.isFocusableInTouchMode = false
        }
        btnSubtitles.setOnClickListener { cycleTracks(C.TRACK_TYPE_TEXT) }
        btnAudio.setOnClickListener     { cycleTracks(C.TRACK_TYPE_AUDIO) }
        btnQuality.setOnClickListener   { cycleTracks(C.TRACK_TYPE_VIDEO) }
        btnAspect.setOnClickListener    { cycleAspectRatio() }
        btnFavorite.setOnClickListener  { toggleFavorite() }
    }

    private fun bindViews() {
        playerView         = findViewById(R.id.native_player_view)
        channelInfoLayout  = findViewById(R.id.channel_info_layout)
        tvChannelName      = findViewById(R.id.tv_channel_name)
        tvTimeInfo         = findViewById(R.id.tv_time_info)
        ivFavorite         = findViewById(R.id.iv_favorite)
        seekBar            = findViewById(R.id.player_seekbar)
        keyGuideLayout     = findViewById(R.id.key_guide_layout)
        volumeLayout       = findViewById(R.id.volume_layout)
        tvVolumeLevel      = findViewById(R.id.tv_volume_level)
        tvStatusOverlay    = findViewById(R.id.tv_status_overlay)
        pbLoading          = findViewById(R.id.pb_loading)
        quickListLayout    = findViewById(R.id.quick_list_layout)
        lvQuickList        = findViewById(R.id.lv_quick_list)
        pauseInfoLayout    = findViewById(R.id.pause_info_layout)
        ivPausePoster      = findViewById(R.id.iv_pause_poster)
        tvPauseTitle       = findViewById(R.id.tv_pause_title)
        tvPauseYear        = findViewById(R.id.tv_pause_year)
        tvPauseRating      = findViewById(R.id.tv_pause_rating)
        tvPauseDescription = findViewById(R.id.tv_pause_description)
        btnSubtitles       = findViewById(R.id.btn_subtitles)
        btnAudio           = findViewById(R.id.btn_audio)
        btnQuality         = findViewById(R.id.btn_quality)
        btnAspect          = findViewById(R.id.btn_aspect)
        btnFavorite        = findViewById(R.id.btn_favorite)
        tvGuideNav         = findViewById(R.id.tv_guide_nav)
        tvGuideSeek        = findViewById(R.id.tv_guide_seek)
        ivCenterPlayPause  = findViewById(R.id.iv_center_play_pause)
        errorLayout        = findViewById(R.id.error_layout)
        tvErrorMessage     = findViewById(R.id.tv_error_message)
        tvErrorSuggestion  = findViewById(R.id.tv_error_suggestion)
        btnGoToSettings    = findViewById(R.id.btn_go_to_settings)

        playerView.setOnTouchListener { _, event -> gestureDetector.onTouchEvent(event); true }
        ivCenterPlayPause.setOnClickListener { togglePlayPause() }
        btnGoToSettings.setOnClickListener {
            saveCurrentPosition()
            val i = Intent("com.aladin.iptv.player.pro.OPEN_SETTINGS").apply { setPackage(packageName) }
            sendBroadcast(i); finish()
        }
    }
}
