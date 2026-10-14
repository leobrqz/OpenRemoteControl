package org.openremotecontrol.open_remote_control

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AppNotificationLanguageTest {
    @Test fun savedLanguageNormalizationNeverDependsOnTheSystemLocale() {
        assertEquals(AppLanguage.ENGLISH, AppLanguage.normalize(null))
        assertEquals(AppLanguage.ENGLISH, AppLanguage.normalize("en-US"))
        assertEquals(AppLanguage.ENGLISH, AppLanguage.normalize("en_US"))
        assertEquals(AppLanguage.PORTUGUESE_BRAZIL, AppLanguage.normalize("pt-BR"))
        assertEquals(AppLanguage.PORTUGUESE_BRAZIL, AppLanguage.normalize("pt_BR"))
        assertEquals(AppLanguage.ENGLISH, AppLanguage.normalize("fr-FR"))
        assertEquals(AppLanguage.PORTUGUESE_BRAZIL, AppLanguage.requested("pt-BR"))
        assertEquals(AppLanguage.ENGLISH, AppLanguage.requested("en-US"))
        assertNull(AppLanguage.requested("pt"))
        assertNull(AppLanguage.requested("fr-FR"))
    }

    @Test fun connectionAndUpdateNotificationCopiesCoverBothSupportedLanguages() {
        val englishConnection = AppNotificationLanguage.connectionCopy(AppLanguage.ENGLISH)
        val portugueseConnection = AppNotificationLanguage.connectionCopy(AppLanguage.PORTUGUESE_BRAZIL)
        assertEquals("Connected to", englishConnection.connectedTo)
        assertEquals("Conexão com", portugueseConnection.connectedTo)
        assertEquals("Connection", englishConnection.channelName)
        assertEquals("Conexão", portugueseConnection.channelName)
        assertEquals(englishConnection.title, portugueseConnection.title)

        val englishUpdate = AppNotificationLanguage.updateCopy(AppLanguage.ENGLISH)
        val portugueseUpdate = AppNotificationLanguage.updateCopy(AppLanguage.PORTUGUESE_BRAZIL)
        assertEquals("Downloading update", englishUpdate.downloading)
        assertEquals("Baixando atualização", portugueseUpdate.downloading)
        assertEquals("Checking update", englishUpdate.validating)
        assertEquals("Verificando atualização", portugueseUpdate.validating)
        assertEquals("Update is ready to install", englishUpdate.ready)
        assertEquals("Atualização pronta para instalar", portugueseUpdate.ready)
        assertEquals("Cancel", englishUpdate.cancel)
        assertEquals("Cancelar", portugueseUpdate.cancel)
        assertEquals(englishUpdate.title, portugueseUpdate.title)
    }
}
