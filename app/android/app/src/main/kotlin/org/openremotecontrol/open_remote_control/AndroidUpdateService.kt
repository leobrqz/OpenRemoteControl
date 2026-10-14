package org.openremotecontrol.open_remote_control

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.StatFs
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.io.File
import java.io.InputStream
import java.io.OutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/** A non-sticky foreground service for a user-approved APK download. */
class AndroidUpdateService : Service() {
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    @Volatile private var connection: HttpURLConnection? = null
    private val cancelled = AtomicBoolean(false)
    private val timeoutHandler = Handler(Looper.getMainLooper())
    private var wakeLock: PowerManager.WakeLock? = null
    private var timeoutTask: Runnable? = null
    @Volatile private var notificationStrings = AppNotificationLanguage.updateCopy(AppLanguage.ENGLISH)
    @Volatile private var currentReceived = 0L
    @Volatile private var currentTotal = 0L
    @Volatile private var serviceToken: Long? = null
    @Volatile private var serviceStartId: Int? = null
    private val languageListener: (AppLanguage) -> Unit = { refreshLocalizedNotification(it) }

    override fun onCreate() {
        super.onCreate()
        notificationStrings = AppNotificationLanguage.updateCopy(AppNotificationLanguage.current(this))
        AppNotificationLanguage.observe(languageListener)
        AppNotificationLanguage.updateChannels(this, AppNotificationLanguage.current(this))
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_CANCEL) {
            val token = intent.getLongExtra(EXTRA_TOKEN, -1L)
            AndroidUpdateRuntime.cancel(this, token)
            return START_NOT_STICKY
        }
        val token = intent?.getLongExtra(EXTRA_TOKEN, -1L) ?: -1L
        if (token < 0L || !AndroidUpdateRuntime.owns(token)) {
            stopSelf(startId); return START_NOT_STICKY
        }
        val raw = intent?.getStringExtra(EXTRA_CANDIDATE) ?: run {
            AndroidUpdateRuntime.cleanup(this)
            AndroidUpdateRuntime.failed(token, "invalidPackage")
            AndroidUpdateRuntime.finishOperation(token)
            stopSelf(startId); return START_NOT_STICKY
        }
        notificationStrings = AppNotificationLanguage.updateCopy(AppNotificationLanguage.current(this))
        AppNotificationLanguage.updateChannels(this, AppNotificationLanguage.current(this))
        currentReceived = 0L
        currentTotal = (AndroidUpdateRuntime.snapshot()["totalBytes"] as? Number)?.toLong() ?: 0L
        cancelled.set(false)
        serviceToken = token
        serviceStartId = startId
        val notification = notification(0, 0, notificationStrings.downloading)
        try {
            if (Build.VERSION.SDK_INT >= 29) startForeground(NOTIFICATION_ID, notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
            else startForeground(NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
            AndroidUpdateRuntime.cleanup(this)
            AndroidUpdateRuntime.failed(token, "permission")
            AndroidUpdateRuntime.finishOperation(token)
            stopSelf(startId)
            return START_NOT_STICKY
        }
        try {
            acquireTransferWakeLock(token)
        } catch (_: Exception) {
            AndroidUpdateRuntime.cleanup(this)
            AndroidUpdateRuntime.failed(token, "permission")
            AndroidUpdateRuntime.finishOperation(token)
            stopForeground(STOP_FOREGROUND_REMOVE); stopSelf(startId)
            return START_NOT_STICKY
        }
        val cancel: () -> Unit = {
            cancelled.set(true)
            connection?.disconnect()
            Unit
        }
        AndroidUpdateRuntime.setCanceller(token, cancel)
        executor.execute {
            try {
                ensureActive(token)
                val candidate = UpdateCandidate.from(jsonObjectToMap(JSONObject(raw)))
                val apk = AndroidUpdateRuntime.apkFile(this)
                val part = AndroidUpdateRuntime.partialFile(this)
                apk.delete(); part.delete()
                download(token, candidate, part)
                ensureActive(token)
                if (!part.renameTo(apk)) throw UpdateFailure("storage", "Downloaded APK could not be saved in private storage.")
                AndroidUpdateRuntime.validating(token)
                currentReceived = candidate.size
                currentTotal = candidate.size
                if (AndroidUpdateRuntime.owns(token)) safeNotify(
                    notification(candidate.size, candidate.size, notificationStrings.validating))
                AndroidUpdateRuntime.validate(this, candidate, apk) { !isActive(token) }
                ensureActive(token)
                AndroidUpdateRuntime.ready(token)
                currentReceived = candidate.size
                currentTotal = candidate.size
                if (AndroidUpdateRuntime.operationState(token) == "ready") safeNotify(readyNotification())
                stopForeground(STOP_FOREGROUND_DETACH)
                stopSelf(startId)
            } catch (failure: Exception) {
                AndroidUpdateRuntime.cleanup(this)
                when (AndroidUpdateRuntime.operationState(token)) {
                    "cancelled", "failed" -> Unit
                    else -> AndroidUpdateRuntime.failed(token, when (failure) {
                        is UpdateFailure -> failure.code
                        is InterruptedException -> "interrupted"
                        else -> "network"
                    })
                }
                safeCancelNotification()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf(startId)
            } finally {
                // This is the last transfer side effect: a retry cannot race stale cleanup or notifications.
                releaseTransferWakeLock(token)
                AndroidUpdateRuntime.finishOperation(token)
            }
        }
        return START_NOT_STICKY
    }

    private fun download(token: Long, candidate: UpdateCandidate, part: File) {
        val stat = StatFs(filesDir.absolutePath)
        if (candidate.size > stat.availableBytes - MIN_FREE_SPACE) throw UpdateFailure("storage", "Not enough free space to download the APK.")
        val initialUrl = AndroidUpdatePolicy.validateInitialDownloadUrl(candidate.downloadUrl)
            ?: throw UpdateFailure("unavailable", "APK download URL is not a valid HTTPS address.")
        var nextUrl = initialUrl
        var redirects = 0
        var response: HttpURLConnection? = null
        while (true) {
            ensureActive(token)
            val opened = (URL(nextUrl.toASCIIString()).openConnection() as? HttpURLConnection)
                ?: throw UpdateFailure("network", "Could not connect to the APK download host.")
            response = opened
            connection = opened
            opened.instanceFollowRedirects = false
            opened.connectTimeout = CONNECT_TIMEOUT_MS
            opened.readTimeout = READ_TIMEOUT_MS
            opened.useCaches = false
            opened.setRequestProperty("Accept", "application/vnd.android.package-archive, application/octet-stream")
            val code = try { opened.responseCode } catch (e: Exception) {
                opened.disconnect(); if (cancelled.get()) throw InterruptedException()
                throw UpdateFailure("network", "APK download connection failed.")
            }
            if (code in 300..399) {
                val location = opened.getHeaderField("Location")
                opened.disconnect(); response = null; connection = null
                if (++redirects > MAX_REDIRECTS || location.isNullOrBlank()) throw UpdateFailure("unavailable", "APK download redirected too many times.")
                nextUrl = AndroidUpdatePolicy.validateDownloadRedirect(nextUrl.resolve(location).toString(), initialUrl.rawPath)
                    ?: throw UpdateFailure("unavailable", "APK download redirected to an unsafe address.")
                continue
            }
            if (code != HttpURLConnection.HTTP_OK) {
                opened.disconnect(); response = null; connection = null
                throw UpdateFailure(if (code == 404 || code == 410) "unavailable" else "network", "APK download failed with HTTP $code.")
            }
            val announcedLength = opened.getHeaderFieldLong("Content-Length", -1L)
            if (announcedLength >= 0 && announcedLength != candidate.size) {
                opened.disconnect(); response = null; connection = null
                throw UpdateFailure("integrity", "APK download size does not match approved metadata.")
            }
            break
        }
        val active = response ?: throw UpdateFailure("network", "APK download connection was not established.")
        try {
            active.inputStream.use { input -> part.outputStream().use { output -> copy(token, input, output, candidate.size) } }
        } catch (e: UpdateFailure) { throw e }
        catch (e: Exception) {
            if (!isActive(token)) throw InterruptedException()
            throw UpdateFailure("network", "APK download was interrupted by a network error.")
        } finally {
            active.disconnect(); connection = null
        }
        if (part.length() != candidate.size) throw UpdateFailure("integrity", "APK download ended before the expected size.")
    }

    private fun copy(token: Long, input: InputStream, output: OutputStream, total: Long) {
        val buffer = ByteArray(64 * 1024)
        var received = 0L
        var lastPublishedAt = 0L
        while (true) {
            ensureActive(token)
            val count = input.read(buffer)
            if (count < 0) break
            received += count
            if (received > total) throw UpdateFailure("integrity", "APK download exceeded the approved size.")
            output.write(buffer, 0, count)
            if (received - lastPublishedAt >= PROGRESS_STEP || received == total) {
                lastPublishedAt = received
                currentReceived = received
                currentTotal = total
                AndroidUpdateRuntime.progress(token, received, total)
                if (AndroidUpdateRuntime.operationState(token) == "downloading")
                    safeNotify(notification(received, total, notificationStrings.downloading))
            }
        }
        output.flush()
    }

    private fun isActive(token: Long) = !cancelled.get() && AndroidUpdateRuntime.owns(token) && !Thread.currentThread().isInterrupted
    private fun ensureActive(token: Long) { if (!isActive(token)) throw InterruptedException() }

    private fun notification(received: Long, total: Long, text: String): Notification {
        val activityIntent = PendingIntent.getActivity(this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val token = serviceToken ?: -1L
        val cancelIntent = PendingIntent.getService(this, token.toInt(),
            Intent(this, AndroidUpdateService::class.java).setAction(ACTION_CANCEL)
                .setData(Uri.parse("openremote://update-cancel/$token")).putExtra(EXTRA_TOKEN, token),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_launcher_monochrome)
            .setContentTitle(notificationStrings.title)
            .setContentText(text)
            .setContentIntent(activityIntent)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .addAction(0, notificationStrings.cancel, cancelIntent)
        if (total > 0) builder.setProgress(100, ((received * 100 / total).coerceIn(0, 100)).toInt(), false)
        else builder.setProgress(0, 0, true)
        return builder.build()
    }

    private fun readyNotification(): Notification {
        val activityIntent = PendingIntent.getActivity(this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        return NotificationCompat.Builder(this, CHANNEL_ID).setSmallIcon(R.drawable.ic_launcher_monochrome)
            .setContentTitle(notificationStrings.title).setContentText(notificationStrings.ready)
            .setContentIntent(activityIntent).setAutoCancel(true).setOnlyAlertOnce(true).build()
    }

    private fun notificationManager() = getSystemService(NotificationManager::class.java)

    private fun safeNotify(notification: Notification) {
        try { notificationManager().notify(NOTIFICATION_ID, notification) } catch (_: SecurityException) { }
    }

    private fun safeCancelNotification() {
        try { notificationManager().cancel(NOTIFICATION_ID) } catch (_: SecurityException) { }
    }

    private fun acquireTransferWakeLock(token: Long) {
        wakeLock = (getSystemService(POWER_SERVICE) as PowerManager)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "OpenRemote:apkUpdate").apply {
                setReferenceCounted(false)
                acquire(WAKE_LOCK_TIMEOUT_MS)
            }
        val timeout = Runnable {
            if (AndroidUpdateRuntime.operationState(token) in setOf("downloading", "validating")) {
                AndroidUpdateRuntime.interrupt(token)
                safeCancelNotification()
                stopForeground(STOP_FOREGROUND_REMOVE)
            }
        }
        timeoutTask = timeout
        timeoutHandler.postDelayed(timeout, WAKE_LOCK_TIMEOUT_MS)
    }

    private fun releaseTransferWakeLock(token: Long) {
        if (serviceToken != token) return
        timeoutTask?.let(timeoutHandler::removeCallbacks)
        timeoutTask = null
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
    }

    private fun refreshLocalizedNotification(language: AppLanguage) {
        notificationStrings = AppNotificationLanguage.updateCopy(language)
        AppNotificationLanguage.updateChannels(this, language)
        val token = serviceToken ?: return
        when (AndroidUpdateRuntime.operationState(token)) {
            "downloading" -> safeNotify(notification(currentReceived, currentTotal, notificationStrings.downloading))
            "validating" -> safeNotify(notification(currentReceived, currentTotal, notificationStrings.validating))
            "ready" -> safeNotify(readyNotification())
        }
    }

    override fun onDestroy() {
        AppNotificationLanguage.stopObserving(languageListener)
        cancelled.set(true)
        connection?.disconnect(); connection = null
        timeoutTask?.let(timeoutHandler::removeCallbacks); timeoutTask = null
        wakeLock?.let { if (it.isHeld) it.release() }; wakeLock = null
        executor.shutdownNow()
        serviceToken?.let { token ->
            if (AndroidUpdateRuntime.operationState(token) in setOf("downloading", "validating")) {
                AndroidUpdateRuntime.cleanup(this)
                AndroidUpdateRuntime.interrupt(token)
            }
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onTimeout(startId: Int, fgsType: Int) {
        if (serviceStartId == startId) serviceToken?.let { AndroidUpdateRuntime.cancel(this, it) }
        stopForeground(STOP_FOREGROUND_REMOVE); stopSelf(startId)
    }

    companion object {
        const val ACTION_CANCEL = "org.openremotecontrol.open_remote_control.CANCEL_UPDATE"
        const val EXTRA_CANDIDATE = "candidate_json"
        const val EXTRA_TOKEN = "operation_token"
        const val CHANNEL_ID = "open_remote_updates"
        private const val NOTIFICATION_ID = 47656
        private const val CONNECT_TIMEOUT_MS = 15_000
        private const val READ_TIMEOUT_MS = 30_000
        private const val MAX_REDIRECTS = 5
        private const val MIN_FREE_SPACE = 8L * 1024 * 1024
        private const val PROGRESS_STEP = 256L * 1024
        private const val WAKE_LOCK_TIMEOUT_MS = 2L * 60 * 60 * 1000

        /** Refreshes a ready notification after its foreground service has stopped. */
        fun refreshReadyNotification(context: android.content.Context) {
            if (AndroidUpdateRuntime.snapshot()["state"] !in
                setOf("ready", "installationCancelled", "installing", "permissionRequired")) return
            val language = AppNotificationLanguage.current(context)
            val copy = AppNotificationLanguage.updateCopy(language)
            AppNotificationLanguage.updateChannels(context, language)
            val activity = PendingIntent.getActivity(context, 0,
                Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_launcher_monochrome)
                .setContentTitle(copy.title).setContentText(copy.ready)
                .setContentIntent(activity).setAutoCancel(true).setOnlyAlertOnce(true).build()
            try { context.getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification) }
            catch (_: SecurityException) { }
        }
    }
}
