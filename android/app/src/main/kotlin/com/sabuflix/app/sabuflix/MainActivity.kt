package com.sabuflix.app.sabuflix

import android.content.Context
import android.content.Intent
import android.net.wifi.WifiManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openMirrorSettings" -> result.success(openMirrorSettings())
                "acquireMulticastLock" -> {
                    acquireMulticastLock()
                    result.success(null)
                }
                "releaseMulticastLock" -> {
                    releaseMulticastLock()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Opens the system's screen-mirroring picker.
     *
     * Mirroring is a system service — an app cannot start it for itself — and
     * the panel that owns it has moved between Android versions and vendors.
     * The candidates are tried in order of how directly they land on the cast
     * picker, ending at the display settings screen, which exists everywhere.
     */
    private fun openMirrorSettings(): Boolean {
        val candidates = listOf(
            "android.settings.CAST_SETTINGS",
            "android.settings.WIFI_DISPLAY_SETTINGS",
            Settings.ACTION_DISPLAY_SETTINGS,
        )

        for (action in candidates) {
            val intent = Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                startActivity(intent)
                return true
            } catch (e: Exception) {
                continue
            }
        }
        return false
    }

    /**
     * Android hands multicast packets to an app only while a lock is held.
     * Both discovery protocols this app uses are multicast — SSDP for DLNA and
     * mDNS for Google Cast — so without it the network looks empty.
     */
    private fun acquireMulticastLock() {
        if (multicastLock?.isHeld == true) return
        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager ?: return
        multicastLock = wifi.createMulticastLock("sabuflix-cast-discovery").apply {
            setReferenceCounted(true)
            acquire()
        }
    }

    private fun releaseMulticastLock() {
        val lock = multicastLock ?: return
        if (lock.isHeld) lock.release()
        multicastLock = null
    }

    override fun onDestroy() {
        releaseMulticastLock()
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "sabuflix/cast"
    }
}
