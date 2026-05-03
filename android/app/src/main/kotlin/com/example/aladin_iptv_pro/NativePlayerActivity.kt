package com.example.aladin_iptv_pro

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
import com.example.aladin_iptv_pro.R

class NativePlayerActivity : AppCompatActivity() {
    private var player: ExoPlayer? = null
    private lateinit var playerView: PlayerView
    private lateinit var audioManager: AudioManager
    private lateinit var trackSelector: DefaultTrackSelector
    private lateinit var prefs: SharedPreferences
    
    private lateinit var channelInfoLayout: LinearLayout
    private lateinit var tvChannelName: TextView
    private lateinit var tvTimeInfo: TextView
    private lateinit var ivFavorite: ImageView
    private lateinit var seekBar: SeekBar
    private lateinit var keyGuideLayout: LinearLayout
    private lateinit var volumeLayout: LinearLayout
    private lateinit var tvVolumeLevel: TextView

    private var channelUrls: ArrayList<String>? = null
    private var channelNames: ArrayList<String>? = null
    private var currentIndex: Int = 0
    private var retryCount = 0
    private val MAX_RETRIES = 3

    private val mainHandler = Handler(Looper.getMainLooper())
    
    private val hideRunnable = Runnable { 
        channelInfoLayout.visibility = View.GONE
        volumeLayout.visibility = View.GONE
        keyGuideLayout.visibility = View.GONE
        seekBar.visibility = View.GONE
    }

    private val updateProgressAction = object : Runnable {
        override fun run() {
            player?.let { p ->
                if (p.isPlaying && p.duration != C.TIME_UNSET && p.duration > 0) {
                    val current = p.currentPosition
                    seekBar.progress = min(current, Int.MAX_VALUE.toLong()).toInt()
                    tvTimeInfo.text = String.format(Locale.getDefault(), "%s / %s", formatTime(current), formatTime(p.duration))
                }
            }
            mainHandler.postDelayed(this, 1000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN, WindowManager.LayoutParams.FLAG_FULLSCREEN)
        setContentView(R.layout.activity_player)

        prefs = getSharedPreferences("AladinPlayerPrefs", Context.MODE_PRIVATE)
        channelUrls = intent.getStringArrayListExtra("URL_LIST")
        channelNames = intent.getStringArrayListExtra("NAME_LIST")
        currentIndex = intent.getIntExtra("CURRENT_INDEX", 0)

        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        playerView = findViewById(R.id.native_player_view)
        channelInfoLayout = findViewById(R.id.channel_info_layout)
        tvChannelName = findViewById(R.id.tv_channel_name)
        tvTimeInfo = findViewById(R.id.tv_time_info)
        ivFavorite = findViewById(R.id.iv_favorite)
        seekBar = findViewById(R.id.player_seekbar)
        keyGuideLayout = findViewById(R.id.key_guide_layout)
        volumeLayout = findViewById(R.id.volume_layout)
        tvVolumeLevel = findViewById(R.id.tv_volume_level)

        // REALTEK İÇİN KRİTİK: İçeriği temizle ki dekoder kilitlenmesin
        // playerView.setKeepContentOnPlayerReset(false)
        // playerView.setShutterBackgroundColor(android.graphics.Color.BLACK)

        prepareAndPlay()
    }

    private fun prepareAndPlay() {
        releasePlayer()
        
        // REALTEK HARD RESET: Donanımın kendini toparlaması için 500ms bekle
        showStatus("Yükleniyor...")
        mainHandler.postDelayed({
            System.gc() // RAM temizliği zorla
            initializePlayer()
            playCurrentChannel()
        }, 500)
    }

    private fun initializePlayer() {
        val renderersFactory = DefaultRenderersFactory(this)
            .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_ON)
            .setEnableDecoderFallback(true) // Donanım (Realtek) çökerse yazılıma geç

        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(15000, 50000, 1500, 3000)
            .build()

        trackSelector = DefaultTrackSelector(this)
        trackSelector.parameters = trackSelector.buildUponParameters()
            .setMaxVideoSizeSd() // Realtek CPU yükünü azalt
            .setForceLowestBitrate(false)
            .build()

        player = ExoPlayer.Builder(this, renderersFactory)
            .setTrackSelector(trackSelector)
            .setLoadControl(loadControl)
            .setHandleAudioBecomingNoisy(true)
            .build()
        
        playerView.player = player
        playerView.useController = false

        player?.addListener(object : Player.Listener {
            override fun onPlayerError(error: PlaybackException) {
                Log.e("ALADIN", "Realtek Hata: ${error.errorCodeName}")
                if (retryCount < MAX_RETRIES) {
                    retryCount++
                    mainHandler.postDelayed({ prepareAndPlay() }, 2000)
                } else {
                    retryCount = 0
                    nextChannelOnError()
                }
            }

            override fun onPlaybackStateChanged(state: Int) {
                if (state == Player.STATE_READY) {
                    retryCount = 0
                    player?.let { p ->
                        if (p.duration != C.TIME_UNSET) {
                            seekBar.max = min(p.duration, Int.MAX_VALUE.toLong()).toInt()
                        }
                    }
                }
            }
        })
    }

