param([switch]$SkipBuild)

$ErrorActionPreference = 'Stop'
$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'release_common.ps1')
$version = Get-ReleaseVersion -WorkspaceRoot $workspaceRoot
$appDirectory = Join-Path $workspaceRoot 'app'
$outputDirectory = Join-Path $workspaceRoot 'output/windows'
$releaseDirectory = Join-Path $appDirectory 'build/windows/x64/runner/Release'
$archivePath = Join-Path $outputDirectory "OpenRemoteControl-Windows-x64-$($version.Tag).zip"
$webDirectory = Join-Path $appDirectory 'web'

New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
if (-not $SkipBuild) {
    Push-Location $webDirectory
    try {
        & npm ci --no-audit --no-fund
        if ($LASTEXITCODE -ne 0) { throw 'Dashboard dependency installation failed.' }
        & npm run build
        if ($LASTEXITCODE -ne 0) { throw 'Dashboard asset build failed.' }
    }
    finally { Pop-Location }

    Push-Location $appDirectory
    try {
        & flutter clean
        if ($LASTEXITCODE -ne 0) { throw 'Flutter build cleanup failed.' }
        & flutter pub get
        if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency resolution failed.' }
        & flutter build windows --release --no-pub
        if ($LASTEXITCODE -ne 0) { throw 'Flutter Windows build failed.' }
    }
    finally { Pop-Location }
}

if (-not (Test-Path -LiteralPath $releaseDirectory)) {
    throw "Windows bundle is missing: $releaseDirectory"
}
$executableVersion = (Get-Item -LiteralPath (Join-Path $releaseDirectory 'open_remote_control.exe')).VersionInfo
if ($executableVersion.ProductVersion -ne "$($version.Name)+$($version.Build)" -or $executableVersion.FilePrivatePart -ne [int]$version.Build) {
    throw "Windows executable version does not match $($version.Name)+$($version.Build)."
}
Copy-Item -LiteralPath (Join-Path $workspaceRoot 'LICENSE') -Destination (Join-Path $releaseDirectory 'LICENSE') -Force
Compress-Archive -Path (Join-Path $releaseDirectory '*') -DestinationPath $archivePath -Force
$readmePath = Join-Path $outputDirectory 'README.md'
Set-Content -LiteralPath $readmePath -Encoding utf8 -Value @'
# Windows artifact

Extract the versioned Windows ZIP and run open_remote_control.exe.
Double-click its tray icon to open the dashboard in your browser; right-click to exit.
Find the PC in the Android app and approve pairing in the Devices page, or scan its QR.
Both devices must be on the same local network. Discovery uses UDP 47653 and control uses TCP 47652.
The package version is in the executable properties and the dashboard's About page.
The ZIP's SHA-256 checksum is in SHA256SUMS.txt.
'@
Write-ArtifactChecksum -ArtifactPath $archivePath
Get-Item -LiteralPath $archivePath, $readmePath, (Join-Path $outputDirectory 'SHA256SUMS.txt')
