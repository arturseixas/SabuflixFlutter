package com.sabuflix.app.sabuflix

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Holds Android's WiFi multicast lock while the app is scanning for TVs.
///
/// Without it, many Android devices silently drop the multicast mDNS
/// packets Chromecast discovery depends on to save battery — the scan
/// would then either find nothing or take far longer than it should.
class MainActivity : FlutterActivity() {
    private val channelName = "sabuflix/multicast_lock"
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "acquire" -> {
                    acquireLock()
                    result.success(null)
                }
                "release" -> {
                    releaseLock()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun acquireLock() {
        if (multicastLock?.isHeld == true) return
        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager ?: return
        val lock = wifiManager.createMulticastLock("sabuflixCastDiscovery")
        lock.setReferenceCounted(true)
        lock.acquire()
        multicastLock = lock
    }

    private fun releaseLock() {
        multicastLock?.let { if (it.isHeld) it.release() }
        multicastLock = null
    }

    override fun onDestroy() {
        releaseLock()
        super.onDestroy()
    }
}
