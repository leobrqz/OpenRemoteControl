$ErrorActionPreference = 'Stop'

$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'release_common.ps1')
$version = Get-ReleaseVersion -WorkspaceRoot $workspaceRoot
$appDirectory = Join-Path $workspaceRoot 'app'
$outputDirectory = Join-Path $workspaceRoot 'output\android'
$sourceApk = Join-Path $appDirectory 'build\app\outputs\flutter-apk\app-release.apk'
$destinationApk = Join-Path $outputDirectory "OpenRemoteControl-Android-$($version.Tag).apk"

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

Assert-ApkVersion -ApkPath $sourceApk -AppDirectory $appDirectory -Version $version
Copy-Item -LiteralPath $sourceApk -Destination $destinationApk -Force

$readmePath = Join-Path $outputDirectory 'README.md'
$readme = @'
# Android artifact

The versioned Android APK installs on Android 7.0 (API 24) or newer. It is a universal release-mode APK for local installation and uses the existing development signing key. It is not a Play Store build.

On first use, find the Windows PC on the same Wi-Fi and approve its pairing request in the dashboard, or scan a pairing QR from the dashboard's Devices page. The QR expires after five minutes. Without a relay or public route, both devices must be on the same local network. Manual IPv4 and port entry are available if automatic discovery is blocked. The app can copy connection diagnostics from the connection screen.

Generate the APK from the repository root with `./scripts/build_android.ps1`. Its SHA-256 checksum is in `SHA256SUMS.txt`.
'@
Set-Content -LiteralPath $readmePath -Value $readme -Encoding utf8
Write-ArtifactChecksum -ArtifactPath $destinationApk
Get-Item -LiteralPath $destinationApk, $readmePath, (Join-Path $outputDirectory 'SHA256SUMS.txt')
