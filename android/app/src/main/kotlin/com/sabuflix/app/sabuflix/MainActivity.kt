package com.sabuflix.app.sabuflix

import android.app.PictureInPictureParams
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val pipChannelName = "com.sabuflix.app/pip"
    private var pipChannel: MethodChannel? = null
    private var autoEnterPipEnabled = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, pipChannelName)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "setAutoEnter" -> {
                    autoEnterPipEnabled = call.argument<Boolean>("enabled") ?: false
                    result.success(null)
                }
                "enterPipMode" -> {
                    enterPip()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        pipChannel = channel
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        pipChannel?.setMethodCallHandler(null)
        pipChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (autoEnterPipEnabled) {
            enterPip()
        }
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun buildPipParams(): PictureInPictureParams {
        return PictureInPictureParams.Builder()
            .setAspectRatio(Rational(16, 9))
            .build()
    }

    private fun enterPip() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                enterPictureInPictureMode(buildPipParams())
            } catch (e: Exception) {
                // Some devices advertise PiP support but still refuse it at runtime; ignore.
            }
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pipChannel?.invokeMethod("onPipModeChanged", isInPictureInPictureMode)
    }
}
