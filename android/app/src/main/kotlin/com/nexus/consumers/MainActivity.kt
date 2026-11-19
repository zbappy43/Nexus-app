package com.nexus.consumers

import android.content.Intent
import android.content.pm.ApplicationInfo
import android.os.Build
import android.os.Bundle
import android.os.Debug
import android.view.WindowManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.function.Consumer

/**
 * Single activity hosting the Flutter UI.
 *
 * Extends [FlutterFragmentActivity] because `local_auth` shows the
 * BiometricPrompt as a fragment.
 *
 * Native responsibilities:
 *  - FLAG_SECURE (blocks screenshots / screen recording / recents thumbnail).
 *  - Screen recording detection on Android 15+.
 *  - Refusing to run under an attached debugger in release builds.
 *  - Delivering App Links and custom-scheme deep links to Dart.
 */
class MainActivity : FlutterFragmentActivity() {

    private var securityChannel: MethodChannel? = null
    private var deepLinkChannel: MethodChannel? = null
    private var initialLink: String? = null
    private var recordingCallbackRegistered = false

    private val screenRecordingCallback = Consumer<Int> { state ->
        val recording = Build.VERSION.SDK_INT >= 35 &&
            state == WindowManager.SCREEN_RECORDING_STATE_VISIBLE
        runOnUiThread { securityChannel?.invokeMethod("onScreenRecordingChanged", recording) }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Secure by default before the first frame is drawn; Dart may relax it.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
        super.onCreate(savedInstanceState)

        if (!isDebuggableBuild() && Debug.isDebuggerConnected()) {
            finishAffinity()
            return
        }
        initialLink = extractLink(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        securityChannel = MethodChannel(messenger, SECURITY_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        if (enabled) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        deepLinkChannel = MethodChannel(messenger, DEEP_LINK_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialLink" -> {
                        result.success(initialLink)
                        initialLink = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        extractLink(intent)?.let { link -> deepLinkChannel?.invokeMethod("onLink", link) }
    }

    override fun onStart() {
        super.onStart()
        if (Build.VERSION.SDK_INT >= 35 && !recordingCallbackRegistered) {
            val initialState = windowManager.addScreenRecordingCallback(
                ContextCompat.getMainExecutor(this),
                screenRecordingCallback,
            )
            recordingCallbackRegistered = true
            screenRecordingCallback.accept(initialState)
        }
    }

    override fun onStop() {
        if (Build.VERSION.SDK_INT >= 35 && recordingCallbackRegistered) {
            windowManager.removeScreenRecordingCallback(screenRecordingCallback)
            recordingCallbackRegistered = false
        }
        super.onStop()
    }

    override fun onDestroy() {
        securityChannel?.setMethodCallHandler(null)
        deepLinkChannel?.setMethodCallHandler(null)
        super.onDestroy()
    }

    private fun extractLink(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_VIEW) return null
        return intent.dataString?.takeIf { it.isNotBlank() }
    }

    private fun isDebuggableBuild(): Boolean =
        (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

    private companion object {
        const val SECURITY_CHANNEL = "com.nexus.consumers/security"
        const val DEEP_LINK_CHANNEL = "com.nexus.consumers/deeplinks"
    }
}
