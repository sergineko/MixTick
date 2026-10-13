param(
  [string]$FlutterExecutable='C:\Users\Sergio\develop\flutter\bin\flutter.bat',
  [string]$DartExecutable='C:\Users\Sergio\develop\flutter\bin\dart.bat',
  [string]$PythonExecutable='C:\Users\Sergio\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe',
  [string]$SupabaseExecutable='',
  [switch]$BackendChecks,
  [switch]$ResetLocal,
  [switch]$IncludeAndroidBuild
)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$evidence=Join-Path $root 'docs/reports/phase04/evidence'
New-Item -ItemType Directory -Force $evidence | Out-Null
$results=[System.Collections.Generic.List[object]]::new()
$originalPath=$env:Path
$originalConfig=Get-Content (Join-Path $root 'supabase/config.toml') -Raw
$startedLocal=$false
if(-not $SupabaseExecutable){$SupabaseExecutable=Join-Path $root '.tooling/supabase/supabase.exe'}
$env:Path=(Split-Path -Parent $FlutterExecutable)+';'+$env:Path
$env:DO_NOT_TRACK='1'
$env:CI='true'
function Protect-Output([string]$line){
  $line=$line -replace 'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+','[TOKEN REDACTED]'
  $line=$line -replace 'sb_(secret|publishable)_[A-Za-z0-9_-]+','[LOCAL KEY REDACTED]'
  $line -replace '([?&](code|token|token_hash)=)[^\s&"<>]+','$1[REDACTED]'
}
function Check([string]$name,[string]$executable,[string[]]$arguments){
  $when=[DateTimeOffset]::Now.ToString('o')
  try {
    & $executable @arguments 2>&1 | ForEach-Object {Protect-Output ([string]$_)} | Set-Content (Join-Path $evidence "$name.txt")
    $code=$LASTEXITCODE
    $status=if($code -eq 0){'PASS'}else{'FAIL'}
    if($name -eq 'db-lint' -and $code -eq 0 -and (Get-Content (Join-Path $evidence "$name.txt") -Raw) -notmatch '"results"\s*:\s*\[\s*\]'){$status='FAIL'}
  } catch {$code=$null;$status='NOT_RUN';$_.Exception.Message | Set-Content (Join-Path $evidence "$name.txt")}
  $results.Add([pscustomobject]@{name=$name;executable=$executable;arguments=$arguments;started_at=$when;exit_code=$code;status=$status})
  Write-Output "$name : $status (exit=$code)"
  if($status -ne 'PASS'){throw "Check failed: $name"}
}
function Write-PublicConfig {
  $local=& $SupabaseExecutable status -o json | ConvertFrom-Json
  if($local.API_URL.TrimEnd('/') -ne 'http://127.0.0.1:54321'){throw 'Only isolated local endpoint is permitted'}
  @{SUPABASE_URL='http://127.0.0.1:54321';SUPABASE_PUBLISHABLE_KEY=$local.ANON_KEY;MIXTICK_ALLOW_LOCAL_BACKEND=$true} | ConvertTo-Json | Set-Content .tooling/phase04-client.local.json
}
function Start-Local {
  $script:startedLocal=$true
  & (Join-Path $PSScriptRoot 'start_isolated_supabase.ps1') -DartExecutable $DartExecutable -SupabaseExecutable $SupabaseExecutable -EvidenceDirectory $evidence
  & (Join-Path $PSScriptRoot 'assert_local_isolation.ps1') -EvidenceDirectory $evidence
  Write-PublicConfig
  $script:network=docker network inspect mixtick-local-tests --format '{{.Id}}'
}
function Stop-Local {
  & $SupabaseExecutable stop --project-id mixtick-phase02 *> .tooling/phase04-stop-private.txt
  if($LASTEXITCODE -ne 0){throw 'Local stop failed'}
  $script:startedLocal=$false
}
function Set-Confirmation([bool]$enabled){
  $value=if($enabled){'true'}else{'false'}
  $pattern=[regex]::new('(?s)(\[auth\.email\].*?enable_confirmations\s*=\s*)(true|false)')
  if(-not $pattern.IsMatch($originalConfig)){throw 'Confirmation setting missing'}
  [System.IO.File]::WriteAllText((Join-Path $root 'supabase/config.toml'),$pattern.Replace($originalConfig,'${1}'+$value,1))
}
Push-Location $root
try {
  if($originalConfig -notmatch '(?m)^project_id\s*=\s*"mixtick-phase02"\s*$'){throw 'Unexpected fixture project'}
  if($BackendChecks){
    if(docker ps -q --filter name=mixtick-phase02){
      $startedLocal=$true
      & (Join-Path $PSScriptRoot 'assert_local_isolation.ps1') -EvidenceDirectory $evidence
      Write-PublicConfig
      $network=docker network inspect mixtick-local-tests --format '{{.Id}}'
    } else {Set-Confirmation $false;Start-Local}
    if($ResetLocal){
      $accounts=docker exec supabase_db_mixtick-phase02 psql -U postgres -d postgres -At -c 'select count(*) from auth.users;'
      if($LASTEXITCODE -ne 0 -or $accounts -ne '0'){throw 'Reset refused: local project contains accounts'}
      $beforeReset=$env:Path
      $env:Path=(Join-Path $root '.tooling/loopback-docker')+';'+$env:Path
      try{Check 'db-reset' $SupabaseExecutable @('db','reset','--local','--network-id',$network)}finally{$env:Path=$beforeReset}
      & (Join-Path $PSScriptRoot 'assert_local_isolation.ps1') -EvidenceDirectory $evidence
    }
    Check 'sql-tests' $SupabaseExecutable @('test','db','--network-id',$network)
    Check 'db-lint' $SupabaseExecutable @('db','lint','--local','--level','warning','--network-id',$network)
    Check 'api-regression' $PythonExecutable @('scripts/test_database_api.py','--cli',$SupabaseExecutable,'--evidence-dir',(Join-Path $evidence 'regression-db'))
    try{Check 'recipes-real-client' $FlutterExecutable @('test','test_support/recipes_local.dart','--dart-define-from-file=.tooling/phase04-client.local.json','--reporter','expanded')}
    finally{Check 'client-fixture-cleanup' $PythonExecutable @('scripts/cleanup_recipe_fixtures.py')}
    Check 'auth-regression-auto-confirm' $FlutterExecutable @('test','test_support/auth_profile_local.dart','--dart-define-from-file=.tooling/phase04-client.local.json','--reporter','expanded')
    Stop-Local
    Set-Confirmation $true
    Start-Local
    Check 'auth-regression-email-confirm' $FlutterExecutable @('test','test_support/auth_profile_local.dart','--dart-define-from-file=.tooling/phase04-client.local.json','--dart-define=MIXTICK_TEST_CONFIRMATION=true','--reporter','expanded')
    Stop-Local
  }
  Check 'gen-l10n' $FlutterExecutable @('gen-l10n')
  Check 'flutter-analyze' $FlutterExecutable @('analyze')
  Check 'flutter-test' $FlutterExecutable @('test','--reporter','expanded')
  Check 'format-check' $DartExecutable @('format','--output=none','--set-exit-if-changed','lib','test','test_support','integration_test','scripts/loopback_docker.dart')
  Check 'identifiers' $PythonExecutable @('scripts/check_identifiers.py','--strict')
  if($IncludeAndroidBuild){Check 'android-debug-build' $FlutterExecutable @('build','apk','--debug')}
} finally {
  if($startedLocal){Stop-Local}
  [System.IO.File]::WriteAllText((Join-Path $root 'supabase/config.toml'),$originalConfig)
  $env:Path=$originalPath
  $results | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $evidence 'results.json')
  Pop-Location
}
