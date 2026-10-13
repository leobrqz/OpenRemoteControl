function Get-ReleaseVersion {
    param([string]$WorkspaceRoot)

    $pubspec = Get-Content -LiteralPath (Join-Path $WorkspaceRoot 'app/pubspec.yaml') -Raw
    $match = [regex]::Match($pubspec, '(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$')
    if (-not $match.Success) {
        throw 'app/pubspec.yaml must contain version: MAJOR.MINOR.PATCH+BUILD.'
    }
    [pscustomobject]@{
        Name = $match.Groups[1].Value
        Build = $match.Groups[2].Value
        Tag = 'v' + $match.Groups[1].Value
    }
}

function Write-ArtifactChecksum {
    param([string]$ArtifactPath)

    $hash = (Get-FileHash -LiteralPath $ArtifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $checksumPath = Join-Path (Split-Path $ArtifactPath) 'SHA256SUMS.txt'
    Set-Content -LiteralPath $checksumPath -Value "$hash  $(Split-Path -Leaf $ArtifactPath)" -Encoding ascii
}

function Assert-ApkVersion {
    param([string]$ApkPath, [string]$AppDirectory, $Version)

    $properties = Get-Content -LiteralPath (Join-Path $AppDirectory 'android/local.properties') -Raw
    $sdkPath = [regex]::Match($properties, '(?m)^sdk\.dir=(.+)$').Groups[1].Value.Trim().Replace('\\', '\').Replace('\:', ':')
    if (-not $sdkPath) { throw 'Android SDK location is missing.' }
    $aaptName = if ($env:OS -eq 'Windows_NT') { 'aapt.exe' } else { 'aapt' }
    $aapt = Get-ChildItem -LiteralPath (Join-Path $sdkPath 'build-tools') -Directory |
        Sort-Object Name -Descending |
        ForEach-Object { Join-Path $_.FullName $aaptName } |
        Where-Object { Test-Path -LiteralPath $_ } |
        Select-Object -First 1
    if (-not $aapt) { throw 'Android aapt is required to verify APK metadata.' }
    $badging = (& $aapt dump badging $ApkPath) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw 'Could not inspect APK metadata.' }
    $apkName = [regex]::Match($badging, "versionName='([^']+)'").Groups[1].Value
    $apkBuild = [regex]::Match($badging, "versionCode='([^']+)'").Groups[1].Value
    if ($apkName -ne $Version.Name -or $apkBuild -ne $Version.Build) {
        throw "APK metadata $apkName+$apkBuild does not match $($Version.Name)+$($Version.Build)."
    }
    Write-Output "Verified Android $apkName (build $apkBuild)."
}
