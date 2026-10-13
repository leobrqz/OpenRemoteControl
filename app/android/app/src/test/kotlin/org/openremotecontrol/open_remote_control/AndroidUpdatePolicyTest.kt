package org.openremotecontrol.open_remote_control

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.nio.file.Files
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

class AndroidUpdatePolicyTest {
    @Test fun onlyStableSemanticVersionsAreAcceptedAndBothVersionsMustAdvance() {
        assertEquals(AndroidUpdatePolicy.SemVersion(2, 14, 0), AndroidUpdatePolicy.parseVersion("2.14.0"))
        listOf("v2.14.0", "2.14", "2.14.0-rc.1", "02.14.0", "2.14.0+5", "2.14.0 ").forEach {
            assertNull("$it must not be treated as stable", AndroidUpdatePolicy.parseVersion(it))
        }
        assertTrue(AndroidUpdatePolicy.isNewer("0.4.0", 10, "0.3.99", 9))
        assertFalse(AndroidUpdatePolicy.isNewer("0.4.0", 9, "0.3.99", 9))
        assertFalse(AndroidUpdatePolicy.isNewer("0.3.99", 11, "0.4.0", 10))
    }

    @Test fun downloadUrlRequiresHttpsWithoutEmbeddedCredentials() {
        val url = "https://github.com/leobrqz/OpenRemoteControl/releases/download/v1.2.3/OpenRemoteControl-Android-universal-release.apk"
        val path = AndroidUpdatePolicy.validateInitialDownloadUrl(url)?.rawPath ?: error("valid release asset rejected")
        assertNull(AndroidUpdatePolicy.validateInitialDownloadUrl("http://github.com/leobrqz/OpenRemoteControl/releases/download/v1.2.3/OpenRemoteControl-Android-universal-release.apk"))
        assertNull(AndroidUpdatePolicy.validateInitialDownloadUrl("https://user:secret@github.com/leobrqz/OpenRemoteControl/releases/download/v1.2.3/OpenRemoteControl-Android-universal-release.apk"))
        assertNull(AndroidUpdatePolicy.validateInitialDownloadUrl("https://github.com:443/leobrqz/OpenRemoteControl/releases/download/v1.2.3/OpenRemoteControl-Android-universal-release.apk"))
        assertNull(AndroidUpdatePolicy.validateInitialDownloadUrl("https://github.com/leobrqz/OpenRemoteControl/releases/download/v1.2.3/other.apk"))
        assertNull(AndroidUpdatePolicy.validateInitialDownloadUrl("https://github.com/leobrqz/OpenRemoteControl/releases/download/v1.2.3/OpenRemoteControl-Android-universal-release.apk?token=x"))
        assertEquals("release-assets.githubusercontent.com", AndroidUpdatePolicy.validateDownloadRedirect(
            "https://release-assets.githubusercontent.com/asset.apk?signature=abc", path)?.host)
        assertEquals("objects.githubusercontent.com", AndroidUpdatePolicy.validateDownloadRedirect(
            "https://objects.githubusercontent.com/asset.apk?signature=abc", path)?.host)
        assertEquals(path, AndroidUpdatePolicy.validateDownloadRedirect("https://github.com$path", path)?.rawPath)
        assertNull(AndroidUpdatePolicy.validateDownloadRedirect("https://evil.example/asset.apk", path))
        assertNull(AndroidUpdatePolicy.validateDownloadRedirect("https://github.com/other/repo/file.apk", path))
        assertNull(AndroidUpdatePolicy.validateDownloadRedirect("https://release-assets.githubusercontent.com:444/asset.apk", path))
    }

    @Test fun packageHashAndAbiPoliciesAreStrict() {
        val expected = "a".repeat(64)
        assertEquals(32, AndroidUpdatePolicy.parseSha256(expected)?.size)
        assertNull(AndroidUpdatePolicy.parseSha256(expected.uppercase()))
        assertTrue(AndroidUpdatePolicy.supportedAbi(listOf("arm64-v8a"), listOf("arm64-v8a", "armeabi-v7a")))
        assertFalse(AndroidUpdatePolicy.supportedAbi(listOf("x86_64"), listOf("arm64-v8a")))
        assertTrue(AndroidUpdatePolicy.supportedAbi(emptyList(), listOf("arm64-v8a")))
    }

    @Test fun apkArchitectureInspectionReadsOnlyNativeLibraryDirectories() {
        val apk = Files.createTempFile("orc-abi", ".apk").toFile()
        try {
            ZipOutputStream(apk.outputStream()).use { zip ->
                listOf("AndroidManifest.xml", "lib/arm64-v8a/libnative.so", "lib/x86_64/libother.so")
                    .forEach { name -> zip.putNextEntry(ZipEntry(name)); zip.write(byteArrayOf(1)); zip.closeEntry() }
            }
            assertEquals(setOf("arm64-v8a", "x86_64"), AndroidUpdatePolicy.apkAbis(apk))
        } finally { apk.delete() }
    }

    @Test fun onlyOneRacingDownloadCanOwnTheOperationGate() {
        val gate = TransferGate()
        val workers = Executors.newFixedThreadPool(12)
        val start = CountDownLatch(1)
        val attempted = CountDownLatch(12)
        val finished = CountDownLatch(12)
        val winners = java.util.concurrent.atomic.AtomicInteger()
        repeat(12) {
            workers.execute {
                start.await()
                val token = gate.tryStart()
                if (token != null) winners.incrementAndGet()
                attempted.countDown()
                if (token != null) { attempted.await(); gate.release(token) }
                finished.countDown()
            }
        }
        start.countDown()
        assertTrue(finished.await(3, TimeUnit.SECONDS))
        workers.shutdownNow()
        assertEquals(1, winners.get())
    }

    @Test fun cancelledWorkerKeepsItsGateUntilExitAndStaleTokenCannotReleaseRetry() {
        val gate = TransferGate()
        val cancelledToken = gate.tryStart() ?: error("first operation did not start")
        // Cancellation invalidates work at the caller but must not free shared files until its worker exits.
        assertTrue(gate.isCurrent(cancelledToken))
        assertNull(gate.tryStart())
        assertTrue(gate.release(cancelledToken))
        val retryToken = gate.tryStart() ?: error("retry did not start after worker exit")
        assertFalse(gate.isCurrent(cancelledToken))
        assertFalse(gate.release(cancelledToken))
        assertTrue(gate.isCurrent(retryToken))
        assertTrue(gate.release(retryToken))
    }

    @Test fun startupCleanupRemovesOnlyUpdaterApkAndPartialFiles() {
        val directory = Files.createTempDirectory("orc-update-policy").toFile()
        try {
            val apk = File(directory, "approved-update.apk").apply { writeText("apk") }
            val part = File(directory, "approved-update.part").apply { writeText("partial") }
            val unrelated = File(directory, "user-note.txt").apply { writeText("keep") }
            AndroidUpdatePolicy.cleanupOwnedFiles(directory)
            assertFalse(apk.exists())
            assertFalse(part.exists())
            assertTrue(unrelated.exists())
        } finally { directory.listFiles()?.forEach { it.delete() }; directory.delete() }
    }
}
