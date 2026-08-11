package com.sabuflix.app.sabuflix

import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.res.Configuration
import android.graphics.drawable.Icon
import android.net.wifi.WifiManager
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val multicastChannelName = "sabuflix/multicast_lock"
    private val pipChannelName = "sabuflix/pip"

    // --- Multicast lock (Chromecast/DLNA discovery) -----------------------
    // Holds Android's WiFi multicast lock while the app is scanning for TVs.
    // Without it, many Android devices silently drop the multicast mDNS
    // packets discovery depends on to save battery.
    private var multicastLock: WifiManager.MulticastLock? = null

    // --- Picture-in-Picture -------------------------------------------------
    private var pipChannel: MethodChannel? = null
    private var pipEligible = false
    private var pipIsPlaying = false
    private var pipActionReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, multicastChannelName).setMethodCallHandler { call, result ->
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

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, pipChannelName)
        pipChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" ->
                    result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                "setEligible" -> {
                    pipEligible = call.argument<Boolean>("eligible") ?: false
                    result.success(null)
                }
                "setPlaying" -> {
                    pipIsPlaying = call.argument<Boolean>("playing") ?: false
                    if (isInPictureInPictureMode) updatePipActions()
                    result.success(null)
                }
                "enter" -> {
                    enterPip()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        registerPipActionReceiver()
    }

    /// Wires up the play/pause button Android draws directly on the PiP
    /// window's system chrome — without this the PiP window is a silent,
    /// uncontrollable video, which is not how Netflix/YouTube's PiP behaves.
    private fun registerPipActionReceiver() {
        if (pipActionReceiver != null) return
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == ACTION_PLAY_PAUSE) {
                    pipChannel?.invokeMethod("togglePlayPause", null)
                }
            }
        }
        pipActionReceiver = receiver
        val filter = IntentFilter(ACTION_PLAY_PAUSE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(receiver, filter)
        }
    }

    private fun buildPipParams(): PictureInPictureParams? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return null

        val actionIcon = if (pipIsPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
        val actionTitle = if (pipIsPlaying) "Pausar" else "Reproduzir"
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            REQUEST_CODE_PLAY_PAUSE,
            Intent(ACTION_PLAY_PAUSE).setPackage(packageName),
            flags,
        )
        val action = RemoteAction(
            Icon.createWithResource(this, actionIcon),
            actionTitle,
            actionTitle,
            pendingIntent,
        )
        return PictureInPictureParams.Builder()
            .setAspectRatio(Rational(16, 9))
            .setActions(listOf(action))
            .build()
    }

    private fun enterPip() {
        val params = buildPipParams() ?: return
        try {
            enterPictureInPictureMode(params)
        } catch (e: Exception) {
            // Some devices report PiP support but refuse to grant it (low-RAM
            // devices, restricted profiles) — playback just stays full-screen.
        }
    }

    private fun updatePipActions() {
        val params = buildPipParams() ?: return
        setPictureInPictureParams(params)
    }

    /// Called when the user leaves the app (home button, app switcher) while
    /// this Activity is on screen — auto-enters PiP exactly like Netflix/
    /// YouTube do, instead of requiring an explicit tap on a PiP button.
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (pipEligible) {
            enterPip()
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pipChannel?.invokeMethod("modeChanged", isInPictureInPictureMode)
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
        pipActionReceiver?.let { unregisterReceiver(it) }
        pipActionReceiver = null
        super.onDestroy()
    }

    companion object {
        private const val ACTION_PLAY_PAUSE = "com.sabuflix.app.sabuflix.PIP_PLAY_PAUSE"
        private const val REQUEST_CODE_PLAY_PAUSE = 4321
    }
}
