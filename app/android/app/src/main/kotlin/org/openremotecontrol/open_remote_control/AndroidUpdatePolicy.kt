package org.openremotecontrol.open_remote_control

import java.net.URI
import java.security.MessageDigest
import java.io.File
import java.util.zip.ZipFile

/** Pure policy helpers shared by the native updater and its JVM tests. */
internal object AndroidUpdatePolicy {
    private val stableVersion = Regex("^(0|[1-9]\\d*)\\.(0|[1-9]\\d*)\\.(0|[1-9]\\d*)$")
    private val sha256 = Regex("^[0-9a-f]{64}$")

    data class SemVersion(val major: Long, val minor: Long, val patch: Long) : Comparable<SemVersion> {
        override fun compareTo(other: SemVersion): Int = compareValuesBy(
            this, other, SemVersion::major, SemVersion::minor, SemVersion::patch,
        )
    }

    fun parseVersion(value: String): SemVersion? {
        val match = stableVersion.matchEntire(value) ?: return null
        return try {
            SemVersion(match.groupValues[1].toLong(), match.groupValues[2].toLong(), match.groupValues[3].toLong())
        } catch (_: NumberFormatException) { null }
    }

    fun isNewer(candidateName: String, candidateCode: Long, currentName: String, currentCode: Long): Boolean {
        val candidate = parseVersion(candidateName) ?: return false
        val current = parseVersion(currentName) ?: return false
        return candidateCode > currentCode && candidate > current
    }

    private val githubReleaseAsset = Regex(
        "^/leobrqz/OpenRemoteControl/releases/download/v(0|[1-9]\\d*)\\.(0|[1-9]\\d*)\\.(0|[1-9]\\d*)/OpenRemoteControl-Android-universal-release\\.apk$",
    )

    fun validateInitialDownloadUrl(value: String): URI? = try {
        val uri = URI(value)
        if (uri.scheme.equals("https", true) && uri.host.equals("github.com", true) &&
            uri.port == -1 && uri.userInfo == null && uri.rawQuery == null &&
            uri.rawFragment == null && githubReleaseAsset.matches(uri.rawPath ?: "")) uri else null
    } catch (_: Exception) { null }

    fun validateDownloadRedirect(value: String, initialPath: String): URI? = try {
        val uri = URI(value)
        val host = uri.host?.lowercase() ?: return null
        val safeAuthority = uri.scheme.equals("https", true) && (uri.port == -1 || uri.port == 443) &&
            uri.userInfo == null && uri.rawFragment == null
        if (!safeAuthority) return null
        when (host) {
            "github.com" -> if (uri.rawPath == initialPath && uri.rawQuery == null) uri else null
            "release-assets.githubusercontent.com", "objects.githubusercontent.com" -> uri
            else -> null
        }
    } catch (_: Exception) { null }

    fun parseSha256(value: String): ByteArray? {
        if (!sha256.matches(value)) return null
        return ByteArray(32) { index -> value.substring(index * 2, index * 2 + 2).toInt(16).toByte() }
    }

    fun sha256(bytes: ByteArray): String = MessageDigest.getInstance("SHA-256").digest(bytes)
        .joinToString("") { "%02x".format(it) }

    fun supportedAbi(apkAbis: List<String>, deviceAbis: List<String>): Boolean =
        apkAbis.isEmpty() || apkAbis.any { it in deviceAbis }

    fun apkAbis(apk: File): Set<String> = ZipFile(apk).use { archive ->
        val result = mutableSetOf<String>()
        val entries = archive.entries()
        while (entries.hasMoreElements()) {
            val name = entries.nextElement().name
            if (name.startsWith("lib/")) {
                val parts = name.split('/')
                if (parts.size >= 3 && parts[1].isNotBlank() && !parts[2].isBlank()) result.add(parts[1])
            }
        }
        result
    }

    fun cleanupOwnedFiles(directory: File) {
        directory.listFiles()?.forEach { file ->
            if (file.isFile && (file.name.endsWith(".apk") || file.name.endsWith(".part"))) file.delete()
        }
    }
}

/** Small atomic guard prevents two concurrent update starts across method-channel races. */
internal class TransferGate {
    private var generation = 0L
    private var owner: Long? = null

    @Synchronized fun tryStart(): Long? {
        if (owner != null) return null
        generation += 1
        owner = generation
        return owner
    }

    @Synchronized fun isCurrent(token: Long): Boolean = owner == token

    @Synchronized fun release(token: Long): Boolean {
        if (owner != token) return false
        owner = null
        return true
    }
}
