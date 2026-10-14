param(
  [string]$Device='emulator-5554',
  [string]$FlutterExecutable='C:\Users\Sergio\develop\flutter\bin\flutter.bat',
  [string]$PythonExecutable='C:\Users\Sergio\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe',
  [string]$AdbExecutable='C:\Users\Sergio\AppData\Local\Android\Sdk\platform-tools\adb.exe'
)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$evidence=Join-Path $root 'docs/reports/phase07/evidence'
$raw=Join-Path $root '.tooling/phase07-native-private.txt'
$helper=$null
$priorPath=$env:Path
$night=$null
$result=$null
Push-Location $root
try {
  [System.IO.File]::WriteAllText($raw,'')
  [System.IO.File]::WriteAllText((Join-Path $root '.tooling/phase07-capture-helper.txt'),'')
  [System.IO.File]::WriteAllText((Join-Path $root '.tooling/phase07-capture-errors.txt'),'')
  New-Item -ItemType Directory -Force $evidence | Out-Null
  & (Join-Path $PSScriptRoot 'assert_local_isolation.ps1') -EvidenceDirectory $evidence
  $local=& .tooling/supabase/supabase.exe status -o json | ConvertFrom-Json
  if($local.API_URL -ne 'http://127.0.0.1:54321'){throw 'Only isolated local endpoint allowed'}
  @{SUPABASE_URL='http://10.0.2.2:54321';SUPABASE_PUBLISHABLE_KEY=$local.ANON_KEY;MIXTICK_ALLOW_LOCAL_BACKEND=$true} | ConvertTo-Json | Set-Content .tooling/phase07-android.local.json
  $env:Path=(Split-Path -Parent $FlutterExecutable)+';'+$env:Path
  $night=((& $AdbExecutable -s $Device shell cmd uimode night)-join '').Replace('Night mode:','').Trim()
  if($night -notin @('yes','no','auto','custom')){throw 'Unrecognized prior emulator night mode'}
  & $AdbExecutable -s $Device shell cmd uimode night no *> .tooling/phase07-night-mode.txt
  & $AdbExecutable -s $Device shell am force-stop es.sergiotech.mixtick
  [System.IO.File]::WriteAllText($raw,'')
  $helperArgs=@(('"'+(Join-Path $PSScriptRoot 'capture_shopping_android.py')+'"'),'--adb',('"'+$AdbExecutable+'"'),'--device',$Device,'--log',('"'+$raw+'"'))
  $helper=Start-Process -FilePath $PythonExecutable -ArgumentList $helperArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput .tooling/phase07-capture-helper.txt -RedirectStandardError .tooling/phase07-capture-errors.txt
  $arguments=@('test','integration_test/shopping_native_test.dart','-d',$Device,'--no-uninstall','--dart-define-from-file=.tooling/phase07-android.local.json','--reporter','expanded')
  $started=[DateTimeOffset]::Now.ToString('o')
  & $FlutterExecutable @arguments *> $raw
  $code=$LASTEXITCODE
  $result=[pscustomobject]@{name='native-shopping';executable=$FlutterExecutable;arguments=$arguments;started_at=$started;exit_code=$code;status=$(if($code -eq 0){'PASS'}else{'FAIL'})}
  if(-not $helper.WaitForExit(15000)){Stop-Process -Id $helper.Id -Force;throw 'Capture companion did not finish'}
  if($code -ne 0 -or $helper.ExitCode -ne 0){throw 'Native shopping/capture failed; inspect redacted evidence'}
  Write-Output 'PASS: real Android shopping integration and light/dark/selection captures'
} finally {
  if($helper -and -not $helper.HasExited){Stop-Process -Id $helper.Id -Force}
  if(Test-Path $raw){
    $text=Get-Content $raw -Raw
    $owned=@([regex]::Matches($text,'P7_FIXTURE:(\{[^\r\n]+\})') | ForEach-Object {$_.Groups[1].Value | ConvertFrom-Json})
    @{users=$owned;photos=@();avatars=@()} | ConvertTo-Json -Depth 4 | Set-Content .tooling/phase07-native-fixtures.json
    Get-Content $raw | ForEach-Object {
      $line=[string]$_ -replace 'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+','[TOKEN REDACTED]'
      $line=$line -replace 'P7_FIXTURE:\{[^\r\n]+\}','P7_FIXTURE:[recorded locally for cleanup]'
      $line -replace '([?&](code|token|token_hash)=)[^\s&"<>]+','$1[REDACTED]'
    } | Set-Content (Join-Path $evidence 'native-shopping.txt')
    & $PythonExecutable scripts/cleanup_shopping_fixtures.py --fixtures .tooling/phase07-native-fixtures.json *> (Join-Path $evidence 'native-fixture-cleanup.txt')
    if($LASTEXITCODE -ne 0){Write-Error 'Native fixture cleanup failed'}
  }
  if(Test-Path .tooling/phase07-capture-helper.txt){Get-Content .tooling/phase07-capture-helper.txt | Set-Content (Join-Path $evidence 'native-captures.txt')}
  if(Test-Path .tooling/phase07-capture-errors.txt){Get-Content .tooling/phase07-capture-errors.txt | Set-Content (Join-Path $evidence 'native-capture-errors.txt')}
  if($night -in @('yes','no','auto','custom')){& $AdbExecutable -s $Device shell cmd uimode night $night *> .tooling/phase07-night-restore.txt}
  if($result){$result | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $evidence 'native-results.json')}
  $env:Path=$priorPath
  Pop-Location
}
