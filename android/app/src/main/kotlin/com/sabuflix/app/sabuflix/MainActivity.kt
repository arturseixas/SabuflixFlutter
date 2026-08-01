package com.sabuflix.app.sabuflix

import android.app.PictureInPictureParams
import android.content.Context
import android.content.res.Configuration
import android.net.wifi.WifiManager
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val pipMethodChannel = "sabuflix/pip"
    private val pipEventChannel = "sabuflix/pip_events"
    private val multicastMethodChannel = "sabuflix/multicast"

    private var pipEventSink: EventChannel.EventSink? = null
    private var isPlaybackActive = false

    // Android drops incoming multicast/broadcast packets by default to save
    // battery, which silently breaks SSDP (DLNA) and mDNS (Chromecast)
    // discovery. Holding this lock while discovering is what makes them work.
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, pipMethodChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enterPip" -> result.success(enterPip())
                    "setPlaybackActive" -> {
                        isPlaybackActive = call.argument<Boolean>("active") ?: false
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, pipEventChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    pipEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    pipEventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, multicastMethodChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquire" -> {
                        acquireMulticastLock()
                        result.success(null)
                    }
                    "release" -> {
                        releaseMulticastLock()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun acquireMulticastLock() {
        if (multicastLock?.isHeld == true) return
        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
        val lock = wifiManager?.createMulticastLock("sabuflix_cast_discovery")
        lock?.setReferenceCounted(true)
        lock?.acquire()
        multicastLock = lock
    }

    private fun releaseMulticastLock() {
        if (multicastLock?.isHeld == true) {
            multicastLock?.release()
        }
        multicastLock = null
    }

    override fun onDestroy() {
        releaseMulticastLock()
        super.onDestroy()
    }

    private fun enterPip(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return try {
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(16, 9))
                .build()
            enterPictureInPictureMode(params)
            true
        } catch (e: Exception) {
            false
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (isPlaybackActive) {
            enterPip()
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pipEventSink?.success(isInPictureInPictureMode)
    }
}
