package org.openremotecontrol.open_remote_control

import android.content.Context
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.FileProvider
import io.flutter.plugin.common.EventChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileInputStream
import java.security.MessageDigest
import java.util.concurrent.CopyOnWriteArraySet
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

internal class UpdateFailure(val code: String, message: String) : Exception(message)

internal data class UpdateCandidate(
    val map: Map<String, Any?>,
    val packageName: String,
    val versionName: String,
    val versionCode: Long,
    val minSdk: Int,
    val targetSdk: Int,
    val maxSdk: Int?,
    val abis: List<String>,
    val signerSha256: Set<String>,
    val size: Long,
    val sha256: String,
    val downloadUrl: String,
) {
    companion object {
        fun from(map: Map<String, Any?>): UpdateCandidate {
            fun string(key: String) = map[key] as? String
                ?: throw UpdateFailure("invalidPackage", "Update metadata is missing $key.")
            fun integer(key: String): Long = when (val value = map[key]) {
                is Int -> value.toLong()
                is Long -> value
                is Number -> value.toLong()
                else -> throw UpdateFailure("invalidPackage", "Update metadata has an invalid $key.")
            }
            val packageName = string("packageName")
            val name = string("versionName")
            val code = integer("versionCode")
            val minSdk = integer("minSdk").toInt()
            val targetSdk = integer("targetSdk").toInt()
            val maxSdk = (map["maxSdk"] as? Number)?.toInt()
            val abis = (map["abis"] as? List<*>)?.map { it as? String
                ?: throw UpdateFailure("invalidPackage", "Update metadata has an invalid ABI.") }
                ?: throw UpdateFailure("invalidPackage", "Update metadata has invalid ABIs.")
            val signers = (map["signerSha256"] as? List<*>)?.map { it as? String
                ?: throw UpdateFailure("invalidPackage", "Update metadata has an invalid signer.") }?.toSet()
                ?: throw UpdateFailure("invalidPackage", "Update metadata has invalid signers.")
            val size = integer("size")
            val hash = string("sha256")
            val url = string("downloadUrl")
            val parsedVersion = AndroidUpdatePolicy.parseVersion(name)
            if (packageName.isBlank() || parsedVersion == null || code <= 0 || minSdk < 1 || targetSdk < 1 ||
                (maxSdk != null && maxSdk < minSdk) || size <= 0 || AndroidUpdatePolicy.parseSha256(hash) == null ||
                signers.isEmpty() || signers.any { AndroidUpdatePolicy.parseSha256(it) == null } ||
                AndroidUpdatePolicy.validateInitialDownloadUrl(url) == null
            ) throw UpdateFailure("invalidPackage", "Update metadata is invalid or unsupported.")
            return UpdateCandidate(map.toMap(), packageName, name, code, minSdk, targetSdk, maxSdk,
                abis, signers, size, hash, url)
        }
    }
}

/** Process-local state. The service is non-sticky; a fresh process removes only updater-owned files. */
internal object AndroidUpdateRuntime {
    data class PermissionValidation(val token: Long, val approvalToken: Long, val candidate: UpdateCandidate, val apk: File)

