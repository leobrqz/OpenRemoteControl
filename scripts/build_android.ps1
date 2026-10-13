$ErrorActionPreference = 'Stop'

$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$appDirectory = Join-Path $workspaceRoot 'app'
$outputDirectory = Join-Path $workspaceRoot 'output\android'
$sourceApk = Join-Path $appDirectory 'build\app\outputs\flutter-apk\app-release.apk'
$destinationApk = Join-Path $outputDirectory 'OpenRemoteControl-Android-universal-release.apk'

New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
Push-Location $appDirectory
try {
    & flutter pub get
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter dependency resolution failed with exit code $LASTEXITCODE."
    }

    & flutter build apk --release --no-pub
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter Android build failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}

if (-not (Test-Path -LiteralPath $sourceApk)) {
    throw "Flutter completed without producing the expected APK: $sourceApk"
}

Copy-Item -LiteralPath $sourceApk -Destination $destinationApk -Force

$catalogPath = Join-Path $outputDirectory 'android-update.json'
& (Join-Path $PSScriptRoot 'android_update_metadata.ps1') -ApkPath $destinationApk -CatalogPath $catalogPath
if ($LASTEXITCODE -ne 0) {
    throw "Android update catalog generation failed with exit code $LASTEXITCODE."
}

$readmePath = Join-Path $outputDirectory 'README.md'
$readme = @'
# Android artifact

`OpenRemoteControl-Android-universal-release.apk` installs on Android 7.0 (API 24) or newer. It is a universal release-mode APK for local installation and is signed with Flutter's debug key, so it is not ready for Play Store publication or signing-key continuity across production updates.

On first use, find the Windows PC on the same Wi-Fi and approve its pairing request in the dashboard, or scan a pairing QR from the dashboard's Devices page. The QR expires after five minutes. Without a relay or public route, both devices must be on the same local network. The Add menu offers QR scanning and manual IPv4/port entry. The navigation drawer opens mouse, connection, theme and display settings; connection diagnostics can be copied from Settings.

Generate the APK from the repository root with `./scripts/build_android.ps1`. Its SHA-256 checksum is in `SHA256SUMS.txt`.
'@
Set-Content -LiteralPath $readmePath -Value $readme -Encoding utf8
$checksums = foreach ($artifact in @($destinationApk, $catalogPath)) {
    "$((Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash)  $(Split-Path -Leaf $artifact)"
}
$checksumsPath = Join-Path $outputDirectory 'SHA256SUMS.txt'
Set-Content -LiteralPath $checksumsPath -Value $checksums -Encoding ascii
Get-Item -LiteralPath $destinationApk, $catalogPath, $readmePath, $checksumsPath
