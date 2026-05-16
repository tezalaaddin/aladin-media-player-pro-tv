package com.aladin.iptv.player.pro

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.media.AudioManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.SeekBar
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.common.PlaybackException
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.ui.PlayerView
import java.util.ArrayList
import java.util.Locale
import kotlin.math.max
import kotlin.math.min
import com.aladin.iptv.player.pro.R
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import java.net.URL
import java.util.concurrent.Executors

import android.view.GestureDetector
import android.view.MotionEvent
import kotlin.math.abs

class NativePlayerActivity : AppCompatActivity(), GestureDetector.OnGestureListener, GestureDetector.OnDoubleTapListener {
    
    companion object {
        init {
            try {
                System.loadLibrary("ffmpeg")
            } catch (t: Throwable) {
                android.util.Log.e("ALADIN_FFMPEG", "FFmpeg not found in jniLibs, using extension only")
            }
        }
    }

    private var player: ExoPlayer? = null
    private lateinit var playerView: PlayerView
    private lateinit var audioManager: AudioManager
    private lateinit var trackSelector: DefaultTrackSelector
    private lateinit var prefs: SharedPreferences
    private lateinit var gestureDetector: GestureDetector
    
    private lateinit var channelInfoLayout: LinearLayout
    private lateinit var tvChannelName: TextView
    private lateinit var tvTimeInfo: TextView
    private lateinit var ivFavorite: ImageView
    private lateinit var seekBar: SeekBar
    private lateinit var keyGuideLayout: LinearLayout
    private lateinit var volumeLayout: LinearLayout
    private lateinit var tvStatusOverlay: TextView
    private lateinit var tvVolumeLevel: TextView

    private lateinit var btnSubtitles: TextView
    private lateinit var btnAudio: TextView
    private lateinit var btnQuality: TextView
    private lateinit var btnAspect: TextView
    private lateinit var btnFavorite: TextView
    private lateinit var tvGuideNav: TextView
    private lateinit var tvGuideSeek: TextView

    // Pause Info Layout
    private lateinit var pauseInfoLayout: LinearLayout
    private lateinit var ivPausePoster: ImageView
    private lateinit var tvPauseTitle: TextView
    private lateinit var tvPauseYear: TextView
    private lateinit var tvPauseRating: TextView
    private lateinit var tvPauseDescription: TextView

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
    private var retryCount = 0
    private val MAX_RETRIES = 3

    // Buffering Timeout Logic
    private var bufferingRetryCount = 0
    private var isPersistentError = false
    
    private val bufferingStatusRunnable = Runnable {
        if (player?.playbackState == Player.STATE_BUFFERING && player?.playWhenReady == true) {
            showStatus(t("loading", "Bağlantı kontrol ediliyor..."), true)
        }
    }

    private val bufferingTimeoutRunnable = Runnable {
        if (bufferingRetryCount < 3) {
            bufferingRetryCount++
            Log.d("ALADIN", "Buffering timeout. Auto-retry #$bufferingRetryCount")
            prepareAndPlay()
        } else {
            isPersistentError = true
            showStatus("${t("error", "Hata")}\n${t("retry_ok", "Yeniden denemek için OK basın")}", true)
            // Keep OSD visible
            mainHandler.removeCallbacks(hideRunnable)
            channelInfoLayout.visibility = View.VISIBLE
        }
    }

