param(
    [Parameter(Mandatory = $true)][string]$NotesFile,
    [string]$Tag,
    [string]$Title,
    [switch]$ValidateOnly
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'release_artifacts.ps1')
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $root
try {
    $product = Get-ProductVersion $root
    $version = $product.Version
    if (-not $Tag) { $Tag = "v$version" }
    if ($Tag -ne "v$version") { throw 'Tag must match the product version.' }
    if (-not $Title) { $Title = "$Tag - User-approved Windows updates" }
    if (-not $Title.Contains($version)) { throw 'Release title must include the version.' }
    if ((git branch --show-current) -ne 'main') { throw 'Releases must be made on main.' }
    if ((git status --porcelain --untracked-files=no)) { throw 'Commit intended source before publishing.' }
    $notes = (Resolve-Path -LiteralPath $NotesFile).Path
    if (-not [IO.File]::ReadAllText($notes).Trim()) { throw 'Release notes cannot be empty.' }
    $windows = Join-Path $root 'output/windows'
    $android = Join-Path $root 'output/android'
    $winHashes = Assert-Checksums $windows $android
    $androidHashes = Assert-Checksums $android
    $packageName = Assert-WindowsArtifacts $windows $version $product.Build
    foreach ($name in @('OpenRemoteControl-Windows-x64.zip', $packageName, 'releases.win-x64.json')) {
        if (-not $winHashes.ContainsKey($name)) { throw "Missing artifact checksum: $name" }
    }
    $apkName = 'OpenRemoteControl-Android-universal-release.apk'
    if (-not $androidHashes.ContainsKey($apkName)) { throw 'Missing APK checksum.' }
    $sdkLine = Get-Content -LiteralPath (Join-Path $root 'app/android/local.properties') | Where-Object { $_ -like 'sdk.dir=*' }
    $sdk = $sdkLine.Substring(8).Replace('\\','\')
    $tools = Get-ChildItem -LiteralPath (Join-Path $sdk 'build-tools') -Directory | Sort-Object Name -Descending | Select-Object -First 1
    $badging = & (Join-Path $tools.FullName 'aapt.exe') dump badging (Join-Path $android $apkName)
    if ($LASTEXITCODE -ne 0 -or $badging[0] -notmatch "versionCode='$($product.Build)'" -or
        $badging[0] -notmatch "versionName='$version'") { throw 'APK version/build mismatch.' }
    $cert = & (Join-Path $tools.FullName 'apksigner.bat') verify --print-certs (Join-Path $android $apkName)
    if ($LASTEXITCODE -ne 0) { throw 'APK signature validation failed.' }
    # Compare to the last distributed APK, rather than relying on a local key filename.
    $previous = gh release view --json tagName --jq '.tagName'
    if ($LASTEXITCODE -ne 0) { throw 'Cannot determine the previous release.' }
    $verification = Join-Path $root ".codex/release-verification/$Tag"
    New-Item -ItemType Directory -Path $verification -Force | Out-Null
    $baseline = Join-Path $verification 'baseline'
    New-Item -ItemType Directory -Path $baseline -Force | Out-Null
    gh release download $previous --pattern $apkName --dir $baseline --clobber
    if ($LASTEXITCODE -ne 0) { throw 'Cannot verify APK signing-key continuity.' }
    $previousCert = & (Join-Path $tools.FullName 'apksigner.bat') verify --print-certs (Join-Path $baseline $apkName)
    if ($LASTEXITCODE -ne 0 -or ($previousCert | Where-Object { $_ -like 'Signer #1 certificate SHA-256 digest:*' }) -ne
        ($cert | Where-Object { $_ -like 'Signer #1 certificate SHA-256 digest:*' })) { throw 'Android signing key changed.' }
    if ($ValidateOnly) { Write-Output "Validated $Tag+$($product.Build), managed portable feed, checksums and APK signing continuity."; return }

    $ErrorActionPreference = 'Continue'
    $existing = gh release view $Tag --json isDraft 2>$null
    $releaseExists = $LASTEXITCODE -eq 0
    $ErrorActionPreference = 'Stop'
    if ($releaseExists -and -not ($existing | ConvertFrom-Json).isDraft) { throw 'Published releases are immutable.' }
    git show-ref --verify --quiet "refs/tags/$Tag"
    if ($LASTEXITCODE -eq 0) {
        if ((git cat-file -t "refs/tags/$Tag") -ne 'tag' -or (git rev-list -n 1 $Tag) -ne (git rev-parse HEAD)) {
            throw 'Existing tag does not annotate the release commit.'
        }
    } else {
        git ls-remote --exit-code --tags origin "refs/tags/$Tag" 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { throw 'Remote tag already exists.' }
        if ($LASTEXITCODE -ne 2) { throw 'Cannot verify remote tag immutability.' }
        git tag -a $Tag -m $Title
        if ($LASTEXITCODE -ne 0) { throw 'Annotated tag creation failed.' }
    }
    git push origin main $Tag
    if ($LASTEXITCODE -ne 0) { throw 'Release commit/tag push failed.' }
    $artifacts = @((Join-Path $android $apkName), (Join-Path $windows 'OpenRemoteControl-Windows-x64.zip'),
        (Join-Path $windows $packageName), (Join-Path $windows 'releases.win-x64.json'))
    $sums = Join-Path $windows 'SHA256SUMS.txt'
    $lines = foreach ($path in $artifacts) { "$((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash)  $(Split-Path -Leaf $path)" }
    Set-Content -LiteralPath $sums -Value $lines -Encoding ascii
    $artifacts += $sums
    if (-not $releaseExists) {
        gh release create $Tag --verify-tag --draft --title $Title --notes-file $notes
        if ($LASTEXITCODE -ne 0) { throw 'Draft release creation failed.' }
    }
    $remote = gh release view $Tag --json assets | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect draft attachments.' }
    foreach ($artifact in $artifacts) {
        $name = Split-Path -Leaf $artifact
        if ($remote.assets.name -notcontains $name) {
            gh release upload $Tag $artifact
            if ($LASTEXITCODE -ne 0) { throw "Upload failed; release remains draft: $name" }
        }
    }
    $download = Join-Path $verification 'published'
    New-Item -ItemType Directory -Path $download -Force | Out-Null
    gh release download $Tag --dir $download --clobber
    if ($LASTEXITCODE -ne 0) { throw 'Attachment verification download failed; release remains draft.' }
    foreach ($artifact in $artifacts) {
        $remoteFile = Join-Path $download (Split-Path -Leaf $artifact)
        if ((Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $remoteFile -Algorithm SHA256).Hash) {
            throw "Published attachment mismatch; release remains draft: $remoteFile"
        }
    }
    Assert-Checksums $download | Out-Null
    Assert-WindowsArtifacts $download $version $product.Build | Out-Null
    $remote = gh release view $Tag --json assets | ConvertFrom-Json
    if (@($remote.assets).Count -ne $artifacts.Count) { throw 'Unexpected release attachments; release remains draft.' }
    gh release edit $Tag --draft=false --latest --title $Title --notes-file $notes
    if ($LASTEXITCODE -ne 0) { throw 'Release publication failed.' }
    $published = gh release view $Tag --json url,isDraft,assets | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or $published.isDraft -or @($published.assets).Count -ne $artifacts.Count) { throw 'Published release verification failed.' }
    Write-Output $published.url
} finally { Pop-Location }
