param([string]$ReleaseNotes, [string]$FixtureVersion, [switch]$TestFixture)
$ErrorActionPreference = 'Stop'

$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$appDirectory = Join-Path $workspaceRoot 'web\server'
$outputDirectory = Join-Path $workspaceRoot 'output\windows'
$releaseDirectory = Join-Path $appDirectory 'build\windows\x64\runner\Release'
$archivePath = Join-Path $outputDirectory 'OpenRemoteControl-Windows-x64.zip'
$webDirectory = Join-Path $workspaceRoot 'web'
$version = [regex]::Match([IO.File]::ReadAllText((Join-Path $appDirectory 'pubspec.yaml')), '(?m)^version: (\d+\.\d+\.\d+)\+(\d+)').Groups[1].Value
if ($FixtureVersion -and -not $TestFixture) { throw 'FixtureVersion requires TestFixture.' }
if ($TestFixture) {
    if ($FixtureVersion) { $version = $FixtureVersion }
    $outputDirectory = Join-Path $workspaceRoot "output\fixtures\$version"
    $archivePath = Join-Path $outputDirectory 'OpenRemoteControl-Windows-x64.zip'
}
if (-not $version) { throw 'Invalid Windows product version.' }
$dotnetCommand = 'dotnet'
if (-not (& dotnet --list-sdks)) {
    $localSdk = Join-Path $env:USERPROFILE '.dotnet\dotnet.exe'
    if (Test-Path -LiteralPath $localSdk) { $dotnetCommand = $localSdk }
}
& $dotnetCommand tool restore
if ($LASTEXITCODE -ne 0) { throw 'Pinned Velopack CLI restore failed. Install the .NET SDK.' }

New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
Push-Location $webDirectory
try {
    & npm ci --no-audit --no-fund
    if ($LASTEXITCODE -ne 0) {
        throw "Dashboard dependency installation failed with exit code $LASTEXITCODE."
    }

    & npm run build
    if ($LASTEXITCODE -ne 0) {
        throw "Dashboard asset build failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}

New-Item -ItemType Directory -Force -Path (Join-Path $appDirectory 'assets\dashboard') | Out-Null
Copy-Item -Path (Join-Path $webDirectory 'dist\*') -Destination (Join-Path $appDirectory 'assets\dashboard') -Recurse -Force

Push-Location $appDirectory
try {
    & flutter pub get
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter dependency resolution failed with exit code $LASTEXITCODE."
    }

    $previousFixture = $env:ORC_UPDATER_TESTING
    $env:ORC_UPDATER_TESTING = if ($TestFixture) { '1' } else { '0' }
    $buildArguments = @('build', 'windows', '--release', '--no-pub')
    if ($FixtureVersion) { $buildArguments += @('--build-name', $FixtureVersion) }
    try { & flutter @buildArguments }
    finally { $env:ORC_UPDATER_TESTING = $previousFixture }
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

$packDirectory = Join-Path $appDirectory ("build\velopack\" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $packDirectory | Out-Null
$packArguments = @('tool', 'run', 'vpk', '--', 'pack', '--packId', 'org.openremotecontrol.windows',
    '--packVersion', $version, '--packDir', $releaseDirectory, '--mainExe', 'open_remote_control.exe',
    '--packTitle', 'Open Remote Control', '--packAuthors', 'org.openremotecontrol',
    '--runtime', 'win-x64', '--channel', 'win-x64', '--delta', 'None', '--noInst',
    '--exclude', '.*\.pdb$|update_policy_test\.exe$',
    '--icon', (Join-Path $appDirectory 'windows\runner\resources\app_icon.ico'), '--outputDir', $packDirectory)
if ($ReleaseNotes) { $packArguments += @('--releaseNotes', (Resolve-Path -LiteralPath $ReleaseNotes).Path) }
& $dotnetCommand @packArguments
if ($LASTEXITCODE -ne 0) { throw 'Velopack packaging / entrypoint verification failed.' }
$portable = Join-Path $packDirectory 'org.openremotecontrol.windows-win-x64-Portable.zip'
$fullPackage = Join-Path $packDirectory "org.openremotecontrol.windows-$version-win-x64-full.nupkg"
$feed = Join-Path $packDirectory 'releases.win-x64.json'
foreach ($artifact in @($portable, $fullPackage, $feed)) {
    if (-not (Test-Path -LiteralPath $artifact)) { throw "Missing Velopack artifact: $artifact" }
}
# A release contains one full package; never carry older / fixture entries into its feed.
$metadata = Get-Content -Raw -LiteralPath $feed | ConvertFrom-Json
$metadata.Assets = @($metadata.Assets | Where-Object { $_.Version -eq $version -and $_.Type -eq 'Full' })
if ($metadata.Assets.Count -ne 1) { throw 'Expected exactly one matching full release.' }
[IO.File]::WriteAllText($feed, ($metadata | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath $portable -Destination $archivePath -Force
Copy-Item -LiteralPath $fullPackage, $feed -Destination $outputDirectory -Force

$readmePath = Join-Path $outputDirectory 'README.md'
$readme = @'
# Windows artifact

Extract `OpenRemoteControl-Windows-x64.zip` into a user-writable directory and run its root launcher, `Open Remote Control.exe`. Keep the launcher, `Update.exe`, `current/` and `packages/` together.
Keep this directory in place so updates retain the executable path and its existing Windows Firewall authorization.
The server starts automatically and stays in the Windows notification area. Double-click the tray icon to open the dashboard in your browser; right-click it to open the dashboard or exit.

In the dashboard's Devices page, scan the QR with the Android app or approve its pairing request. The QR expires after five minutes. Without a relay or public route, both devices must be on the same local network. Discovery uses UDP 47653 and control uses TCP 47652.

Updates are checked after startup. Approve downloading and restarting in About > Updates in the local dashboard. From 0.2.1, stop the old server and extract this first managed ZIP into a new user-writable directory; pairing and server identity are preserved.

Windows diagnostics are saved to `%LOCALAPPDATA%\OpenRemoteControl\logs\open-remote.log`. Checksums for the ZIP, full update package and feed are in `SHA256SUMS.txt`.
'@
Set-Content -LiteralPath $readmePath -Value $readme -Encoding utf8
$artifacts = @($archivePath, (Join-Path $outputDirectory (Split-Path -Leaf $fullPackage)), (Join-Path $outputDirectory (Split-Path -Leaf $feed)))
$checksums = foreach ($artifact in $artifacts) {
    "$((Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash)  $(Split-Path -Leaf $artifact)"
}
Set-Content -LiteralPath (Join-Path $outputDirectory 'SHA256SUMS.txt') -Value $checksums -Encoding ascii
Get-Item -LiteralPath $archivePath, $readmePath, (Join-Path $outputDirectory 'SHA256SUMS.txt')
