param([switch]$SkipLockedFile)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$testRoot = Join-Path $root 'output/update-tests'
$installed = Join-Path $testRoot 'managed'
$source = Join-Path $root 'output/fixtures/0.3.1'
$base = Join-Path $root 'output/fixtures/0.3.0'
$config = Join-Path $testRoot 'source.json'
$dashboard = 'http://127.0.0.1:47654'
$evidence = [Collections.Generic.List[object]]::new()
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
function Save-Mode([string]$Mode) { [IO.File]::WriteAllText($config, (@{mode=$Mode} | ConvertTo-Json), [Text.UTF8Encoding]::new($false)) }
function Get-State { Invoke-RestMethod -Uri "$dashboard/api/updates" -TimeoutSec 2 }
function Action([string]$Name, [string]$Id) {
    $body = @{action=$Name}; if ($Id) { $body.candidateId=$Id }
    Invoke-RestMethod -Method Post -Uri "$dashboard/api/action" -Headers @{Origin=$dashboard} -ContentType application/json -Body ($body | ConvertTo-Json -Compress) -TimeoutSec 2 | Out-Null
}
function Wait-State([string]$State, [int]$Seconds = 30) {
    $end = [DateTime]::UtcNow.AddSeconds($Seconds)
    while ([DateTime]::UtcNow -lt $end) {
        try { $value = Get-State; if ($value.state -eq $State) { return $value } } catch { }
        Start-Sleep -Milliseconds 150
    }
    throw "Timed out waiting for $State."
}
function Servers {
    @(Get-CimInstance Win32_Process -Filter "Name='open_remote_control.exe'" | Where-Object {
        $_.ExecutablePath -and $_.ExecutablePath.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase) -and
        $_.CommandLine -notlike '*--orc-updater-worker*'
    })
}
function Stop-Host {
    foreach ($updater in @(Get-CimInstance Win32_Process -Filter "Name='Update.exe'" | Where-Object {
        $_.ExecutablePath -and $_.ExecutablePath.StartsWith($testRoot + '\', [StringComparison]::OrdinalIgnoreCase)
    })) { Stop-Process -Id $updater.ProcessId -Force; Wait-Process -Id $updater.ProcessId -Timeout 5 -ErrorAction SilentlyContinue }
    try { Action 'stop' } catch { }
    foreach ($process in (Servers)) { Stop-Process -Id $process.ProcessId -Force; Wait-Process -Id $process.ProcessId -Timeout 5 -ErrorAction SilentlyContinue }
    foreach ($worker in @(Get-CimInstance Win32_Process -Filter "Name='open_remote_control.exe'" | Where-Object {
        $_.ExecutablePath -and $_.ExecutablePath.StartsWith($testRoot + '\', [StringComparison]::OrdinalIgnoreCase) -and $_.CommandLine -like '*--orc-updater-worker*'
    })) { Stop-Process -Id $worker.ProcessId -Force -ErrorAction SilentlyContinue }
}
function Reset-Managed {
    Stop-Host
    # Use a fresh layout for each case; Windows/OneDrive can retain DLL handles
    # briefly after exit. No running or failed installation is overwritten.
    $script:installed = Join-Path $testRoot ('managed-' + [guid]::NewGuid().ToString('N'))
    Expand-Archive -LiteralPath (Join-Path $base 'OpenRemoteControl-Windows-x64.zip') -DestinationPath $installed
    New-Item -ItemType Directory -Path (Join-Path $installed 'packages') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $base 'org.openremotecontrol.windows-0.3.0-win-x64-full.nupkg') -Destination (Join-Path $installed 'packages')
}
function Start-Host {
    $env:ORC_UPDATER_TEST_SOURCE = 'http://127.0.0.1:48790'
    Start-Process -FilePath (Join-Path $installed 'Open Remote Control.exe') -WorkingDirectory $installed -WindowStyle Hidden
}
function Controls {
    $state = Invoke-RestMethod -Uri "$dashboard/api/status" -TimeoutSec 2
    if (-not $state.running) { throw 'Controls stopped during an update operation.' }
    $info = Invoke-RestMethod -Uri "http://$($state.addresses[0]):$($state.port)/info" -TimeoutSec 2
    return @{state=$state;info=$info}
}
function Record([string]$Case, [object]$Details) { $evidence.Add(@{case=$Case;passed=$true;details=$Details}); Write-Output "PASS $Case" }
Save-Mode 'normal'
$node = (Get-Command node).Source
$fixture = Start-Process -FilePath $node -ArgumentList @((Join-Path $PSScriptRoot 'update_fixture_server.mjs'), $source, $config) -WindowStyle Hidden -PassThru
try {
    $before = Controls
    [IO.File]::WriteAllText((Join-Path $testRoot 'identity-before.json'), ($before.info | ConvertTo-Json))
    Reset-Managed; $env:ORC_UPDATER_TEST_DELAY='2000'; Start-Host
    $checking = Wait-State 'checking'
    $responsive = Controls
    if ($responsive.info.serverId -ne $before.info.serverId) { throw 'Identity changed from the legacy bundle.' }
    Record 'responsive startup during delayed check' $checking.currentVersion
    $candidate = Wait-State 'available'; Action 'update_defer' $candidate.candidateId
    $deferred = Wait-State 'deferred'
    if (@(Get-ChildItem -LiteralPath (Join-Path $installed 'packages') -Filter '*0.3.1*').Count) { throw 'Deferral downloaded a package.' }
    Record 'deferral without download or restart' $deferred.state
    $env:ORC_UPDATER_TEST_DELAY=$null
    Action 'update_check'; $candidate = Wait-State 'available'
    if ($candidate.candidateId -eq $deferred.candidateId) { throw 'Candidate ID was reused.' }
    $env:ORC_UPDATER_TEST_DELAY=$null
    foreach ($case in @(@('offline','offline'),@('rateLimit','rate_limited'),@('invalid','invalid_metadata'),@('missingFeed','missing_asset'))) {
        Save-Mode $case[0]; Action 'update_check'; $failed = Wait-State 'failed'
        if ($failed.error.code -ne $case[1]) { throw "Unexpected error for $($case[0]): $($failed.error.code)" }
        Controls | Out-Null; Record $case[0] $failed.error.code
    }
    foreach ($case in @(@('corrupt','checksum'),@('truncated','checksum'),@('missingPackage','missing_asset'),@('space','insufficient_space'))) {
        Save-Mode $case[0]; Action 'update_check'; $candidate = Wait-State 'available'; Action 'update_install' $candidate.candidateId
        $failed = Wait-State 'failed'
        if ($failed.error.code -ne $case[1]) { throw "Unexpected error for $($case[0]): $($failed.error.code)" }
        Controls | Out-Null; Record $case[0] $failed.error.code
    }
    Save-Mode 'normal'; Action 'update_check'; $candidate = Wait-State 'available'
    $acl = Get-Acl -LiteralPath $installed
    $restricted = Get-Acl -LiteralPath $installed
    $rule = [Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.WindowsIdentity]::GetCurrent().User, 'Write', 'Deny')
    $restricted.AddAccessRule($rule)
    try {
        Set-Acl -LiteralPath $installed -AclObject $restricted
        Action 'update_install' $candidate.candidateId; $failed = Wait-State 'failed'
        if ($failed.error.code -ne 'unwritable_directory') { throw 'Write access was not validated.' }
        Controls | Out-Null; Record 'unwritable directory' $failed.error.code
    } finally { Set-Acl -LiteralPath $installed -AclObject $acl }

    Reset-Managed; Save-Mode 'normal'; $env:ORC_UPDATER_TEST_PREPARE_FAIL='1'; Start-Host
    $candidate=Wait-State 'available'; Action 'update_install' $candidate.candidateId; $failed=Wait-State 'failed'
    if ($failed.error.code -ne 'prepare_failed') { throw 'Preparation failure was not retained.' }
    Controls | Out-Null; Record 'updater preparation failure' $failed.error.code
    $env:ORC_UPDATER_TEST_PREPARE_FAIL=$null

    Reset-Managed; Save-Mode 'normal'; $env:ORC_UPDATER_TEST_TIMEOUT='1000'; $env:ORC_UPDATER_TEST_DELAY='2000'; Start-Host
    $failed=Wait-State 'failed'
    if ($failed.error.code -ne 'timeout') { throw 'Native worker timeout did not cancel the request.' }
    Controls | Out-Null; Record 'worker timeout' $failed.error.code
    $env:ORC_UPDATER_TEST_TIMEOUT=$null; $env:ORC_UPDATER_TEST_DELAY=$null

    if (-not $SkipLockedFile) {
        Reset-Managed; Save-Mode 'normal'; Start-Host; $candidate=Wait-State 'available'
        $lock = [IO.File]::Open((Join-Path $installed 'current/dartjni.dll'), 'Open', 'Read', 'Read')
        try {
            Action 'update_install' $candidate.candidateId
            Wait-State 'applying' | Out-Null
            $end = [DateTime]::UtcNow.AddSeconds(90)
            do {
                Start-Sleep -Milliseconds 200
                $updaters = @(Get-CimInstance Win32_Process -Filter "Name='Update.exe'" | Where-Object {
                    $_.ExecutablePath -and $_.ExecutablePath.StartsWith($installed + '\', [StringComparison]::OrdinalIgnoreCase)
                })
            } while ($updaters.Count -gt 0 -and [DateTime]::UtcNow -lt $end)
            if ($updaters.Count) { throw 'Locked-file updater did not finish.' }
        } finally { $lock.Dispose() }
        # Recovery uses the Velopack launcher and the untouched previous current directory.
        if (-not @(Servers).Count) { Start-Host }
        $candidate=Wait-State 'available'
        if ($candidate.currentVersion -ne '0.3.0') { throw 'Locked-file failure did not retain the previous version.' }
        Controls | Out-Null; Record 'locked-file recovery / cached package requires fresh approval' $candidate.currentVersion
    }

    Reset-Managed; Save-Mode 'slow'; Start-Host; $candidate=Wait-State 'available'
    Action 'update_install' $candidate.candidateId
    Wait-State 'downloading' | Out-Null; Controls | Out-Null
    Record 'responsive controls during download' $true
    Wait-State 'applying' | Out-Null
    $oldPackage=Join-Path $installed 'packages/org.openremotecontrol.windows-0.3.0-win-x64-full.nupkg'
    if (-not (Test-Path -LiteralPath $oldPackage)) { throw 'Previous full package deleted before restart.' }
    Record 'previous full package retained until restart' $true
    $target = Wait-State 'upToDate' 60
    if ($target.currentVersion -ne '0.3.1') { throw 'Updated version not active.' }
    $after = Controls
    if ($after.info.serverId -ne $before.info.serverId -or $after.info.signingPublicKey -ne $before.info.signingPublicKey) { throw 'Identity / public key changed.' }
    foreach ($client in $before.state.clients) {
        if ($after.state.clients.id -notcontains $client.id) { throw 'A paired phone was lost.' }
    }
    $hosts = @(Servers)
    if ($hosts.Count -ne 1 -or (Get-Process -Id $hosts[0].ProcessId).MainWindowHandle -ne 0) { throw 'Unexpected server process/window count.' }
    Record 'silent restart, one hidden server and identity / pairing continuity' @{version=$target.currentVersion;clients=@($after.state.clients).Count;processes=$hosts.Count}
    $diagnostics=Invoke-WebRequest -UseBasicParsing -Uri "$dashboard/api/diagnostics" -TimeoutSec 3
    if (-not $diagnostics.Content.Contains('[WindowsUpdater]')) { throw 'Updater diagnostics missing from export.' }
    Record 'native update diagnostics exported' $true
} finally {
    $env:ORC_UPDATER_TEST_SOURCE=$null; $env:ORC_UPDATER_TEST_DELAY=$null; $env:ORC_UPDATER_TEST_TIMEOUT=$null; $env:ORC_UPDATER_TEST_PREPARE_FAIL=$null
    Stop-Process -Id $fixture.Id -Force -ErrorAction SilentlyContinue
    [IO.File]::WriteAllText((Join-Path $testRoot 'evidence.json'), ($evidence | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
}