    // Accumulative Seeking
    private var pendingSeekAmount: Long = 0
    private val seekHandler = Handler(Looper.getMainLooper())
    private val performSeekRunnable = Runnable {
        player?.let { p ->
            val targetPos = max(0L, min(p.currentPosition + pendingSeekAmount, p.duration))
            p.seekTo(targetPos)
            pendingSeekAmount = 0
            hideStatusDelayed()
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    
    private val hideStatusOverlayRunnable = Runnable {
        tvStatusOverlay.visibility = View.GONE
    }

    private val hideRunnable = Runnable { 
        channelInfoLayout.visibility = View.GONE
        volumeLayout.visibility = View.GONE
        keyGuideLayout.visibility = View.GONE
        seekBar.visibility = View.GONE
    }

    private val updateProgressAction = object : Runnable {
        override fun run() {
            player?.let { p ->
                val duration = p.duration
                if (duration != C.TIME_UNSET && duration > 0) {
                    val current = p.currentPosition
                    seekBar.progress = min(current, Int.MAX_VALUE.toLong()).toInt()
                    tvTimeInfo.text = String.format(Locale.getDefault(), "%s / %s", formatTime(current), formatTime(duration))
                    
                    if (p.isPlaying && current % 60000 < 1000) {
                        saveCurrentPosition()
                    }
                }
            }
            mainHandler.postDelayed(this, 1000)
        }
    }

    private val prepareRunnable = Runnable {
        initializePlayer()
        playCurrentChannel()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN, WindowManager.LayoutParams.FLAG_FULLSCREEN)
        setContentView(R.layout.activity_player)

        prefs = getSharedPreferences("AladinPlayerPrefs", Context.MODE_PRIVATE)
        channelUrls = intent.getStringArrayListExtra("URL_LIST")
        channelNames = intent.getStringArrayListExtra("NAME_LIST")
        channelDescs = intent.getStringArrayListExtra("DESC_LIST")
        channelPosters = intent.getStringArrayListExtra("POSTER_LIST")
        channelRatings = intent.getStringArrayListExtra("RATING_LIST")
        channelYears = intent.getStringArrayListExtra("YEAR_LIST")
        channelTypes = intent.getStringArrayListExtra("TYPE_LIST")
        channelFavs = (intent.getSerializableExtra("FAV_LIST") as? ArrayList<Boolean>) ?: ArrayList()
        channelPositions = (intent.getSerializableExtra("POS_LIST") as? ArrayList<Int>) ?: ArrayList()
        currentIndex = intent.getIntExtra("CURRENT_INDEX", 0)

        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        gestureDetector = GestureDetector(this, this)
        gestureDetector.setOnDoubleTapListener(this)

        playerView = findViewById(R.id.native_player_view)
        playerView.setOnTouchListener { _, event -> 
            gestureDetector.onTouchEvent(event)
            true 
        }

        channelInfoLayout = findViewById(R.id.channel_info_layout)
        tvChannelName = findViewById(R.id.tv_channel_name)
        tvTimeInfo = findViewById(R.id.tv_time_info)
        ivFavorite = findViewById(R.id.iv_favorite)
        seekBar = findViewById(R.id.player_seekbar)
        setupSeekBar()
        
        keyGuideLayout = findViewById(R.id.key_guide_layout)
        volumeLayout = findViewById(R.id.volume_layout)
        tvVolumeLevel = findViewById(R.id.tv_volume_level)
        tvStatusOverlay = findViewById(R.id.tv_status_overlay)

        tvPauseDescription = findViewById(R.id.tv_pause_description)

        ivPausePoster = findViewById(R.id.iv_pause_poster)
        tvPauseTitle = findViewById(R.id.tv_pause_title)
        tvPauseYear = findViewById(R.id.tv_pause_year)
        tvPauseRating = findViewById(R.id.tv_pause_rating)
        pauseInfoLayout = findViewById(R.id.pause_info_layout)

        btnSubtitles = findViewById(R.id.btn_subtitles)
        btnAudio = findViewById(R.id.btn_audio)
        btnQuality = findViewById(R.id.btn_quality)
        btnAspect = findViewById(R.id.btn_aspect)
        btnFavorite = findViewById(R.id.btn_favorite)
        tvGuideNav = findViewById(R.id.tv_guide_nav)
        tvGuideSeek = findViewById(R.id.tv_guide_seek)

        setupLabels()
        prepareAndPlay()
    }

    private fun setupSeekBar() {
        seekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(sb: SeekBar?, progress: Int, fromUser: Boolean) {
                if (fromUser) {
                    tvTimeInfo.text = formatTime(progress.toLong())
                }
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

    private fun setupLabels() {
        btnSubtitles.text = "● ${t("subtitles", "Altyazı")}"
        btnAudio.text = "● ${t("audio", "Ses")}"
        btnQuality.text = "● ${t("quality", "Kalite")}"
        btnAspect.text = "● ${t("aspect", "Oran")}"
        btnFavorite.text = "[0] ${t("favorites_short", "Favori")}"
        
        tvGuideNav.text = t("guide_channel", "↕ Kanal Değiştir")
        
        // Dynamic seek/volume guide based on content type
        val isLive = player?.duration == C.TIME_UNSET
        tvGuideSeek.text = if (isLive) t("guide_volume", "↔ Ses Ayarla") else t("guide_seek", "↔ İleri/Geri Sar")

        // Ensure buttons are not focusable to prevent them from capturing OK button on TV remotes
        val buttons = listOf(btnSubtitles, btnAudio, btnQuality, btnAspect, btnFavorite)
        buttons.forEach {
            it.isFocusable = false
            it.isFocusableInTouchMode = false
        }

        // Mobile Button Support (also works for non-focus TV navigation if ever used)
        btnSubtitles.setOnClickListener { cycleTracks(C.TRACK_TYPE_TEXT) }
        btnAudio.setOnClickListener { cycleTracks(C.TRACK_TYPE_AUDIO) }
        btnQuality.setOnClickListener { cycleTracks(C.TRACK_TYPE_VIDEO) }
        btnAspect.setOnClickListener { cycleAspectRatio() }
        btnFavorite.setOnClickListener { toggleFavorite() }

        // Star icon is now informational only (passive) as requested
    }

    // --- Gesture Implementation ---

    override fun onSingleTapConfirmed(e: MotionEvent): Boolean {
        if (channelInfoLayout.visibility == View.VISIBLE) {
            hideRunnable.run()
        } else {
            showOSD()
        }
        return true
    }

    override fun onDoubleTap(e: MotionEvent): Boolean {
        togglePlayPause()
        return true
    }

    override fun onDoubleTapEvent(e: MotionEvent): Boolean = false

    override fun onDown(e: MotionEvent): Boolean = true
    override fun onShowPress(e: MotionEvent) {}
    override fun onSingleTapUp(e: MotionEvent): Boolean = false
    override fun onScroll(e1: MotionEvent?, e2: MotionEvent, distanceX: Float, distanceY: Float): Boolean = false
    override fun onLongPress(e: MotionEvent) { toggleFavorite() }

    override fun onFling(e1: MotionEvent?, e2: MotionEvent, velocityX: Float, velocityY: Float): Boolean {
        if (e1 == null) return false
        val diffX = e2.x - e1.x
        val diffY = e2.y - e1.y
        
        if (abs(diffX) > abs(diffY)) {
            // Horizontal Swipe
            if (abs(diffX) > 100 && abs(velocityX) > 100) {
                player?.let { p ->
                    if (p.duration != C.TIME_UNSET && p.duration > 0) {
                        // VOD - Accumulative Seeking
                        val amount = if (diffX > 0) 30000L else -10000L
                        accumulateSeek(amount)
                    } else {
                        // Live - Volume
                        if (diffX > 0) {
                            audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_RAISE, 0)
                        } else {
                            audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_LOWER, 0)
                        }
                        showVolume()
                    }
                }
            }
        } else {
            // Vertical Swipe
            if (abs(diffY) > 100 && abs(velocityY) > 100) {
                if (diffY > 0) {
                    // Swipe Down -> Next
                    val size = channelUrls?.size ?: 1
                    if (currentIndex < size - 1) { currentIndex++; prepareAndPlay() }
                } else {
                    // Swipe Up -> Previous
                    if (currentIndex > 0) { currentIndex--; prepareAndPlay() }
                }
            }
        }
        return true
    }

    private fun accumulateSeek(amountMs: Long) {
        seekHandler.removeCallbacks(performSeekRunnable)
        pendingSeekAmount += amountMs
        
        player?.let { p ->
            val targetPos = max(0L, min(p.currentPosition + pendingSeekAmount, p.duration))
            val sign = if (pendingSeekAmount > 0) "+" else "-"
            val absAmount = abs(pendingSeekAmount) / 1000
            
            // Show: Target Time (+Amount)
            showStatus("${formatTime(targetPos)} ($sign${absAmount}s)")
            seekBar.progress = min(targetPos, Int.MAX_VALUE.toLong()).toInt()
        }
        
        channelInfoLayout.visibility = View.VISIBLE
        seekBar.visibility = View.VISIBLE
        
        seekHandler.postDelayed(performSeekRunnable, 800)
    }

    private fun hideStatusDelayed() {
        mainHandler.removeCallbacks(hideRunnable)
        mainHandler.postDelayed(hideRunnable, 2000)
    }

    private fun togglePlayPause() {
        player?.let { p ->
            if (p.isPlaying) { p.pause(); showOSD() }
            else { p.play(); showOSD() }
        }
    }

    // --- End Gestures ---

    private fun t(key: String, default: String): String {
        return intent.getStringExtra("i18n_$key") ?: default
    }

    private fun prepareAndPlay() {
        mainHandler.removeCallbacks(prepareRunnable)
        releasePlayer()
        
        showStatus(t("loading", "Yükleniyor..."))
        pauseInfoLayout.visibility = View.GONE
        
        // DEBOUNCE & REALTEK RESET
        mainHandler.postDelayed(prepareRunnable, 500)
    }

    private fun initializePlayer() {
        if (player != null) return // Already initialized

        // 1. Renderers Factory: Extension (FFmpeg) desteğini aktif et
        val renderersFactory = DefaultRenderersFactory(this)
            .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_PREFER)
            .setEnableDecoderFallback(true)

        // 2. LoadControl (Buffer Ayarları)
        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(30000, 60000, 2500, 5000)
            .setPrioritizeTimeOverSizeThresholds(true)
            .build()

        // 3. Track Selector (Stereo Downmix)
        trackSelector = DefaultTrackSelector(this)
        trackSelector.parameters = trackSelector.buildUponParameters()
            .setMaxVideoSizeSd()
            .setMaxAudioChannelCount(2) // Cihaz desteklemiyorsa 2 kanala düşür
            .build()

        val audioAttributes = AudioAttributes.Builder()
            .setUsage(C.USAGE_MEDIA)
            .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE)
            .build()

