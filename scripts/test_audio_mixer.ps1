$ErrorActionPreference = 'Stop'
$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$serverDirectory = Join-Path $workspaceRoot 'web\server'
$buildDirectory = Join-Path $serverDirectory 'build\windows\x64'

Push-Location $serverDirectory
try {
    & flutter build windows --debug
    if ($LASTEXITCODE -ne 0) { throw 'Windows debug build failed.' }
}
finally {
    Pop-Location
}

$cmake = Get-Command cmake -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source
if (-not $cmake) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    $vsPath = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    $cmake = Join-Path $vsPath 'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
}
if (-not (Test-Path -LiteralPath $cmake)) { throw 'CMake was not found.' }
& $cmake --build $buildDirectory --config Debug --target audio_mixer_test
if ($LASTEXITCODE -ne 0) { throw 'Native audio mixer test build failed.' }

$library = Join-Path $buildDirectory 'audio-mixer-tests\Debug\audio_mixer_test.dll'
$escapedLibrary = $library.Replace('\', '\\')
$source = @"
using System;
using System.Runtime.InteropServices;
public static class AudioMixerNativeTest {
    [DllImport("$escapedLibrary", CallingConvention = CallingConvention.Cdecl)]
    public static extern int TestMixer();
    [DllImport("$escapedLibrary", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr MixerFailure();
}
"@
Add-Type -TypeDefinition $source
if ([AudioMixerNativeTest]::TestMixer() -ne 1) {
    throw [Runtime.InteropServices.Marshal]::PtrToStringAnsi([AudioMixerNativeTest]::MixerFailure())
}
Write-Output 'Audio mixer integration test passed.'
