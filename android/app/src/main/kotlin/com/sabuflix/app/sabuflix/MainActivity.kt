package com.sabuflix.app.sabuflix

import android.app.UiModeManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isTelevision" -> result.success(isTelevision())
                "setKeepScreenOn" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    setKeepScreenOn(enabled)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Whether this build is running on a television.
     *
     * Checked in the order of how much each signal can be trusted:
     *
     *  1. `UiModeManager` reporting TV mode — what Android itself uses to decide
     *     it is a leanback device, and what Google TV, Fire TV and every certified
     *     Android TV set report.
     *  2. The leanback system features, for devices whose UI mode is misreported
     *     (some cheap set-top boxes ship a phone-flavoured system image).
     *  3. No touchscreen at all — a strong hint that whatever this is, it is
     *     being driven with a remote or a mouse, not a finger.
     *
     * A false negative is not fatal: Ajustes has an explicit "Sempre TV" switch.
     */
    private fun isTelevision(): Boolean {
        val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
        if (uiModeManager?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION) {
            return true
        }

        val pm = packageManager
        return pm.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
            pm.hasSystemFeature(FEATURE_TELEVISION) ||
            pm.hasSystemFeature(FEATURE_LEANBACK_ONLY) ||
            !pm.hasSystemFeature(PackageManager.FEATURE_TOUCHSCREEN)
    }

    /**
     * Holds the panel awake while a video plays. A film runs far past any
     * screen timeout, and nothing touches the remote in the meantime.
     */
    private fun setKeepScreenOn(enabled: Boolean) {
        runOnUiThread {
            if (enabled) {
                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
        }
    }

    companion object {
        private const val CHANNEL = "sabuflix/tv"

        // Deprecated in the framework constants but still what older TV system
        // images report, so both spellings are checked.
        private const val FEATURE_TELEVISION = "android.hardware.type.television"
        private const val FEATURE_LEANBACK_ONLY = "android.software.leanback_only"
    }
}
