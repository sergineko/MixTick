param([string]$AdbExecutable='C:\Users\Sergio\AppData\Local\Android\Sdk\platform-tools\adb.exe')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
  $databaseRunning=@(docker ps -q --filter name=supabase_db_mixtick-phase02)
  if($databaseRunning.Count -gt 0){
    $remaining=docker exec supabase_db_mixtick-phase02 psql -U postgres -d postgres -Atq -c 'select (select count(*) from auth.users)+(select count(*) from storage.objects)+(select count(*) from private.storage_cleanup_jobs)+(select count(*) from private.account_deletions);'
    if($LASTEXITCODE -ne 0 -or $remaining -ne '0'){throw 'Refuse final stop with unresolved fixtures/jobs'}
  } else {
    $audit=Get-Content docs/reports/phase08/evidence/all-fixtures-audit-final.json -Raw | ConvertFrom-Json
    if($audit.auth_users -ne 0 -or $audit.cleanup_jobs -ne 0 -or $audit.recipe_photos -ne 0 -or $audit.avatars -ne 0){throw 'No clean final audit for already stopped project'}
  }
  $expectedEnv=(Join-Path $root '.tooling/phase08-functions.env').Replace('/','\')
  $owned=@(Get-CimInstance Win32_Process | Where-Object {
    $_.Name -eq 'supabase.exe' -and $_.CommandLine -match 'functions serve' -and
    $_.CommandLine.Replace('/','\').IndexOf($expectedEnv,[StringComparison]::OrdinalIgnoreCase) -ge 0
  })
  foreach($process in $owned){Stop-Process -Id $process.ProcessId -Force}
  & .tooling/supabase/supabase.exe stop --project-id mixtick-phase02 *> .tooling/phase08-final-stop.txt
  if($LASTEXITCODE -ne 0){throw 'Project stop failed'}
  $metadata=Get-Content .tooling/phase08-emulator.json -Raw | ConvertFrom-Json
  if($metadata.avd -ne 'Pixel_10a'){throw 'Unexpected emulator ownership metadata'}
  $actual=((& $AdbExecutable -s emulator-5554 emu avd name)-join ' ').Trim()
  if($LASTEXITCODE -ne 0 -or $actual -notmatch '^Pixel_10a\s+OK$'){throw 'Emulator identity mismatch'}
  $launched=[DateTime]$metadata.started
  $emulatorProcesses=@(Get-CimInstance Win32_Process | Where-Object {
    $_.Name -match '^(emulator|qemu-system-x86_64)\.exe$' -and
    $_.CommandLine -match '(?:-avd\s+|@)Pixel_10a(?:\s|$)' -and
    $_.CreationDate -ge $launched.AddSeconds(-2)
  })
  if($emulatorProcesses.Count -eq 0){throw 'No matching owned emulator process'}
  $night=((& $AdbExecutable -s emulator-5554 shell cmd uimode night)-join '').Trim()
  & $AdbExecutable -s emulator-5554 emu kill *> .tooling/phase08-emulator-stop.txt
  if($LASTEXITCODE -ne 0){throw 'Owned emulator stop failed'}
  $listeners=@(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object {$_.LocalPort -ge 54321 -and $_.LocalPort -le 54329})
  $containers=@(docker ps -q --filter name=mixtick-phase02)
  $result=@{status='PASS';project='mixtick-phase02';running_project_containers=$containers.Count;project_port_listeners=$listeners.Count;owned_function_processes_stopped=$owned.Count;owned_emulator='Pixel_10a';emulator_stop_exit=0;night_mode_before_stop=$night;docker_global_stopped=$false}
  if($containers.Count -ne 0 -or $listeners.Count -ne 0){$result.status='FAIL'}
  $result | ConvertTo-Json | Set-Content docs/reports/phase08/evidence/local-stop-final.json
  if($result.status -ne 'PASS'){throw 'Project listeners/containers remain'}
  Write-Output 'PASS: owned stack/functions/emulator stopped; no project ports; Docker global preserved'
} finally {Pop-Location}
