package org.openremotecontrol.open_remote_control

import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/** Keeps the existing Flutter connection alive while the activity is in the background. */
class ConnectionService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null
    private var connectedAddress = "PC"
    private var serviceActive = false
    private val languageListener: (AppLanguage) -> Unit = { refreshNotification(it) }

    override fun onCreate() {
        super.onCreate()
        AppNotificationLanguage.observe(languageListener)
        AppNotificationLanguage.updateChannels(this, AppNotificationLanguage.current(this))
    }

    @Suppress("DEPRECATION")
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        connectedAddress = intent?.getStringExtra("address") ?: connectedAddress
        serviceActive = true
        refreshNotification(AppNotificationLanguage.current(this))
        if (wakeLock == null) {
            wakeLock = (getSystemService(POWER_SERVICE) as PowerManager)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "OpenRemote:connection").apply { acquire() }
        }
        return START_NOT_STICKY
    }

    @Suppress("DEPRECATION")
    private fun refreshNotification(language: AppLanguage) {
        AppNotificationLanguage.updateChannels(this, language)
        if (!serviceActive) return
        val copy = AppNotificationLanguage.connectionCopy(language)
        val activity = PendingIntent.getActivity(this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL_ID) else Notification.Builder(this)
        val notification = builder.setSmallIcon(R.drawable.ic_launcher_monochrome)
            .setContentTitle(copy.title)
            .setContentText("${copy.connectedTo} $connectedAddress")
            .setContentIntent(activity).setOngoing(true).setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_SERVICE).build()
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    override fun onDestroy() {
        serviceActive = false
        AppNotificationLanguage.stopObserving(languageListener)
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val CHANNEL_ID = "open_remote_connection"
        private const val NOTIFICATION_ID = 47652
    }
}
