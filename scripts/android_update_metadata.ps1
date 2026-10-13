param(
    [string]$ApkPath,
    [string]$CatalogPath,
    [switch]$Validate
)
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $ApkPath) {
    $ApkPath = Join-Path $root 'output/android/OpenRemoteControl-Android-universal-release.apk'
}
if (-not $CatalogPath) {
    $CatalogPath = Join-Path $root 'output/android/android-update.json'
}
$ApkPath = (Resolve-Path -LiteralPath $ApkPath).Path
$CatalogPath = [IO.Path]::GetFullPath($CatalogPath)

function Get-AndroidSdk([string]$ProjectRoot) {
    $properties = Join-Path $ProjectRoot 'app/android/local.properties'
    if (Test-Path -LiteralPath $properties) {
        $line = Get-Content -LiteralPath $properties | Where-Object { $_ -match '^sdk\.dir=' } | Select-Object -First 1
        if ($line) {
            $value = $line.Substring(8).Replace('\\', '\')
            if (Test-Path -LiteralPath $value) { return (Resolve-Path -LiteralPath $value).Path }
        }
    }
    foreach ($candidate in @($env:ANDROID_SDK_ROOT, $env:ANDROID_HOME)) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    throw 'Android SDK was not found. Set sdk.dir in app/android/local.properties or ANDROID_SDK_ROOT.'
}

function Get-AndroidBuildTools([string]$SdkPath) {
    $directories = Get-ChildItem -LiteralPath (Join-Path $SdkPath 'build-tools') -Directory |
        Where-Object { $_.Name -match '^\d+(\.\d+){1,3}$' } |
        Sort-Object { [version]$_.Name } -Descending
    foreach ($directory in $directories) {
        $aapt = Join-Path $directory.FullName 'aapt.exe'
        $apksigner = Join-Path $directory.FullName 'apksigner.bat'
        if ((Test-Path -LiteralPath $aapt) -and (Test-Path -LiteralPath $apksigner)) {
            return @{ Aapt = $aapt; ApkSigner = $apksigner }
        }
    }
    throw "No Android build-tools containing aapt.exe and apksigner.bat were found in: $SdkPath"
}

function Get-AndroidMetadata([string]$Path) {
    $sdk = Get-AndroidSdk $root
    $tools = Get-AndroidBuildTools $sdk
    $badging = @(& $tools.Aapt dump badging $Path 2>&1 | ForEach-Object { $_.ToString() })
    if ($LASTEXITCODE -ne 0) { throw 'aapt could not read APK metadata.' }

    $packageLine = $badging | Where-Object { $_ -match "^package: name='([^']+)' versionCode='(\d+)' versionName='([^']*)'" } | Select-Object -First 1
    if (-not $packageLine -or $packageLine -notmatch "^package: name='([^']+)' versionCode='(\d+)' versionName='([^']*)'") {
        throw 'APK package, versionCode or versionName is missing.'
    }
    $packageName = $Matches[1]
    $versionCode = [long]$Matches[2]
    $versionName = $Matches[3]
    if ($versionCode -lt 1 -or $versionName -notmatch '^\d+\.\d+\.\d+$') {
        throw 'APK must have a positive versionCode and stable semantic version.'
    }

    $minLine = $badging | Where-Object { $_ -match "^sdkVersion:'(\d+)'$" } | Select-Object -First 1
    if (-not $minLine -or $minLine -notmatch "^sdkVersion:'(\d+)'$") { throw 'APK minSdk is missing or invalid.' }
    $minSdk = [int]$Matches[1]
    $targetLine = $badging | Where-Object { $_ -match "^targetSdkVersion:'(\d+)'$" } | Select-Object -First 1
    if (-not $targetLine -or $targetLine -notmatch "^targetSdkVersion:'(\d+)'$") { throw 'APK targetSdk is missing or invalid.' }
    $targetSdk = [int]$Matches[1]
    $maxLine = $badging | Where-Object { $_ -match "^maxSdkVersion:'(\d+)'$" } | Select-Object -First 1
    $maxSdk = $null
    if ($maxLine) {
        if ($maxLine -notmatch "^maxSdkVersion:'(\d+)'$") { throw 'APK maxSdk is invalid.' }
        $maxSdk = [int]$Matches[1]
    }
    $abiLine = $badging | Where-Object { $_ -match '^native-code:' } | Select-Object -First 1
    $abis = @()
    if ($abiLine) {
        $abis = @([regex]::Matches($abiLine, "'([^']+)'") | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    }

    $signerOutput = @(& $tools.ApkSigner verify --print-certs $Path 2>&1 | ForEach-Object { $_.ToString() })
    if ($LASTEXITCODE -ne 0) { throw 'APK signature validation failed.' }
    $signers = @([regex]::Matches(($signerOutput -join "`n"), 'certificate SHA-256 digest:\s*([A-Fa-f0-9]{64})') |
        ForEach-Object { $_.Groups[1].Value.ToLowerInvariant() } | Sort-Object -Unique)
    if ($signers.Count -eq 0) { throw 'APK signer SHA-256 certificate digest is missing.' }

    $assetHash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    return [ordered]@{
        schemaVersion = 1
        packageName = $packageName
        versionName = $versionName
        versionCode = $versionCode
        minSdk = $minSdk
        targetSdk = $targetSdk
        maxSdk = $maxSdk
        abis = $abis
        signerSha256 = $signers
        asset = [ordered]@{
            name = [IO.Path]::GetFileName($Path)
            size = [long](Get-Item -LiteralPath $Path).Length
            sha256 = $assetHash
        }
    }
}

function ConvertTo-CanonicalJson([object]$Value) {
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        $parts = foreach ($property in ($Value.PSObject.Properties | Sort-Object Name)) {
            $key = ConvertTo-Json -InputObject $property.Name -Compress
            "$key`:$((ConvertTo-CanonicalJson $property.Value))"
        }
        return '{' + ($parts -join ',') + '}'
    }
    if ($Value -is [System.Collections.IDictionary]) {
        $parts = foreach ($keyName in @($Value.Keys | Sort-Object)) {
            $key = ConvertTo-Json -InputObject ([string]$keyName) -Compress
            "$key`:$((ConvertTo-CanonicalJson $Value[$keyName]))"
        }
        return '{' + ($parts -join ',') + '}'
    }
    if ($Value -is [array]) {
        $parts = foreach ($item in $Value) { ConvertTo-CanonicalJson $item }
        return '[' + ($parts -join ',') + ']'
    }
    return ConvertTo-Json -InputObject $Value -Compress
}

$expected = Get-AndroidMetadata $ApkPath
if ($Validate) {
    if (-not (Test-Path -LiteralPath $CatalogPath -PathType Leaf)) { throw "Android update catalog is missing: $CatalogPath" }
    try { $actual = Get-Content -LiteralPath $CatalogPath -Raw | ConvertFrom-Json -ErrorAction Stop }
    catch { throw "Android update catalog is not valid JSON: $CatalogPath" }
    if ((ConvertTo-CanonicalJson $actual) -cne (ConvertTo-CanonicalJson $expected)) {
        throw 'Android update catalog does not exactly match the signed APK metadata.'
    }
    Write-Output "Validated Android update catalog against $([IO.Path]::GetFileName($ApkPath))."
    return
}

$directory = Split-Path -Parent $CatalogPath
if (-not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
$json = ConvertTo-Json -InputObject $expected -Depth 5
[IO.File]::WriteAllText($CatalogPath, $json, [Text.UTF8Encoding]::new($false))
Write-Output "Generated Android update catalog: $CatalogPath"
