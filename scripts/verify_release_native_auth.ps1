param(
    [string]$Device = 'emulator-5554',
    [string]$FlutterExecutable = 'C:\Users\Sergio\develop\flutter\bin\flutter.bat',
    [string]$PythonExecutable = 'C:\Users\Sergio\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe',
    [string]$AdbExecutable = 'C:\Users\Sergio\AppData\Local\Android\Sdk\platform-tools\adb.exe'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$evidence = Join-Path $root 'docs/reports/phase08/auth-regression/evidence'
$results = [System.Collections.Generic.List[object]]::new()
$ownedIds = [System.Collections.Generic.HashSet[string]]::new()
$delivery = $null
$priorPath = $env:Path
$env:Path=(Split-Path -Parent $FlutterExecutable)+';'+$env:Path
$env:DO_NOT_TRACK='1'
$env:CI='true'
function Redact([string]$line) {
    $line = $line -replace 'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+','[TOKEN REDACTED]'
    $line = $line -replace 'MIXTICK_FIXTURE_ID:[0-9a-f-]{36}','MIXTICK_FIXTURE_ID:[recorded locally for cleanup]'
    $line = $line -replace 'MIXTICK_RECOVERY_READY:mixtick-native-[0-9a-f]+@example\.test','MIXTICK_RECOVERY_READY:[local fixture]'
    $line -replace '([?&](code|token|token_hash)=)[^\s&"<>]+','$1[REDACTED]'
}
function Native-Test([string]$name,[string]$target) {
    $raw = Join-Path $root ".tooling/$name-private.txt"
    $testArguments = @('test',$target,'-d',$Device,'--no-uninstall','--dart-define-from-file=.tooling/phase08-auth-android.local.json','--reporter','expanded')
    $started=[DateTimeOffset]::Now.ToString('o')
    & $FlutterExecutable @testArguments *> $raw
    $code=$LASTEXITCODE
    $text=Get-Content $raw -Raw
    foreach ($match in [regex]::Matches($text,'MIXTICK_FIXTURE_ID:([0-9a-f-]{36})')) { [void]$ownedIds.Add($match.Groups[1].Value) }
    Get-Content $raw | ForEach-Object { Redact ([string]$_) } | Set-Content (Join-Path $evidence "$name.txt")
    $results.Add([PSCustomObject]@{name=$name; executable=$FlutterExecutable;arguments=$testArguments;started_at=$started;exit_code=$code;status=$(if($code -eq 0){'PASS'}else{'FAIL'})})
    Write-Output "$name : exit=$code"
    if ($code -ne 0) { throw "Native test failed: $name" }
}
Push-Location $root
try {
    & (Join-Path $PSScriptRoot 'assert_local_isolation.ps1') -EvidenceDirectory $evidence
    $config=Get-Content supabase/config.toml -Raw
    if ($config -notmatch '(?s)\[auth\.email\].*?enable_confirmations\s*=\s*false') { throw 'Native UI seed requires local auto-confirm mode; email-confirm mode is tested separately' }
    $local = & .tooling/supabase/supabase.exe status -o json | ConvertFrom-Json
    @{SUPABASE_URL='http://10.0.2.2:54321';SUPABASE_PUBLISHABLE_KEY=$local.ANON_KEY;MIXTICK_ALLOW_LOCAL_BACKEND=$true} | ConvertTo-Json | Set-Content .tooling/phase08-auth-android.local.json
    Native-Test 'native-seed' 'integration_test/auth_native_seed_test.dart'
    $files=& $AdbExecutable -s $Device shell run-as es.sergiotech.mixtick ls shared_prefs
    $secureFile=$files | Where-Object { $_ -match 'FlutterSecureStorage.*\.xml' } | Select-Object -First 1
    if (-not $secureFile) { throw 'Native secure storage missing' }
    $contents=(& $AdbExecutable -s $Device shell run-as es.sergiotech.mixtick cat "shared_prefs/$secureFile") -join "`n"
    if ($contents -match 'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+|mixtick-native-|"access_token"|"refresh_token"') { throw 'Plaintext session in native secure file' }
    'PASS: native preferences contain encrypted values; no plaintext fixture email/JWT/session JSON; raw file not retained' | Set-Content (Join-Path $evidence 'native-encrypted-storage.txt')
    # Helper waits for the marker of this exact native test, then delivers a
    # real email callback. Its stdout does not contain URI/code/token values.
    $restoreLog=Join-Path $root '.tooling/native-restore-private.txt'
    [System.IO.File]::WriteAllText($restoreLog,'')
    $helperArgs=@(('"'+(Join-Path $PSScriptRoot 'deliver_native_recovery.py')+'"'),'--log',('"'+$restoreLog+'"'),'--adb',('"'+$AdbExecutable+'"'),'--device',$Device)
    $delivery=Start-Process -FilePath $PythonExecutable -ArgumentList $helperArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $root '.tooling/native-delivery.txt') -RedirectStandardError (Join-Path $root '.tooling/native-delivery-errors.txt')
    Native-Test 'native-restore' 'integration_test/auth_native_restore_test.dart'
    $delivery.WaitForExit()
    if ($delivery.ExitCode -ne 0) { throw 'Native callback delivery failed' }
    Get-Content .tooling/native-delivery.txt | Set-Content (Join-Path $evidence 'native-callback-delivery.txt')
} finally {
    if ($delivery -and -not $delivery.HasExited) { Stop-Process -Id $delivery.Id -Force }
    if ($ownedIds.Count -gt 0) {
        foreach ($id in $ownedIds) { if ($id -notmatch '^[0-9a-f-]{36}$') { throw 'Invalid owned fixture UUID' } }
        $sqlIds=($ownedIds | ForEach-Object { "'$_'::uuid" }) -join ','
        $cleanup="DELETE FROM auth.users WHERE id IN ($sqlIds); SELECT count(*) FROM auth.users WHERE id IN ($sqlIds);"
        $cleanup | docker exec -i supabase_db_mixtick-phase02 psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 | Set-Content (Join-Path $evidence 'native-fixture-cleanup.txt')
    }
    $results | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $evidence 'native-results.json')
    $env:Path=$priorPath
    Pop-Location
}
