package com.sabuflix.app.sabuflix

import android.app.PictureInPictureParams
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Adds system picture-in-picture on top of the in-app floating window.
 *
 * The in-app window floats over the rest of Sabuflix; this floats the video
 * over every other app, which is what picture-in-picture means outside the
 * app itself. Android has only offered it since API 26, so callers are told
 * whether it is available rather than having it fail silently.
 */
class MainActivity : FlutterActivity() {
    private val channel = "sabuflix/pip"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> result.success(isPipSupported())
                "enter" -> result.success(enterPip())
                else -> result.notImplemented()
            }
        }
    }

    private fun isPipSupported(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return packageManager.hasSystemFeature(
            android.content.pm.PackageManager.FEATURE_PICTURE_IN_PICTURE
        )
    }

    private fun enterPip(): Boolean {
        if (!isPipSupported()) return false
        return try {
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(16, 9))
                .build()
            enterPictureInPictureMode(params)
        } catch (e: IllegalStateException) {
            // Thrown when the activity is not in a state that allows PiP.
            false
        }
    }

    /**
     * Tells Dart when the window enters or leaves system picture-in-picture,
     * so the app can hide its own chrome while the window is thumbnail sized.
     */
    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        methodChannel?.invokeMethod("modeChanged", isInPictureInPictureMode)
    }
}
