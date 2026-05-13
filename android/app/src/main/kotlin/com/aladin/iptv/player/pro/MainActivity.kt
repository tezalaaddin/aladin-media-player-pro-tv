package com.aladin.iptv.player.pro

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayList

class MainActivity : FlutterActivity() {
    private val CHANNEL = "aladin/exoplayer"
    private var methodChannel: MethodChannel? = null

    private val playerReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                "com.aladin.iptv.player.pro.FAVORITE_TOGGLED" -> {
                    val url = intent.getStringExtra("url")
                    val isFavorite = intent.getBooleanExtra("isFavorite", false)
                    methodChannel?.invokeMethod("onFavoriteToggled", mapOf(
                        "url" to url,
                        "isFavorite" to isFavorite
                    ))
                }
                "com.aladin.iptv.player.pro.PROGRESS_UPDATE" -> {
                    val url = intent.getStringExtra("url")
                    val position = intent.getLongExtra("position", 0L)
                    val duration = intent.getLongExtra("duration", 0L)
                    methodChannel?.invokeMethod("onProgressUpdate", mapOf(
                        "url" to url,
                        "position" to position,
                        "duration" to duration
                    ))
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel
        
        channel.setMethodCallHandler { call, result ->
            if (call.method == "playNative") {
                val urls = call.argument<List<String>>("urls")
                val names = call.argument<List<String>>("names")
                val descriptions = call.argument<List<String>>("descriptions")
                val posters = call.argument<List<String>>("posters")
                val ratings = call.argument<List<String>>("ratings")
                val years = call.argument<List<String>>("years")
                val types = call.argument<List<String>>("types")
                val index = call.argument<Int>("index") ?: 0
                
                val intent = Intent(this, NativePlayerActivity::class.java).apply {
                    putStringArrayListExtra("URL_LIST", if (urls != null) ArrayList(urls) else ArrayList())
                    putStringArrayListExtra("NAME_LIST", if (names != null) ArrayList(names) else ArrayList())
                    putStringArrayListExtra("DESC_LIST", if (descriptions != null) ArrayList(descriptions) else ArrayList())
                    putStringArrayListExtra("POSTER_LIST", if (posters != null) ArrayList(posters) else ArrayList())
                    putStringArrayListExtra("RATING_LIST", if (ratings != null) ArrayList(ratings) else ArrayList())
                    putStringArrayListExtra("YEAR_LIST", if (years != null) ArrayList(years) else ArrayList())
                    putStringArrayListExtra("TYPE_LIST", if (types != null) ArrayList(types) else ArrayList())
                    putExtra("CURRENT_INDEX", index)
                }
                startActivity(intent)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
        
        val filter = IntentFilter().apply {
            addAction("com.aladin.iptv.player.pro.FAVORITE_TOGGLED")
            addAction("com.aladin.iptv.player.pro.PROGRESS_UPDATE")
        }
        registerReceiver(playerReceiver, filter)
    }

    override fun onDestroy() {
        unregisterReceiver(playerReceiver)
        super.onDestroy()
    }
}