    const val DIR_NAME = "updates"
    private val observers = CopyOnWriteArraySet<EventChannel.EventSink>()
    private val observerStartSequence = ConcurrentHashMap<EventChannel.EventSink, Long>()
    private val lock = Any()
    private val transferGate = TransferGate()
    private val mainHandler = Handler(Looper.getMainLooper())
    val validationExecutor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "open-remote-update-validation").apply { isDaemon = true }
    }
    private var initialized = false
    private var eventSequence = 0L
    private var current: MutableMap<String, Any?> = mutableMapOf(
        "state" to "idle", "receivedBytes" to 0L, "totalBytes" to 0L,
    )
    private var activeToken: Long? = null
    private var approvedToken: Long? = null
    private var cancelOperation: (() -> Unit)? = null
    @Volatile private var transferActive = false

    fun initialize(context: Context): File = synchronized(lock) {
        val directory = File(context.filesDir, DIR_NAME)
        if (!directory.exists() && !directory.mkdirs()) throw UpdateFailure("storage", "Cannot create private update storage.")
        if (!initialized) {
            if (!transferActive) AndroidUpdatePolicy.cleanupOwnedFiles(directory)
            initialized = true
        }
        directory
    }

    fun addObserver(sink: EventChannel.EventSink) {
        synchronized(lock) {
            observerStartSequence[sink] = eventSequence
            observers.add(sink)
            sink.success(HashMap(current))
        }
    }
    fun removeObserver(sink: EventChannel.EventSink) {
        observers.remove(sink)
        observerStartSequence.remove(sink)
    }
    fun snapshot(): Map<String, Any?> = synchronized(lock) { HashMap(current) }

    fun begin(candidate: Map<String, Any?>): Long? = synchronized(lock) {
        if (transferActive || current["state"] in setOf("ready", "validating", "installing", "permissionRequired", "installationCancelled")) return null
        val token = transferGate.tryStart() ?: return null
        transferActive = true
        activeToken = token
        approvedToken = token
        current = mutableMapOf("state" to "downloading", "receivedBytes" to 0L,
            "totalBytes" to ((candidate["size"] as? Number)?.toLong() ?: 0L), "candidate" to candidate.toMap())
        publishLocked()
        token
    }

    fun beginInstall(): Long? = synchronized(lock) {
        if (transferActive || approvedToken == null || current["state"] !in setOf("ready", "installationCancelled")) return null
        val token = transferGate.tryStart() ?: return null
        transferActive = true
        activeToken = token
        current["state"] = "validating"
        publishLocked()
        token
    }

    fun setCanceller(token: Long, cancel: () -> Unit) = synchronized(lock) {
        if (ownsLocked(token)) cancelOperation = cancel
    }

    fun progress(token: Long, received: Long, total: Long) = update(token, "downloading", received, total)
    fun validating(token: Long) = update(token, "validating")
    fun ready(token: Long) = update(token, "ready")
    fun installing(token: Long) = update(token, "installing")
    fun cancelled(token: Long): Unit = synchronized(lock) {
        if (!ownsLocked(token)) return@synchronized
        cancelOperation = null
        if (current["state"] != "cancelled") current = mutableMapOf(
            "state" to "cancelled", "receivedBytes" to 0L, "totalBytes" to 0L,
        )
        publishLocked()
        Unit
    }

    fun installationCancelled(token: Long) = complete(token, "installationCancelled")
    fun installationSucceeded(token: Long) = complete(token, "idle")

    fun permissionRequired(candidate: Map<String, Any?>?): Unit = synchronized(lock) {
        if (transferActive) return@synchronized
        if (approvedToken == null || candidate == null) {
            current = mutableMapOf("state" to "idle", "receivedBytes" to 0L, "totalBytes" to 0L)
            publishLocked()
            return@synchronized
        }
        current = mutableMapOf("state" to "permissionRequired", "receivedBytes" to 0L,
            "totalBytes" to 0L, "errorCode" to "permission")
        current["candidate"] = candidate
        publishLocked()
        Unit
    }

    fun beginPermissionValidation(context: Context): PermissionValidation? = synchronized(lock) {
        if (transferActive || current["state"] != "permissionRequired") return null
        val approval = approvedToken
        @Suppress("UNCHECKED_CAST")
        val candidateMap = current["candidate"] as? Map<String, Any?>
        val apk = File(File(context.filesDir, DIR_NAME), "approved-update.apk")
        val candidate = try { candidateMap?.let(UpdateCandidate::from) } catch (_: Exception) { null }
        if (approval == null || candidate == null || !apk.isFile || apk.length() != candidate.size) {
            approvedToken = null
            AndroidUpdatePolicy.cleanupOwnedFiles(File(context.filesDir, DIR_NAME))
            current = mutableMapOf("state" to "idle", "receivedBytes" to 0L, "totalBytes" to 0L)
            publishLocked()
            return null
        }
        val token = transferGate.tryStart() ?: return null
        activeToken = token
        transferActive = true
        current["state"] = "validating"
        publishLocked()
        PermissionValidation(token, approval, candidate, apk)
    }

    fun finishPermissionValidation(token: Long, approvalToken: Long, permissionGranted: Boolean): Unit = synchronized(lock) {
        if (!ownsLocked(token) || current["state"] != "validating") return@synchronized
        if (approvedToken != approvalToken || current["candidate"] == null) {
            approvedToken = null
            current = mutableMapOf("state" to "idle", "receivedBytes" to 0L, "totalBytes" to 0L)
        } else if (permissionGranted) {
            current["state"] = "ready"
            current.remove("errorCode")
        } else {
            current["state"] = "permissionRequired"
            current["errorCode"] = "permission"
        }
        publishLocked()
        finishOperation(token)
        Unit
    }

    fun invalidatePermissionValidation(token: Long): Unit = synchronized(lock) {
        if (!ownsLocked(token) || current["state"] == "cancelled") return@synchronized
        approvedToken = null
        current = mutableMapOf("state" to "idle", "receivedBytes" to 0L, "totalBytes" to 0L)
        publishLocked()
        finishOperation(token)
        Unit
    }

    fun failed(token: Long, code: String): Unit = synchronized(lock) {
        if (!ownsLocked(token) || current["state"] in setOf("cancelled", "failed")) return@synchronized
        cancelOperation = null
        if (approvedToken == token) approvedToken = null
        current = mutableMapOf("state" to "failed", "receivedBytes" to 0L, "totalBytes" to 0L, "errorCode" to code)
        publishLocked()
        Unit
    }

    /** Only the owner can release its token, and only after its worker has stopped. */
    fun finishOperation(token: Long): Unit = synchronized(lock) {
        if (activeToken != token) return@synchronized
        cancelOperation = null
        transferActive = false
        activeToken = null
        transferGate.release(token)
        Unit
    }

    fun interrupt(token: Long): Unit = synchronized(lock) {
        if (!ownsLocked(token) || current["state"] in setOf("cancelled", "ready", "installing")) return@synchronized
        cancelOperation?.invoke()
        current = mutableMapOf("state" to "failed", "receivedBytes" to 0L,
            "totalBytes" to 0L, "errorCode" to "interrupted")
        publishLocked()
        Unit
    }

    fun owns(token: Long): Boolean = synchronized(lock) { ownsLocked(token) }
    fun currentToken(state: String): Long? = synchronized(lock) { if (current["state"] == state) activeToken else null }
    fun operationState(token: Long): String? = synchronized(lock) { if (activeToken == token) current["state"] as? String else null }

    fun cancel(context: Context, token: Long? = null): Boolean = synchronized(lock) {
        val owner = activeToken
        if (current["state"] == "installing") return false
        if (owner != null && token != null && owner != token) return false
        if (owner != null) {
            cancelOperation?.invoke()
            cancelOperation = null
            approvedToken = null
            current = mutableMapOf("state" to "cancelled", "receivedBytes" to 0L, "totalBytes" to 0L)
        } else if (current["state"] in setOf("ready", "permissionRequired", "installationCancelled", "failed")) {
            approvedToken = null
            current = mutableMapOf("state" to "cancelled", "receivedBytes" to 0L, "totalBytes" to 0L)
        } else return false
        AndroidUpdatePolicy.cleanupOwnedFiles(File(context.filesDir, DIR_NAME))
        publishLocked()
        true
    }

    private fun complete(token: Long, state: String): Unit = synchronized(lock) {
        if (!ownsLocked(token)) return@synchronized
        current["state"] = state
        if (state == "idle") {
            approvedToken = null
            current = mutableMapOf("state" to "idle", "receivedBytes" to 0L, "totalBytes" to 0L)
        }
        publishLocked()
        finishOperation(token)
        Unit
    }

    private fun ownsLocked(token: Long) = activeToken == token && transferGate.isCurrent(token)
    private fun update(token: Long, state: String, received: Long = 0, total: Long = 0): Unit = synchronized(lock) {
        if (!ownsLocked(token) || current["state"] in setOf("cancelled", "failed")) return@synchronized
        current["state"] = state
        if (state == "downloading") { current["receivedBytes"] = received; current["totalBytes"] = total }
        publishLocked()
        Unit
    }

    private fun publishLocked() {
        val event = HashMap(current)
        val sequence = ++eventSequence
        mainHandler.post {
            observers.forEach { sink ->
                if (sequence > (observerStartSequence[sink] ?: Long.MAX_VALUE)) {
                    try { sink.success(event) } catch (_: Exception) { }
                }
            }
        }
    }

    fun cleanup(context: Context) {
        AndroidUpdatePolicy.cleanupOwnedFiles(File(context.filesDir, DIR_NAME))
    }

    fun apkFile(context: Context) = File(initialize(context), "approved-update.apk")
    fun partialFile(context: Context) = File(initialize(context), "approved-update.part")

    fun deviceInfo(context: Context): Map<String, Any?> {
        initialize(context)
        val pm = context.packageManager
        val flags = signingFlags()
        val installed = if (Build.VERSION.SDK_INT >= 33) pm.getPackageInfo(context.packageName,
            PackageManager.PackageInfoFlags.of(flags.toLong()))
        else @Suppress("DEPRECATION") pm.getPackageInfo(context.packageName, flags)
        val signers = signerDigests(installed, pm)
        return mapOf("packageName" to context.packageName, "versionName" to (installed.versionName ?: ""),
            "versionCode" to longVersionCode(installed), "sdkInt" to Build.VERSION.SDK_INT,
            "abis" to Build.SUPPORTED_ABIS.toList(), "signerSha256" to signers.toList().sorted())
    }

    fun validate(context: Context, candidate: UpdateCandidate, apk: File, isCancelled: () -> Boolean = { false }) {
        fun checkCancellation() { if (isCancelled()) throw InterruptedException() }
        checkCancellation()
        if (!apk.isFile || apk.length() != candidate.size) throw UpdateFailure("integrity", "Downloaded APK size does not match approved metadata.")
        val digest = MessageDigest.getInstance("SHA-256")
        FileInputStream(apk).use { stream ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
                checkCancellation()
                val count = stream.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        val actualHash = digest.digest().joinToString("") { "%02x".format(it) }
        if (actualHash != candidate.sha256) throw UpdateFailure("integrity", "Downloaded APK checksum does not match approved metadata.")

        val pm = context.packageManager
        checkCancellation()
        val archive = archiveInfo(pm, apk.absolutePath)
            ?: throw UpdateFailure("invalidPackage", "Android could not read the downloaded APK.")
        checkCancellation()
        val app = archive.applicationInfo ?: throw UpdateFailure("invalidPackage", "APK has no application information.")
        if (archive.packageName != context.packageName || candidate.packageName != context.packageName ||
            archive.packageName != candidate.packageName || longVersionCode(archive) != candidate.versionCode ||
            archive.versionName != candidate.versionName
        ) throw UpdateFailure("identity", "APK identity or version does not match the approved update.")
        if (!AndroidUpdatePolicy.isNewer(candidate.versionName, candidate.versionCode,
                context.packageManager.getPackageInfo(context.packageName, 0).versionName ?: "", installedVersionCode(context))) {
            throw UpdateFailure("identity", "Update version is not newer than the installed app.")
        }
        if (app.minSdkVersion != candidate.minSdk || app.targetSdkVersion != candidate.targetSdk)
            throw UpdateFailure("identity", "APK SDK requirements do not match approved metadata.")
        val apkAbis = try { AndroidUpdatePolicy.apkAbis(apk) }
        catch (_: Exception) { throw UpdateFailure("invalidPackage", "APK archive could not be inspected.") }
        if (apkAbis != candidate.abis.toSet()) throw UpdateFailure("identity", "APK native architectures do not match approved metadata.")
        if (Build.VERSION.SDK_INT < candidate.minSdk || (candidate.maxSdk != null && Build.VERSION.SDK_INT > candidate.maxSdk) ||
            (Build.VERSION.SDK_INT >= 35 && candidate.targetSdk < 24) ||
            (Build.VERSION.SDK_INT == 34 && candidate.targetSdk < 23) ||
            !AndroidUpdatePolicy.supportedAbi(apkAbis.toList(), Build.SUPPORTED_ABIS.toList())
        ) throw UpdateFailure("incompatible", "APK is not compatible with this Android version or device architecture.")
        if ((archive.splitNames?.isNotEmpty() == true) ||
            (Build.VERSION.SDK_INT >= 19 && app.metaData?.getBoolean("com.android.vending.splits.required", false) == true))
            throw UpdateFailure("incompatible", "APK requires split packages and cannot be installed alone.")
        val apkSigners = signerDigests(archive, pm)
        val installed = packageInfo(context, context.packageName)
        val installedSigners = signerDigests(installed, pm)
        if (apkSigners.isEmpty() || apkSigners != candidate.signerSha256 || apkSigners != installedSigners)
            throw UpdateFailure("signature", "APK signing certificates do not match the installed app.")
    }

    fun contentUri(context: Context, apk: File) = FileProvider.getUriForFile(context,
        "${context.packageName}.updates", apk)

    @Suppress("DEPRECATION")
    private fun archiveInfo(pm: PackageManager, path: String): PackageInfo? {
        val flags = signingFlags() or PackageManager.GET_META_DATA
        return if (Build.VERSION.SDK_INT >= 33) pm.getPackageArchiveInfo(path, PackageManager.PackageInfoFlags.of(flags.toLong()))
        else pm.getPackageArchiveInfo(path, flags)
    }

    @Suppress("DEPRECATION")
    private fun packageInfo(context: Context, packageName: String): PackageInfo {
        val flags = signingFlags()
        return if (Build.VERSION.SDK_INT >= 33) context.packageManager.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(flags.toLong()))
        else context.packageManager.getPackageInfo(packageName, flags)
    }

    @Suppress("DEPRECATION")
    private fun signingFlags() = if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES

    private fun installedVersionCode(context: Context): Long = longVersionCode(packageInfo(context, context.packageName))

    private fun longVersionCode(info: PackageInfo): Long = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else @Suppress("DEPRECATION") info.versionCode.toLong()

    @Suppress("DEPRECATION")
    private fun signerDigests(info: PackageInfo, pm: PackageManager): Set<String> {
        val signatures = if (Build.VERSION.SDK_INT >= 28) info.signingInfo?.apkContentsSigners
            else info.signatures
        return signatures?.map { signature ->
            MessageDigest.getInstance("SHA-256").digest(signature.toByteArray())
                .joinToString("") { "%02x".format(it) }
        }?.toSet() ?: emptySet()
    }
}

internal fun jsonObjectToMap(objectValue: JSONObject): Map<String, Any?> = objectValue.keys().asSequence().associateWith { key ->
    when (val value = objectValue.get(key)) {
        JSONObject.NULL -> null
        is JSONObject -> jsonObjectToMap(value)
        is JSONArray -> (0 until value.length()).map { index ->
            val item = value.get(index)
            if (item is JSONObject) jsonObjectToMap(item) else if (item === JSONObject.NULL) null else item
        }
        else -> value
    }
}
