package org.openremotecontrol.open_remote_control

import android.content.pm.PackageManager
import android.Manifest
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.os.Build
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import org.json.JSONObject
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    private val permissionChannelName = "open_remote/permissions"
    private val localNetworkPermission = "android.permission.ACCESS_LOCAL_NETWORK"
    private val localNetworkRequestCode = 47653
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingNotificationResult: MethodChannel.Result? = null
    private val notificationRequestCode = 47655
    private val updatePermissionRequestCode = 47657
    private val updateInstallRequestCode = 47658
    private var updateEvents: EventChannel? = null
    private var updateEventSink: EventChannel.EventSink? = null
    private var updatePermissionPending = false
    private var updateInstallPending = false
    private var fullscreen = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Remove only updater-owned leftovers from a prior process before the UI
        // can offer another approved download.
        try { AndroidUpdateRuntime.initialize(this) } catch (_: Exception) { }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "open_remote/updates")
            .setMethodCallHandler { call, result -> handleUpdateMethod(call.method, call.arguments, result) }
        updateEvents = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "open_remote/update_events")
        updateEvents?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                updateEventSink?.let { AndroidUpdateRuntime.removeObserver(it) }
                updateEventSink = events
                AndroidUpdateRuntime.addObserver(events)
            }
            override fun onCancel(arguments: Any?) {
                updateEventSink?.let { AndroidUpdateRuntime.removeObserver(it) }
                updateEventSink = null
            }
        })
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "open_remote/device_identity")
            .setMethodCallHandler { call, result ->
                if (call.method != "getDeviceIdentity") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    val manufacturer = cleanDeviceValue(Build.MANUFACTURER, 64)
                    val model = cleanDeviceValue(Build.MODEL, 64)
                    val deviceName = if (Build.VERSION.SDK_INT >= 25) {
                        try {
                            cleanDeviceValue(
                                Settings.Global.getString(contentResolver, Settings.Global.DEVICE_NAME),
                                64,
                            )
                        } catch (_: Exception) {
                            ""
                        }
                    } else {
                        ""
                    }
                    val fallbackName = cleanDeviceValue(when {
                        model.isEmpty() -> manufacturer.ifEmpty { "Android" }
                        manufacturer.isEmpty() || model.contains(manufacturer, ignoreCase = true) -> model
                        else -> "$manufacturer $model"
                    }, 64)
                    result.success(
                        mapOf(
                            "clientName" to deviceName.ifEmpty { fallbackName },
                            "clientModel" to model,
                            "clientAndroidVersion" to cleanDeviceValue(Build.VERSION.RELEASE, 32),
                        ),
                    )
                } catch (_: Exception) {
                    // Device metadata is optional and must never prevent a connection.
                    result.success(mapOf("clientName" to "Android"))
                }
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

    private fun handleUpdateMethod(method: String, arguments: Any?, result: MethodChannel.Result) {
        try {
            when (method) {
                "getDeviceInfo" -> result.success(AndroidUpdateRuntime.deviceInfo(this))
                "getState" -> result.success(AndroidUpdateRuntime.snapshot())
                "download" -> {
                    val args = arguments as? Map<*, *> ?: throw UpdateFailure("invalidPackage", "Update request is invalid.")
                    @Suppress("UNCHECKED_CAST")
                    val candidate = args["candidate"] as? Map<String, Any?>
                        ?: throw UpdateFailure("invalidPackage", "Update candidate is missing.")
                    val parsed = UpdateCandidate.from(candidate)
                    if (parsed.packageName != packageName) throw UpdateFailure("identity", "Update package does not match this app.")
                    val notification = args["notification"] as? Map<*, *> ?: emptyMap<Any, Any>()
                    val candidateJson = JSONObject(candidate).toString()
                    val token = AndroidUpdateRuntime.begin(candidate)
                        ?: throw UpdateFailure("busy", "Another update operation is already active.")
                    val intent = Intent(this, AndroidUpdateService::class.java)
                        .putExtra(AndroidUpdateService.EXTRA_CANDIDATE, candidateJson)
                        .putExtra(AndroidUpdateService.EXTRA_TOKEN, token)
                    listOf("title", "downloading", "validating", "ready", "cancel").forEach { key ->
                        (notification[key] as? String)?.let { intent.putExtra(key, it) }
                    }
                    (notification["channelName"] as? String)?.let { intent.putExtra("channelName", it) }
                    try {
                        if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
                    } catch (failure: Exception) {
                        AndroidUpdateRuntime.cleanup(this)
                        AndroidUpdateRuntime.failed(token, "unavailable")
                        AndroidUpdateRuntime.finishOperation(token)
                        throw failure
                    }
                    result.success(null)
                }
                "cancel" -> {
                    AndroidUpdateRuntime.cancel(this)
                    result.success(null)
                }
                "canInstall" -> result.success(canInstallPackages())
                "openInstallPermission" -> {
                    if (Build.VERSION.SDK_INT < 26 || canInstallPackages()) { result.success(null); return }
                    if (updatePermissionPending) throw UpdateFailure("busy", "Install permission settings are already open.")
                    updatePermissionPending = true
                    val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName"))
                    startActivityForResult(intent, updatePermissionRequestCode)
                    result.success(null)
                }
                "install" -> startApprovedInstall(result)
                else -> result.notImplemented()
            }
        } catch (failure: UpdateFailure) {
            result.error(failure.code, failure.message, null)
        } catch (failure: Exception) {
            result.error("installer", failure.message ?: "Android update operation failed.", null)
        }
    }

    private fun canInstallPackages(): Boolean = Build.VERSION.SDK_INT < 26 || packageManager.canRequestPackageInstalls()

    private fun startApprovedInstall(result: MethodChannel.Result) {
        if (updateInstallPending) throw UpdateFailure("busy", "Android installation confirmation is already open.")
        val snapshot = AndroidUpdateRuntime.snapshot()
        val state = snapshot["state"] as? String
        if (state !in setOf("ready", "installationCancelled", "permissionRequired"))
            throw UpdateFailure("busy", "There is no validated update ready to install.")
        @Suppress("UNCHECKED_CAST")
        val candidateMap = snapshot["candidate"] as? Map<String, Any?>
            ?: throw UpdateFailure("invalidPackage", "There is no approved update to install.")
        if (!canInstallPackages()) {
            // The caller must explicitly visit settings and explicitly retry installation afterward.
            AndroidUpdateRuntime.permissionRequired(candidateMap)
            result.success(null)
            return
        }
        if (state == "permissionRequired") {
            // Returning from settings only revalidates the approved APK. Installation
            // still requires a separate tap on the ready action.
            refreshPermissionApproval()
            result.success(null)
            return
        }
        val candidate = UpdateCandidate.from(candidateMap)
        val token = AndroidUpdateRuntime.beginInstall()
            ?: throw UpdateFailure("busy", "Another update operation is already active.")
        val apk = AndroidUpdateRuntime.apkFile(this)
        val canceled = AtomicBoolean(false)
        AndroidUpdateRuntime.setCanceller(token) { canceled.set(true) }
        try {
            AndroidUpdateRuntime.validationExecutor.execute {
                try {
                    AndroidUpdateRuntime.validate(this, candidate, apk) {
                        canceled.get() || !AndroidUpdateRuntime.owns(token)
                    }
                    runOnUiThread {
                        if (!AndroidUpdateRuntime.owns(token) || canceled.get()) {
                            result.error("cancelled", "Installation was cancelled.", null)
                            AndroidUpdateRuntime.finishOperation(token)
                            return@runOnUiThread
                        }
                        if (isFinishing) {
                            AndroidUpdateRuntime.ready(token)
                            result.error("unavailable", "App closed before installation confirmation opened.", null)
                            AndroidUpdateRuntime.finishOperation(token)
                            return@runOnUiThread
                        }
                        try {
                            val uri = AndroidUpdateRuntime.contentUri(this, apk)
                            val intent = Intent(Intent.ACTION_INSTALL_PACKAGE).setDataAndType(uri, "application/vnd.android.package-archive")
                                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                .putExtra(Intent.EXTRA_RETURN_RESULT, true)
                            updateInstallPending = true
                            AndroidUpdateRuntime.installing(token)
                            startActivityForResult(intent, updateInstallRequestCode)
                            result.success(null)
                        } catch (_: Exception) {
                            updateInstallPending = false
                            AndroidUpdateRuntime.ready(token)
                            AndroidUpdateRuntime.finishOperation(token)
                            result.error("installer", "Android could not open the installation confirmation.", null)
                        }
                    }
                } catch (failure: Exception) {
                    val code = when (failure) {
                        is UpdateFailure -> failure.code
                        is InterruptedException -> "cancelled"
                        else -> "invalidPackage"
                    }
                    if (code == "cancelled") AndroidUpdateRuntime.cancelled(token)
                    else {
                        AndroidUpdateRuntime.cleanup(this)
                        AndroidUpdateRuntime.failed(token, code)
                    }
                    runOnUiThread {
                        result.error(code, if (code == "cancelled") "Installation was cancelled." else "Downloaded APK could not be verified.", null)
                        AndroidUpdateRuntime.finishOperation(token)
                    }
                }
            }
        } catch (_: Exception) {
            AndroidUpdateRuntime.ready(token)
            AndroidUpdateRuntime.finishOperation(token)
            throw UpdateFailure("busy", "Android update validation could not be started.")
        }
    }

    private fun setUpdatePermissionRequired() {
        // Preserve the approved candidate so the user can retry after granting permission.
        val state = AndroidUpdateRuntime.snapshot()
        @Suppress("UNCHECKED_CAST")
        val candidate = state["candidate"] as? Map<String, Any?>
        AndroidUpdateRuntime.permissionRequired(candidate)
    }

    private fun refreshPermissionApproval() {
        val validation = AndroidUpdateRuntime.beginPermissionValidation(this) ?: return
        val cancelled = AtomicBoolean(false)
        AndroidUpdateRuntime.setCanceller(validation.token) { cancelled.set(true) }
        try {
            AndroidUpdateRuntime.validationExecutor.execute {
                try {
                    AndroidUpdateRuntime.validate(this, validation.candidate, validation.apk) {
                        cancelled.get() || !AndroidUpdateRuntime.owns(validation.token)
                    }
                    runOnUiThread {
                        AndroidUpdateRuntime.finishPermissionValidation(
                            validation.token,
                            validation.approvalToken,
                            canInstallPackages() && !cancelled.get(),
                        )
                    }
                } catch (failure: Exception) {
                    if (failure is InterruptedException || cancelled.get()) {
                        AndroidUpdateRuntime.cancelled(validation.token)
                        runOnUiThread { AndroidUpdateRuntime.finishOperation(validation.token) }
                    } else {
                        AndroidUpdateRuntime.cleanup(this)
                        AndroidUpdateRuntime.invalidatePermissionValidation(validation.token)
                    }
                }
            }
        } catch (_: Exception) {
            AndroidUpdateRuntime.invalidatePermissionValidation(validation.token)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            updatePermissionRequestCode -> {
                updatePermissionPending = false
                if (canInstallPackages()) refreshPermissionApproval() else setUpdatePermissionRequired()
            }
            updateInstallRequestCode -> {
                updateInstallPending = false
                val token = AndroidUpdateRuntime.currentToken("installing") ?: return
                if (resultCode == RESULT_OK) {
                    AndroidUpdateRuntime.cleanup(this)
                    AndroidUpdateRuntime.installationSucceeded(token)
                } else AndroidUpdateRuntime.installationCancelled(token)
            }
        }
    }

    private fun cleanDeviceValue(value: String?, maxLength: Int): String =
        value.orEmpty()
            .replace(Regex("[\\p{Cc}\\p{Cf}]+"), " ")
            .trim()
            .replace(Regex("\\s+"), " ")
            .take(maxLength)

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

    override fun onResume() {
        super.onResume()
        if (!updatePermissionPending && AndroidUpdateRuntime.snapshot()["state"] == "permissionRequired" && canInstallPackages()) {
            refreshPermissionApproval()
        }
    }

    override fun onDestroy() {
        stopService(Intent(this, ConnectionService::class.java))
        updateEventSink?.let { AndroidUpdateRuntime.removeObserver(it) }
        updateEventSink = null
        updateEvents?.setStreamHandler(null)
        pendingPermissionResult?.error("activity_closed", "Activity closed.", null)
        pendingNotificationResult?.error("activity_closed", "Activity closed.", null)
        pendingPermissionResult = null
        pendingNotificationResult = null
        super.onDestroy()
    }
}
