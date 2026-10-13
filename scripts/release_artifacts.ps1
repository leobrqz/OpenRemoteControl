$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-ProductVersion([string]$Root) {
    $app = [regex]::Match([IO.File]::ReadAllText((Join-Path $Root 'app/pubspec.yaml')), '(?m)^version: (\d+\.\d+\.\d+)\+(\d+)\s*$')
    $server = [regex]::Match([IO.File]::ReadAllText((Join-Path $Root 'web/server/pubspec.yaml')), '(?m)^version: (\d+\.\d+\.\d+)\+(\d+)\s*$')
    if (-not $app.Success -or -not $server.Success -or $app.Groups[1].Value -ne $server.Groups[1].Value -or
        $app.Groups[2].Value -ne $server.Groups[2].Value) { throw 'Android and Windows versions/builds must match.' }
    $version = $app.Groups[1].Value
    $web = Get-Content -Raw -LiteralPath (Join-Path $Root 'web/package.json') | ConvertFrom-Json
    $lockVersions = & node -p 'JSON.stringify([require(process.argv[1]).version,require(process.argv[1]).packages[String()].version])' (Join-Path $Root 'web/package-lock.json') | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read dashboard lockfile.' }
    $shared = [regex]::Match([IO.File]::ReadAllText((Join-Path $Root 'packages/remote_core/pubspec.yaml')), '(?m)^version: (\d+\.\d+\.\d+)\s*$').Groups[1].Value
    if ($web.version -ne $version -or $lockVersions[0] -ne $version -or $lockVersions[1] -ne $version -or $shared -ne $version) {
        throw 'All product versions must be synchronized.'
    }
    return @{ Version = $version; Build = $app.Groups[2].Value }
}
function Read-ZipEntry([string]$Path, [string]$EntryName) {
    $zip = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $entry = $zip.GetEntry($EntryName)
        if (-not $entry) { throw "Missing archive entry: $EntryName" }
        $reader = [IO.StreamReader]::new($entry.Open())
        try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
    } finally { $zip.Dispose() }
}
function Assert-Checksums([string]$Directory, [string]$ExtraDirectory) {
    $sumFile = Join-Path $Directory 'SHA256SUMS.txt'
    $verified = @{}
    foreach ($line in Get-Content -LiteralPath $sumFile) {
        if ($line -notmatch '^([A-Fa-f0-9]{64})  ([^/\\]+)$') { throw 'Invalid checksum file.' }
        $hash = $Matches[1]; $name = $Matches[2]
        $file = Join-Path $Directory $name
        if (-not (Test-Path -LiteralPath $file) -and $ExtraDirectory) { $file = Join-Path $ExtraDirectory $name }
        if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $hash) { throw "Checksum mismatch: $name" }
        if ($verified.ContainsKey($name)) { throw 'Duplicate checksum entry.' }
        $verified[$name] = $hash
    }
    return $verified
}
function Assert-WindowsArtifacts([string]$Directory, [string]$Version, [int]$Build = 0) {
    $name = "org.openremotecontrol.windows-$Version-win-x64-full.nupkg"
    $package = Join-Path $Directory $name
    $feed = Get-Content -Raw -LiteralPath (Join-Path $Directory 'releases.win-x64.json') | ConvertFrom-Json
    if (@($feed.Assets).Count -ne 1) { throw 'Release feed must contain exactly one full package.' }
    $asset = $feed.Assets[0]
    if ($asset.PackageId -ne 'org.openremotecontrol.windows' -or $asset.Version -ne $Version -or
        $asset.Type -ne 'Full' -or $asset.FileName -ne $name -or $asset.Size -ne (Get-Item -LiteralPath $package).Length -or
        $asset.SHA256 -ne (Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash -or
        $asset.SHA1 -ne (Get-FileHash -LiteralPath $package -Algorithm SHA1).Hash) { throw 'Release feed/package mismatch.' }
    [xml]$manifest = Read-ZipEntry (Join-Path $Directory 'OpenRemoteControl-Windows-x64.zip') 'current/sq.version'
    [xml]$packageManifest = Read-ZipEntry $package 'org.openremotecontrol.windows.nuspec'
    if ($manifest.package.metadata.id -ne 'org.openremotecontrol.windows' -or $manifest.package.metadata.version -ne $Version -or
        $manifest.package.metadata.channel -ne 'win-x64') { throw 'Portable ZIP version/channel mismatch.' }
    if ($packageManifest.package.metadata.id -ne $manifest.package.metadata.id -or
        $packageManifest.package.metadata.version -ne $Version -or
        $packageManifest.package.metadata.channel -ne 'win-x64') { throw 'Full update package manifest mismatch.' }
    $zip = [IO.Compression.ZipFile]::OpenRead((Join-Path $Directory 'OpenRemoteControl-Windows-x64.zip'))
    try {
        foreach ($entry in @('Open Remote Control.exe','Update.exe','current/open_remote_control.exe','current/velopack_libc.dll','current/LICENSE.velopack','current/LICENSE.nlohmann')) {
            if (-not $zip.GetEntry($entry)) { throw "Missing managed portable file: $entry" }
        }
        $binary = $zip.GetEntry('current/open_remote_control.exe')
        $reader = [IO.BinaryReader]::new($binary.Open())
        try { $bytes = $reader.ReadBytes([int]$binary.Length) } finally { $reader.Dispose() }
        if ([Text.Encoding]::ASCII.GetString($bytes).Contains('ORC_UPDATER_TEST_SOURCE') -or
            [Text.Encoding]::Unicode.GetString($bytes).Contains('ORC_UPDATER_TEST_SOURCE')) { throw 'Test source must not be shipped.' }
        $temporary = [IO.Path]::GetTempFileName()
        try {
            [IO.File]::WriteAllBytes($temporary, $bytes)
            $resources = [Diagnostics.FileVersionInfo]::GetVersionInfo($temporary)
            if ($resources.ProductVersion.Split('+')[0] -ne $Version -or ($Build -gt 0 -and $resources.FilePrivatePart -ne $Build) -or
                $resources.CompanyName -ne 'org.openremotecontrol' -or $resources.ProductName -ne 'Open Remote Control') {
                throw 'Windows executable version/build or storage identity mismatch.'
            }
        } finally { [IO.File]::Delete($temporary) }
    } finally { $zip.Dispose() }
    return $name
}
