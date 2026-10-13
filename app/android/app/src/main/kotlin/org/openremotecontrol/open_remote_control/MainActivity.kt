package org.openremotecontrol.open_remote_control

import android.content.pm.PackageManager
import android.Manifest
import android.content.Intent
import android.os.Build
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val permissionChannelName = "open_remote/permissions"
    private val localNetworkPermission = "android.permission.ACCESS_LOCAL_NETWORK"
    private val localNetworkRequestCode = 47653
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingNotificationResult: MethodChannel.Result? = null
    private val notificationRequestCode = 47655
    private var fullscreen = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "open_remote/preferences")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "requestNotificationPermission" -> {
                            if (Build.VERSION.SDK_INT < 33 || checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
                                result.success(true)
                            } else if (pendingNotificationResult != null) {
                                result.error("permission_pending", "A notification request is already active.", null)
                            } else {
                                pendingNotificationResult = result
                                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), notificationRequestCode)
                            }
                        }
                        "setBackgroundConnection" -> {
                            val service = Intent(this, ConnectionService::class.java)
                            if (call.argument<Boolean>("enabled") == true) {
                                service.putExtra("address", call.argument<String>("address"))
                                if (Build.VERSION.SDK_INT >= 26) startForegroundService(service) else startService(service)
                            } else { stopService(service) }
                            result.success(null)
                        }
                        "setDisplayPreferences" -> {
                            fullscreen = call.argument<Boolean>("fullscreen") == true
                            if (call.argument<Boolean>("keepScreenAwake") == true) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            } else { window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON) }
                            applyFullscreen()
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) { result.error("preferences_failed", error.message, null) }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, permissionChannelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "requestLocalNetworkAccess") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (Build.VERSION.SDK_INT < 37 || applicationInfo.targetSdkVersion < 37) {
                    result.success(true)
                    return@setMethodCallHandler
                }
                if (checkSelfPermission(localNetworkPermission) == PackageManager.PERMISSION_GRANTED) {
                    result.success(true)
                    return@setMethodCallHandler
                }
                if (pendingPermissionResult != null) {
                    result.error("permission_pending", "A local network permission request is already active.", null)
                    return@setMethodCallHandler
                }
                pendingPermissionResult = result
                requestPermissions(arrayOf(localNetworkPermission), localNetworkRequestCode)
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == notificationRequestCode) {
            pendingNotificationResult?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
            pendingNotificationResult = null
            return
        }
        if (requestCode != localNetworkRequestCode) return
        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
    }

    @Suppress("DEPRECATION")
    private fun applyFullscreen() {
        if (Build.VERSION.SDK_INT >= 30) {
            window.insetsController?.apply {
                systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                if (fullscreen) hide(WindowInsets.Type.systemBars()) else show(WindowInsets.Type.systemBars())
            }
        } else {
            val layout = View.SYSTEM_UI_FLAG_LAYOUT_STABLE or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            window.decorView.systemUiVisibility = if (fullscreen) layout or View.SYSTEM_UI_FLAG_FULLSCREEN or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY else layout
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) applyFullscreen()
    }

    override fun onDestroy() {
        stopService(Intent(this, ConnectionService::class.java))
        pendingPermissionResult?.error("activity_closed", "Activity closed.", null)
        pendingNotificationResult?.error("activity_closed", "Activity closed.", null)
        pendingPermissionResult = null
        pendingNotificationResult = null
        super.onDestroy()
    }
}
