package org.openremotecontrol.open_remote_control

import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val permissionChannelName = "open_remote/permissions"
    private val localNetworkPermission = "android.permission.ACCESS_LOCAL_NETWORK"
    private val localNetworkRequestCode = 47653
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
        if (requestCode != localNetworkRequestCode) return
        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
    }
}
