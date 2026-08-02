package com.sabuflix.app.sabuflix

import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges Android's system Picture-in-Picture window to the Flutter side.
 *
 * Android is the only target where the OS itself floats the app over other
 * apps; the other platforms fall back to Sabuflix's own mini player.
 */
class MainActivity : FlutterActivity() {

    private var channel: MethodChannel? = null

    /** Set from Dart while something is playing, so pressing Home floats it. */
    private var autoPipEnabled = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPip" -> {
                    val aspectRatio = call.argument<Double>("aspectRatio") ?: DEFAULT_ASPECT
                    result.success(enterPip(aspectRatio))
                }
                "setAutoPipEnabled" -> {
                    autoPipEnabled = call.arguments as? Boolean ?: false
                    result.success(null)
                }
                "isPipSupported" -> result.success(supportsPip())
                else -> result.notImplemented()
            }
        }
    }

    private fun supportsPip(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
    }

    // The SDK check is repeated inline in every method that touches the
    // API-26 surface: lint only recognises version guards in the same method,
    // and a release build runs lint.
    private fun enterPip(aspectRatio: Double): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        if (!packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)) {
            return false
        }
        return try {
            // Android rejects anything outside roughly 1:2.39 … 2.39:1.
            val clamped = aspectRatio.coerceIn(MIN_ASPECT, MAX_ASPECT)
            val rational = Rational((clamped * 1000).toInt(), 1000)
            val params = PictureInPictureParams.Builder().setAspectRatio(rational).build()
            enterPictureInPictureMode(params)
        } catch (e: IllegalStateException) {
            // Raised when the activity cannot go to PiP right now (already
            // finishing, for instance) — the caller falls back to the mini
            // player.
            false
        } catch (e: IllegalArgumentException) {
            false
        }
    }

    /** Pressing Home mid-episode floats the video instead of hiding it. */
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (autoPipEnabled && !isInPictureInPictureMode) {
            enterPip(DEFAULT_ASPECT)
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        channel?.invokeMethod("onPipModeChanged", isInPictureInPictureMode)
    }

    companion object {
        private const val CHANNEL_NAME = "com.sabuflix.app/pip"
        private const val DEFAULT_ASPECT = 16.0 / 9.0
        private const val MIN_ASPECT = 0.42
        private const val MAX_ASPECT = 2.39
    }
}