        // 4. Player Oluşturma
        player = ExoPlayer.Builder(this, renderersFactory)
            .setTrackSelector(trackSelector)
            .setLoadControl(loadControl)
            .setHandleAudioBecomingNoisy(true)
            .setAudioAttributes(audioAttributes, true)
            .build()
        
        player?.setVideoScalingMode(C.VIDEO_SCALING_MODE_SCALE_TO_FIT_WITH_CROPPING)
        
        playerView.player = player
        playerView.useController = false

        player?.addListener(object : Player.Listener {
            override fun onPlayerError(error: PlaybackException) {
                if (retryCount < MAX_RETRIES) {
                    retryCount++
                    mainHandler.postDelayed({ prepareAndPlay() }, 2000)
                } else {
                    retryCount = 0
                    nextChannelOnError()
                }
            }

            override fun onTracksChanged(tracks: Tracks) {
                for (group in tracks.groups) {
                    if (group.type == C.TRACK_TYPE_AUDIO) {
                        for (i in 0 until group.length) {
                            val format = group.getTrackFormat(i)
                            val isSupported = group.isTrackSupported(i)
                            Log.d("ALADIN_AUDIO", "Ses kanalı: ${format.sampleMimeType}, Dil: ${format.language}, Destek: $isSupported")
                            
                            if (!isSupported) {
                                showStatus("${t("audio_not_supported", "Ses formatı desteklenmiyor")}: ${format.sampleMimeType?.substringAfter("/")}", false)
                            }
                        }
                    }
                }
            }

            override fun onPlaybackStateChanged(state: Int) {
                when (state) {
                    Player.STATE_BUFFERING -> {
                        // Start 5s delay for showing "Connecting..." status
                        mainHandler.removeCallbacks(bufferingStatusRunnable)
                        mainHandler.postDelayed(bufferingStatusRunnable, 5000)
                        
                        // Start 15s timeout for auto-retry
                        mainHandler.removeCallbacks(bufferingTimeoutRunnable)
                        mainHandler.postDelayed(bufferingTimeoutRunnable, 15000)
                    }
                    Player.STATE_READY -> {
                        retryCount = 0
                        bufferingRetryCount = 0
                        isPersistentError = false
                        mainHandler.removeCallbacks(bufferingStatusRunnable)
                        mainHandler.removeCallbacks(bufferingTimeoutRunnable)
                        
                        tvStatusOverlay.visibility = View.GONE
                        
                        player?.let { p ->
                            if (p.duration != C.TIME_UNSET) {
                                seekBar.max = min(p.duration, Int.MAX_VALUE.toLong()).toInt()
                            }
                        }
                    }
                    Player.STATE_ENDED -> {
                        mainHandler.removeCallbacks(bufferingTimeoutRunnable)
                    }
                    Player.STATE_IDLE -> {
                        // Keep it for now
                    }
                }
            }

            override fun onIsPlayingChanged(isPlaying: Boolean) {
                if (!isPlaying && player?.playbackState != Player.STATE_BUFFERING) {
                    updatePauseInfo()
                } else {
                    pauseInfoLayout.visibility = View.GONE
                }
            }
        })
    }

    private fun playCurrentChannel() {
        val url = channelUrls?.getOrNull(currentIndex) ?: return
        val name = channelNames?.getOrNull(currentIndex) ?: "Kanal"

        tvChannelName.text = name
        updateFavoriteIcon()
        
        val mediaItem = MediaItem.fromUri(url)
        player?.setMediaItem(mediaItem, true)
        player?.prepare()
        
        // Initial seek from Flutter data
        val savedPos = channelPositions.getOrNull(currentIndex)?.toLong() ?: 0L
        if (savedPos > 0) {
            player?.seekTo(savedPos * 1000)
        }
        
        player?.play()
        showOSD()
    }

    private fun updatePauseInfo() {
        val type = channelTypes?.getOrNull(currentIndex) ?: "tv"
        if (type == "tv") {
            pauseInfoLayout.visibility = View.GONE
            return
        }

        val name = channelNames?.getOrNull(currentIndex) ?: ""
        val desc = channelDescs?.getOrNull(currentIndex) ?: ""
        val poster = channelPosters?.getOrNull(currentIndex) ?: ""
        val rating = channelRatings?.getOrNull(currentIndex) ?: ""
        val year = channelYears?.getOrNull(currentIndex) ?: ""

        tvPauseTitle.text = name
        tvPauseDescription.text = desc
        tvPauseRating.text = if (rating.isNotEmpty()) "⭐ $rating/10" else ""
        tvPauseYear.text = year
        
        if (poster.isNotEmpty()) {
            ivPausePoster.visibility = View.VISIBLE
            loadPoster(poster)
        } else {
            ivPausePoster.visibility = View.GONE
        }
        
        pauseInfoLayout.visibility = View.VISIBLE
    }

    private fun loadPoster(posterUrl: String) {
        executor.execute {
            try {
                val inputStream = URL(posterUrl).openStream()
                val bitmap = BitmapFactory.decodeStream(inputStream)
                mainHandler.post {
                    ivPausePoster.setImageBitmap(bitmap)
                }
            } catch (e: Exception) {
                Log.e("ALADIN", "Poster Load Error: $e")
            }
        }
    }

    private fun nextChannelOnError() {
        val size = channelUrls?.size ?: return
        if (currentIndex < size - 1) {
            currentIndex++
            prepareAndPlay()
        } else {
            showStatus(t("error", "Yayın Açılamadı"))
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        when (keyCode) {
            KeyEvent.KEYCODE_DPAD_UP -> { 
                if (currentIndex > 0) { currentIndex--; prepareAndPlay() }
                return true
            }
            KeyEvent.KEYCODE_DPAD_DOWN -> { 
                val size = channelUrls?.size ?: 1
                if (currentIndex < size - 1) { currentIndex++; prepareAndPlay() }
                return true
            }
            KeyEvent.KEYCODE_DPAD_RIGHT -> { 
                player?.let { p ->
                    if (p.duration == C.TIME_UNSET) {
                        audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_RAISE, 0); showVolume()
                    } else {
                        accumulateSeek(30000L)
                    }
                }
                return true
            }
            KeyEvent.KEYCODE_DPAD_LEFT -> { 
                player?.let { p ->
                    if (p.duration == C.TIME_UNSET) {
                        audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_LOWER, 0); showVolume()
                    } else {
                        accumulateSeek(-10000L)
                    }
                }
                return true
            }
            KeyEvent.KEYCODE_PROG_RED, KeyEvent.KEYCODE_F1 -> { cycleTracks(C.TRACK_TYPE_TEXT); return true }
            KeyEvent.KEYCODE_PROG_GREEN, KeyEvent.KEYCODE_F2 -> { cycleTracks(C.TRACK_TYPE_AUDIO); return true }
            KeyEvent.KEYCODE_PROG_YELLOW, KeyEvent.KEYCODE_F3 -> { cycleTracks(C.TRACK_TYPE_VIDEO); return true }
            KeyEvent.KEYCODE_PROG_BLUE, KeyEvent.KEYCODE_F4 -> { cycleAspectRatio(); return true }
            KeyEvent.KEYCODE_0, KeyEvent.KEYCODE_NUMPAD_0 -> { toggleFavorite(); return true }
            KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER -> {
                if (isPersistentError) {
                    bufferingRetryCount = 0
                    isPersistentError = false
                    prepareAndPlay()
                } else {
                    player?.let { p ->
                        if (p.isPlaying) { p.pause(); showOSD() }
                        else { p.play(); showOSD() }
                    }
                }
                return true
            }
            KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_ESCAPE -> { 
                saveCurrentPosition()
                finish()
                return true
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    private fun toggleFavorite() {
        val url = channelUrls?.getOrNull(currentIndex) ?: return
        val isFav = channelFavs.getOrNull(currentIndex) ?: false
        val newFavStatus = !isFav
        
        // Update local state
        if (currentIndex < channelFavs.size) {
            channelFavs[currentIndex] = newFavStatus
        }
        
        updateFavoriteIcon()
        showStatus(if (newFavStatus) t("added", "Favorilere Eklendi") else t("removed", "Favorilerden Çıkarıldı"))

        // Send to Flutter with explicit package targeting for modern Android security
        val intent = Intent("com.aladin.iptv.player.pro.FAVORITE_TOGGLED")
        intent.setPackage(packageName)
        intent.putExtra("url", url)
        intent.putExtra("isFavorite", newFavStatus)
        sendBroadcast(intent)
    }

    private fun updateFavoriteIcon() {
        val isFav = channelFavs.getOrNull(currentIndex) ?: false
        ivFavorite.setImageResource(if (isFav) android.R.drawable.btn_star_big_on else android.R.drawable.btn_star_big_off)
    }

    private fun saveCurrentPosition() {
        val url = channelUrls?.getOrNull(currentIndex) ?: return
        player?.let { p ->
            val duration = p.duration
            if (duration != C.TIME_UNSET && duration > 0) {
                val pos = p.currentPosition
                prefs.edit().putLong("pos_$url", pos).apply()
                
                // Broadcast for Flutter to save to DB (Continue Watching)
                val intent = Intent("com.aladin.iptv.player.pro.PROGRESS_UPDATE")
                intent.setPackage(packageName)
                intent.putExtra("url", url)
                intent.putExtra("position", pos)
                intent.putExtra("duration", duration)
                sendBroadcast(intent)
            }
        }
    }

    private fun cycleTracks(trackType: Int) {
        val p = player ?: return
        val tracks = p.currentTracks
        val typeGroups = tracks.groups.filter { it.type == trackType }
        if (typeGroups.isEmpty()) return
        
        val availableTracks = mutableListOf<Triple<Int, Int, String>>()
        typeGroups.forEachIndexed { gIdx, group ->
            for (tIdx in 0 until group.length) {
                if (group.isTrackSupported(tIdx)) {
                    val format = group.getTrackFormat(tIdx)
                    val label = when(trackType) {
                        C.TRACK_TYPE_TEXT -> format.label ?: format.language ?: "${t("subtitles", "Altyazı")} ${availableTracks.size + 1}"
                        C.TRACK_TYPE_AUDIO -> format.label ?: format.language ?: "${t("audio", "Ses")} ${availableTracks.size + 1}"
                        else -> "${format.width}x${format.height}"
                    }
                    availableTracks.add(Triple(gIdx, tIdx, label))
                }
            }
        }

        if (availableTracks.isEmpty()) return

        var currentSelectedIdx = -1
        for (i in 0 until availableTracks.size) {
            val (gIdx, tIdx, _) = availableTracks[i]
            if (typeGroups[gIdx].isTrackSelected(tIdx)) {
                currentSelectedIdx = i
                break
            }
        }

        val nextIdx = (currentSelectedIdx + 1) % (availableTracks.size + (if (trackType == C.TRACK_TYPE_VIDEO) 0 else 1))
        
        if (nextIdx == availableTracks.size) {
            p.trackSelectionParameters = p.trackSelectionParameters.buildUpon()
                .setTrackTypeDisabled(trackType, true)
                .clearOverridesOfType(trackType)
                .build()
            showStatus(if (trackType == C.TRACK_TYPE_TEXT) "${t("subtitles", "Altyazı")}: ${t("off", "Kapalı")}" else "${t("audio", "Ses")}: ${t("off", "Kapalı")}")
        } else {
            val (groupIndex, trackIndex, label) = availableTracks[nextIdx]
            val group = typeGroups[groupIndex]
            p.trackSelectionParameters = p.trackSelectionParameters.buildUpon()
                .setTrackTypeDisabled(trackType, false)
                .setOverrideForType(TrackSelectionOverride(group.mediaTrackGroup, trackIndex))
                .build()
            
            val prefix = when(trackType) { 
                C.TRACK_TYPE_TEXT -> "${t("subtitles", "Altyazı")}: " 
                C.TRACK_TYPE_AUDIO -> "${t("audio", "Ses")}: " 
                else -> "${t("quality", "Kalite")}: " 
            }
            showStatus("$prefix$label")
        }
    }

    private fun cycleAspectRatio() {
        val modes = intArrayOf(androidx.media3.ui.AspectRatioFrameLayout.RESIZE_MODE_FIT, androidx.media3.ui.AspectRatioFrameLayout.RESIZE_MODE_FILL, androidx.media3.ui.AspectRatioFrameLayout.RESIZE_MODE_ZOOM)
        val names = arrayOf(t("aspect_fit", "Sığdır"), t("aspect_fill", "Doldur"), t("aspect_zoom", "Zoom"))
        val current = playerView.resizeMode
        val next = (modes.indexOf(current) + 1) % modes.size
        playerView.resizeMode = modes[next]
        showStatus("${t("aspect", "Ekran Oranı")}: ${names[next]}")
    }

    private fun formatTime(ms: Long): String {
        val totalSecs = ms / 1000
        val hours = totalSecs / 3600
        val mins = (totalSecs % 3600) / 60
        val secs = totalSecs % 60
        return if (hours > 0) {
            String.format(Locale.getDefault(), "%02d:%02d:%02d", hours, mins, secs)
        } else {
            String.format(Locale.getDefault(), "%02d:%02d", mins, secs)
        }
    }

    private fun showOSD() {
        channelInfoLayout.visibility = View.VISIBLE
        keyGuideLayout.visibility = View.VISIBLE
        player?.let { p ->
            if (p.duration != C.TIME_UNSET && p.duration > 0) seekBar.visibility = View.VISIBLE
            else seekBar.visibility = View.GONE
            tvTimeInfo.visibility = View.VISIBLE
        }
        resetHideTimer()
    }

    private fun resetHideTimer() {
        mainHandler.removeCallbacks(hideRunnable)
        mainHandler.postDelayed(hideRunnable, 5000)
    }

    private fun showStatus(msg: String, persistent: Boolean = false) {
        tvStatusOverlay.text = msg
        tvStatusOverlay.visibility = View.VISIBLE
        
        mainHandler.removeCallbacks(hideStatusOverlayRunnable)
        if (!persistent) {
            mainHandler.postDelayed(hideStatusOverlayRunnable, 3000)
        }
    }

    private fun showVolume() {
        val current = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
        val max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        tvVolumeLevel.text = "%${(current * 100 / max)}"
        volumeLayout.visibility = View.VISIBLE
        resetHideTimer()
    }

    private fun releasePlayer() {
        player?.let { p ->
            p.stop()
            p.clearMediaItems()
            p.release()
        }
        player = null
        playerView.player = null
    }

    override fun onResume() {
        super.onResume()
        player?.play()
        mainHandler.post(updateProgressAction)
    }

    override fun onPause() {
        super.onPause()
        player?.pause()
        mainHandler.removeCallbacks(updateProgressAction)
        saveCurrentPosition()
        if (isFinishing) releasePlayer()
    }

    override fun onDestroy() {
        super.onDestroy()
        releasePlayer()
        executor.shutdown()
    }
}