    private fun playCurrentChannel() {
        val url = channelUrls?.getOrNull(currentIndex) ?: return
        val name = channelNames?.getOrNull(currentIndex) ?: "Kanal"

        tvChannelName.text = name
        updateFavoriteIcon(url)
        
        val mediaItem = MediaItem.fromUri(url)
        player?.setMediaItem(mediaItem, true)
        player?.prepare()
        
        val savedPos = prefs.getLong("pos_$url", 0L)
        if (savedPos > 0 && player?.duration != C.TIME_UNSET) {
            player?.seekTo(savedPos)
        }
        
        player?.play()
        showOSD()
    }

    private fun nextChannelOnError() {
        val size = channelUrls?.size ?: return
        if (currentIndex < size - 1) {
            currentIndex++
            prepareAndPlay()
        } else {
            showStatus("Yayın Açılamadı")
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        when (keyCode) {
            KeyEvent.KEYCODE_DPAD_UP -> { 
                saveCurrentPosition()
                if (currentIndex > 0) { currentIndex--; prepareAndPlay() }
                return true
            }
            KeyEvent.KEYCODE_DPAD_DOWN -> { 
                saveCurrentPosition()
                val size = channelUrls?.size ?: 1
                if (currentIndex < size - 1) { currentIndex++; prepareAndPlay() }
                return true
            }
            KeyEvent.KEYCODE_DPAD_RIGHT -> { 
                player?.let { p ->
                    val isLive = p.duration == C.TIME_UNSET
                    if (isLive) {
                        audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_RAISE, 0); showVolume()
                    } else {
                        val safePos = min(p.currentPosition + 15000, p.duration)
                        p.seekTo(safePos); showOSD(); showStatus("15sn >>")
                    }
                }
                return true
            }
            KeyEvent.KEYCODE_DPAD_LEFT -> { 
                player?.let { p ->
                    val isLive = p.duration == C.TIME_UNSET
                    if (isLive) {
                        audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_LOWER, 0); showVolume()
                    } else {
                        val safePos = max(p.currentPosition - 5000, 0L)
                        p.seekTo(safePos); showOSD(); showStatus("<< 5sn")
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
                player?.let { p ->
                    if (p.isPlaying) { p.pause(); showOSD(); showStatus("Duraklatıldı") }
                    else { p.play(); showOSD(); showStatus("Oynatılıyor") }
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
        val isFav = prefs.getBoolean("fav_$url", false)
        val newFavStatus = !isFav
        prefs.edit().putBoolean("fav_$url", newFavStatus).apply()
        updateFavoriteIcon(url)
        showStatus(if (newFavStatus) "Favorilere Eklendi" else "Favorilerden Çıkarıldı")

        val intent = Intent("com.example.aladin.FAVORITE_TOGGLED")
        intent.putExtra("url", url)
        intent.putExtra("isFavorite", newFavStatus)
        sendBroadcast(intent)
    }

    private fun updateFavoriteIcon(url: String) {
        val isFav = prefs.getBoolean("fav_$url", false)
        ivFavorite.setImageResource(if (isFav) android.R.drawable.btn_star_big_on else android.R.drawable.btn_star_big_off)
    }

    private fun saveCurrentPosition() {
        val url = channelUrls?.getOrNull(currentIndex) ?: return
        player?.let { p ->
            val isLive = p.duration == C.TIME_UNSET
            if (!isLive && p.duration > 0) {
                prefs.edit().putLong("pos_$url", p.currentPosition).apply()
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
                        C.TRACK_TYPE_TEXT -> format.label ?: format.language ?: "Altyazı ${availableTracks.size + 1}"
                        C.TRACK_TYPE_AUDIO -> format.label ?: format.language ?: "Ses ${availableTracks.size + 1}"
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
            showStatus(if (trackType == C.TRACK_TYPE_TEXT) "Altyazı: Kapalı" else "Ses: Kapalı")
        } else {
            val (groupIndex, trackIndex, label) = availableTracks[nextIdx]
            val group = typeGroups[groupIndex]
            p.trackSelectionParameters = p.trackSelectionParameters.buildUpon()
                .setTrackTypeDisabled(trackType, false)
                .setOverrideForType(TrackSelectionOverride(group.mediaTrackGroup, trackIndex))
                .build()
            
            val prefix = when(trackType) { 
                C.TRACK_TYPE_TEXT -> "Altyazı: " 
                C.TRACK_TYPE_AUDIO -> "Ses: " 
                else -> "Kalite: " 
            }
            showStatus("$prefix$label")
        }
    }

    private fun cycleAspectRatio() {
        val modes = intArrayOf(androidx.media3.ui.AspectRatioFrameLayout.RESIZE_MODE_FIT, androidx.media3.ui.AspectRatioFrameLayout.RESIZE_MODE_FILL, androidx.media3.ui.AspectRatioFrameLayout.RESIZE_MODE_ZOOM)
        val names = arrayOf("Sığdır", "Doldur", "Zoom")
        val current = playerView.resizeMode
        val next = (modes.indexOf(current) + 1) % modes.size
        playerView.resizeMode = modes[next]
        showStatus("Ekran: ${names[next]}")
    }

    private fun formatTime(ms: Long): String {
        val totalSecs = ms / 1000
        val mins = (totalSecs % 3600) / 60
        val secs = totalSecs % 60
        return String.format(Locale.getDefault(), "%02d:%02d", mins, secs)
    }

    private fun showOSD() {
        channelInfoLayout.visibility = View.VISIBLE
        keyGuideLayout.visibility = View.VISIBLE
        player?.let { p ->
            if (p.duration != C.TIME_UNSET) seekBar.visibility = View.VISIBLE
            else seekBar.visibility = View.GONE
            tvTimeInfo.visibility = View.VISIBLE
        }
        resetHideTimer()
    }

    private fun resetHideTimer() {
        mainHandler.removeCallbacks(hideRunnable)
        mainHandler.postDelayed(hideRunnable, 5000)
    }

    private fun showStatus(msg: String) {
        tvChannelName.text = msg
        channelInfoLayout.visibility = View.VISIBLE
        resetHideTimer()
    }

    private fun showVolume() {
        val current = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
        val max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        tvVolumeLevel.text = "%${(current * 100 / max)}"
        volumeLayout.visibility = View.VISIBLE
        resetHideTimer()
    }

    private fun releasePlayer() {
        mainHandler.removeCallbacks(updateProgressAction)
        mainHandler.removeCallbacks(hideRunnable)
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
        mainHandler.post(updateProgressAction)
    }

    override fun onPause() {
        super.onPause()
        mainHandler.removeCallbacks(updateProgressAction)
        saveCurrentPosition()
        if (isFinishing) releasePlayer()
    }

    override fun onDestroy() {
        super.onDestroy()
        releasePlayer()
    }
}
