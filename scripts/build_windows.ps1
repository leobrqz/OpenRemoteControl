$ErrorActionPreference = 'Stop'

$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$appDirectory = Join-Path $workspaceRoot 'app'
$outputDirectory = Join-Path $workspaceRoot 'output\windows'
$releaseDirectory = Join-Path $appDirectory 'build\windows\x64\runner\Release'
$archivePath = Join-Path $outputDirectory 'OpenRemoteControl-Windows-x64.zip'

New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
Push-Location $appDirectory
try {
    & flutter pub get
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter dependency resolution failed with exit code $LASTEXITCODE."
    }

    & flutter build windows --release --no-pub
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter Windows build failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}

if (-not (Test-Path -LiteralPath $releaseDirectory)) {
    throw "Flutter completed without producing the expected Windows bundle: $releaseDirectory"
}

Compress-Archive -Path (Join-Path $releaseDirectory '*') -DestinationPath $archivePath -Force

$readmePath = Join-Path $outputDirectory 'README.md'
$readme = @'
# Windows artifact

Extract `OpenRemoteControl-Windows-x64.zip` and run `open_remote_control.exe`.
The server starts automatically and stays in the Windows notification area. Double-click the tray icon to open the localhost dashboard; right-click it to show the app or exit.

Open the Android app and approve its first pairing request in the dashboard. If Windows Firewall asks, allow the app on the network profile currently in use. Discovery uses UDP 47653 and control uses TCP 47652.

Windows diagnostics are saved to `%LOCALAPPDATA%\OpenRemoteControl\logs\open-remote.log`. The SHA-256 checksum for the ZIP is in `SHA256SUMS.txt`.
'@
Set-Content -LiteralPath $readmePath -Value $readme -Encoding utf8
$checksum = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
Set-Content -LiteralPath (Join-Path $outputDirectory 'SHA256SUMS.txt') `
    -Value "$checksum  $(Split-Path -Leaf $archivePath)" -Encoding ascii
Get-Item -LiteralPath $archivePath, $readmePath, (Join-Path $outputDirectory 'SHA256SUMS.txt')
