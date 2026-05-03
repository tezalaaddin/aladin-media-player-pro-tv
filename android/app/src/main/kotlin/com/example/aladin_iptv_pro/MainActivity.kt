package com.example.aladin_iptv_pro

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

    private val favoriteReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.example.aladin.FAVORITE_TOGGLED") {
                val url = intent.getStringExtra("url")
                val isFavorite = intent.getBooleanExtra("isFavorite", false)
                methodChannel?.invokeMethod("onFavoriteToggled", mapOf(
                    "url" to url,
                    "isFavorite" to isFavorite
                ))
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
                val index = call.argument<Int>("index") ?: 0
                
                val intent = Intent(this, NativePlayerActivity::class.java).apply {
                    putStringArrayListExtra("URL_LIST", if (urls != null) ArrayList(urls) else ArrayList())
                    putStringArrayListExtra("NAME_LIST", if (names != null) ArrayList(names) else ArrayList())
                    putExtra("CURRENT_INDEX", index)
                }
                startActivity(intent)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
        
        registerReceiver(favoriteReceiver, IntentFilter("com.example.aladin.FAVORITE_TOGGLED"))
    }

    override fun onDestroy() {
        unregisterReceiver(favoriteReceiver)
        super.onDestroy()
    }
}
