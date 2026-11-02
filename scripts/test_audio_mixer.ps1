param(
    [switch]$Fixture,
    [string]$Library,
    [string]$SessionName,
    [string]$ReadyEventName,
    [string]$StopEventName,
    [string]$DoneEventName
)
$ErrorActionPreference = 'Stop'
if ($Fixture) {
    $fixtureLibrary = $Library.Replace('\', '\\')
    $fixtureSource = @"
using System.Runtime.InteropServices;
public static class AudioMixerFixtureRunner {
    [DllImport("$fixtureLibrary", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
    public static extern int AudioMixerFixture(string sessionName, string ready, string stop, string done);
}
"@
    Add-Type -TypeDefinition $fixtureSource
    if ([AudioMixerFixtureRunner]::AudioMixerFixture($SessionName, $ReadyEventName, $StopEventName, $DoneEventName) -ne 1) { exit 1 }
    exit 0
}

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
    [DllImport("$escapedLibrary", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
    public static extern int TestMixerAcrossProcesses(string sessionName, string stop, string done);
}
"@
Add-Type -TypeDefinition $source
if ([AudioMixerNativeTest]::TestMixer() -ne 1) {
    throw [Runtime.InteropServices.Marshal]::PtrToStringAnsi([AudioMixerNativeTest]::MixerFailure())
}
$testId = [guid]::NewGuid().ToString('N')
$sessionName = "ORC_Audio_Test_$testId"
$readyName = "Local\ORC_Audio_Ready_$testId"
$stopName = "Local\ORC_Audio_Stop_$testId"
$doneName = "Local\ORC_Audio_Done_$testId"
$resetMode = [System.Threading.EventResetMode]::ManualReset
$readyEvent = [System.Threading.EventWaitHandle]::new($false, $resetMode, $readyName)
$stopEvent = [System.Threading.EventWaitHandle]::new($false, $resetMode, $stopName)
$doneEvent = [System.Threading.EventWaitHandle]::new($false, $resetMode, $doneName)
$fixtureProcess = $null
try {
    $powerShellPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $fixtureArguments = @(
        '-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
        '-File', "`"$PSCommandPath`"", '-Fixture', '-Library', "`"$library`"",
        '-SessionName', $sessionName, '-ReadyEventName', $readyName,
        '-StopEventName', $stopName, '-DoneEventName', $doneName
    )
    $fixtureProcess = Start-Process -FilePath $powerShellPath -ArgumentList $fixtureArguments -WindowStyle Hidden -PassThru
    if (-not $readyEvent.WaitOne(15000)) { throw 'External audio fixture did not start.' }
    if ([AudioMixerNativeTest]::TestMixerAcrossProcesses($sessionName, $stopName, $doneName) -ne 1) {
        throw [Runtime.InteropServices.Marshal]::PtrToStringAnsi([AudioMixerNativeTest]::MixerFailure())
    }
    if (-not $fixtureProcess.WaitForExit(10000) -or $fixtureProcess.ExitCode -ne 0) {
        throw 'External audio fixture did not exit cleanly.'
    }
}
finally {
    $stopEvent.Set() | Out-Null
    if ($fixtureProcess -and -not $fixtureProcess.HasExited -and -not $fixtureProcess.WaitForExit(10000)) {
        Stop-Process -Id $fixtureProcess.Id -Force
    }
    $readyEvent.Dispose()
    $stopEvent.Dispose()
    $doneEvent.Dispose()
}
Write-Output 'Audio mixer integration test passed.'
