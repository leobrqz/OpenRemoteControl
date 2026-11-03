$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'release_artifacts.ps1')

$first = 'a' * 64
$second = 'b' * 64
$legacy = @("Signer #1 certificate SHA-256 digest: $first")
$current = @("V2 Signer: certificate SHA-256 digest: $first", "V3 Signer: certificate SHA-256 digest: $first")
if ((@(Get-ApkSignerDigests $legacy) -join ',') -cne (@(Get-ApkSignerDigests $current) -join ',')) {
    throw 'Equivalent signer output formats were not matched.'
}
$multiple = @("V2 Signer: certificate SHA-256 digest: $second", "V3 Signer: certificate SHA-256 digest: $first")
if ((@(Get-ApkSignerDigests $multiple) -join ',') -cne "$first,$second") {
    throw 'Distinct signers were not sorted and retained.'
}
$missingRejected = $false
try { Get-ApkSignerDigests @('signature verified') | Out-Null }
catch { $missingRejected = $true }
if (-not $missingRejected) { throw 'Missing signer digest was accepted.' }
Write-Output 'APK signer parsing tests passed.'
