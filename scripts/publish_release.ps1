param(
    [Parameter(Mandatory)]
    [ValidatePattern('^v\d+\.\d+\.\d+$')]
    [string]$Tag,
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'release_common.ps1')
$version = Get-ReleaseVersion -WorkspaceRoot $workspaceRoot
if ($Tag -ne $version.Tag) { throw "Tag $Tag does not match app version $($version.Tag)." }

Push-Location $workspaceRoot
try {
    $tagType = git cat-file -t "refs/tags/$Tag"
    if ($LASTEXITCODE -ne 0 -or $tagType -ne 'tag') {
        throw 'Use an annotated version tag with an English title and concise changelog.'
    }
    $headCommit = git rev-parse HEAD
    $tagCommit = git rev-parse "$Tag^{commit}"
    if ($headCommit -ne $tagCommit) { throw 'Check out the version tag before publishing.' }
    $tagMessage = @(git for-each-ref '--format=%(contents)' "refs/tags/$Tag")
    $title = $tagMessage[0].Trim()
    $notes = ($tagMessage | Select-Object -Skip 1) -join "`n"
    if (-not $title.StartsWith($Tag) -or -not $notes.Trim()) {
        throw 'The tag message must start with the version title and include an English changelog.'
    }

    # Retrying a published tag must not replace its downloads.
    $publishedTags = @(gh release list --limit 100 --json tagName --jq '.[].tagName')
    if ($LASTEXITCODE -ne 0) { throw 'Could not read published releases.' }
    if ($publishedTags -contains $Tag) {
        Write-Output "Release $Tag is already published."
        exit 0
    }

    if (-not $SkipBuild) {
        & (Join-Path $PSScriptRoot 'build_windows.ps1')
        & (Join-Path $PSScriptRoot 'build_android.ps1')
    }
    $windowsZip = Join-Path $workspaceRoot "output/windows/OpenRemoteControl-Windows-x64-$Tag.zip"
    $androidApk = Join-Path $workspaceRoot "output/android/OpenRemoteControl-Android-$Tag.apk"
    foreach ($artifact in @($windowsZip, $androidApk)) {
        if (-not (Test-Path -LiteralPath $artifact)) { throw "Missing release artifact: $artifact" }
        $checksumFile = Join-Path (Split-Path $artifact) 'SHA256SUMS.txt'
        $expected = ((Get-Content -LiteralPath $checksumFile -Raw).Trim() -split '\s+')[0]
        if ((Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash -ine $expected) {
            throw "Checksum mismatch: $artifact"
        }
    }
    $checksums = Join-Path $workspaceRoot 'output/SHA256SUMS.txt'
    $notesPath = Join-Path $workspaceRoot "output/release-notes-$Tag.md"
    Set-Content -LiteralPath $notesPath -Value $notes.Trim() -Encoding utf8
    Get-Content -LiteralPath (Join-Path $workspaceRoot 'output/windows/SHA256SUMS.txt'), (Join-Path $workspaceRoot 'output/android/SHA256SUMS.txt') |
        Set-Content -LiteralPath $checksums -Encoding ascii

    $publishedTags = @(gh release list --limit 100 --json tagName --jq '.[].tagName')
    if ($LASTEXITCODE -ne 0) { throw 'Could not read published releases.' }
    if ($publishedTags -contains $Tag) {
        Write-Output "Release $Tag was published while building."
        exit 0
    }
    gh release create $Tag $windowsZip $androidApk $checksums --verify-tag --title $title --notes-file $notesPath
    if ($LASTEXITCODE -ne 0) { throw "Could not publish release $Tag." }
}
finally {
    Pop-Location
}
