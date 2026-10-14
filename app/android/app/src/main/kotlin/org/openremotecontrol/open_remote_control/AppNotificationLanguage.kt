package org.openremotecontrol.open_remote_control

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import java.util.concurrent.CopyOnWriteArraySet

internal enum class AppLanguage(val tag: String) {
    ENGLISH("en-US"), PORTUGUESE_BRAZIL("pt-BR");

    companion object {
        /** Stored/legacy locale values are normalized without consulting the device locale. */
        fun normalize(value: String?): AppLanguage = when (
            value?.trim()?.replace('_', '-')?.lowercase()?.substringBefore('-')
        ) {
            "pt" -> PORTUGUESE_BRAZIL
            else -> ENGLISH
        }

        fun requested(value: String?): AppLanguage? = entries.firstOrNull { it.tag == value }
    }
}

internal data class ConnectionNotificationCopy(
    val channelName: String,
    val channelDescription: String,
    val title: String,
    val connectedTo: String,
)

internal data class UpdateNotificationCopy(
    val channelName: String,
    val channelDescription: String,
    val title: String,
    val downloading: String,
    val validating: String,
    val ready: String,
    val cancel: String,
)

/** Native notification language is independent of the Android system locale. */
internal object AppNotificationLanguage {
    private const val PREFERENCES = "open_remote_native_preferences"
    private const val LANGUAGE_KEY = "notification_language"
    private val listeners = CopyOnWriteArraySet<(AppLanguage) -> Unit>()

    fun current(context: Context): AppLanguage = AppLanguage.normalize(
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).getString(LANGUAGE_KEY, null),
    )

    fun set(context: Context, rawLanguage: String?): AppLanguage? {
        val language = AppLanguage.requested(rawLanguage) ?: return null
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .edit().putString(LANGUAGE_KEY, language.tag).apply()
        updateChannels(context, language)
        listeners.forEach { listener -> try { listener(language) } catch (_: Exception) { } }
        return language
    }

    fun observe(listener: (AppLanguage) -> Unit) { listeners.add(listener) }
    fun stopObserving(listener: (AppLanguage) -> Unit) { listeners.remove(listener) }

    fun connectionCopy(language: AppLanguage): ConnectionNotificationCopy = when (language) {
        AppLanguage.ENGLISH -> ConnectionNotificationCopy(
            "Connection", "Keeps the remote connection active in the background.",
            "Open Remote", "Connected to",
        )
        AppLanguage.PORTUGUESE_BRAZIL -> ConnectionNotificationCopy(
            "Conexão", "Mantém a conexão remota ativa em segundo plano.",
            "Open Remote", "Conexão com",
        )
    }

    fun updateCopy(language: AppLanguage): UpdateNotificationCopy = when (language) {
        AppLanguage.ENGLISH -> UpdateNotificationCopy(
            "App updates", "Notifications about app updates.", "Open Remote Control",
            "Downloading update", "Checking update", "Update is ready to install", "Cancel",
        )
        AppLanguage.PORTUGUESE_BRAZIL -> UpdateNotificationCopy(
            "Atualizações do app", "Notificações sobre atualizações do app.", "Open Remote Control",
            "Baixando atualização", "Verificando atualização", "Atualização pronta para instalar", "Cancelar",
        )
    }

    fun updateChannels(context: Context, language: AppLanguage) {
        if (Build.VERSION.SDK_INT < 26) return
        val manager = context.getSystemService(NotificationManager::class.java)
        val connection = connectionCopy(language)
        val update = updateCopy(language)
        manager.createNotificationChannel(NotificationChannel(
            ConnectionService.CHANNEL_ID, connection.channelName, NotificationManager.IMPORTANCE_LOW,
        ).apply { description = connection.channelDescription })
        manager.createNotificationChannel(NotificationChannel(
            AndroidUpdateService.CHANNEL_ID, update.channelName, NotificationManager.IMPORTANCE_LOW,
        ).apply { description = update.channelDescription })
    }
}
