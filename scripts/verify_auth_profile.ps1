param(
    [string]$FlutterExecutable = 'C:\Users\Sergio\develop\flutter\bin\flutter.bat',
    [string]$DartExecutable = 'C:\Users\Sergio\develop\flutter\bin\dart.bat',
    [string]$PythonExecutable = 'C:\Users\Sergio\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe',
    [string]$SupabaseExecutable = '',
    [switch]$BackendChecks,
    [switch]$ResetLocal,
    [switch]$IncludeAndroidBuild
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$evidence = Join-Path $root 'docs/reports/phase03/evidence'
New-Item -ItemType Directory -Force -Path $evidence | Out-Null
$results = [System.Collections.Generic.List[object]]::new()
$originalPath = $env:Path
$originalConfig = Get-Content (Join-Path $root 'supabase/config.toml') -Raw
$localStarted = $false
if (-not $SupabaseExecutable) { $SupabaseExecutable = Join-Path $root '.tooling/supabase/supabase.exe' }
$env:Path = (Split-Path -Parent $FlutterExecutable) + ';' + $env:Path
$env:DO_NOT_TRACK = '1'
$env:CI = 'true'
function Protect-Output([string]$line) {
    $line = $line -replace 'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+','[TOKEN REDACTED]'
    $line = $line -replace 'sb_(secret|publishable)_[A-Za-z0-9_-]+','[LOCAL KEY REDACTED]'
    $line -replace '([?&](code|token|token_hash)=)[^\s&"<>]+','$1[REDACTED]'
}
function Check([string]$name,[string]$executable,[string[]]$arguments) {
    $started = [DateTimeOffset]::Now.ToString('o')
    try {
        & $executable @arguments 2>&1 | ForEach-Object { Protect-Output ([string]$_) } | Set-Content (Join-Path $evidence "$name.txt")
        $code = $LASTEXITCODE
        $status = if ($code -eq 0) { 'PASS' } else { 'FAIL' }
        if ($name -eq 'db-lint' -and $code -eq 0 -and (Get-Content (Join-Path $evidence "$name.txt") -Raw) -notmatch '"results"\s*:\s*\[\s*\]') { $status = 'FAIL' }
    } catch { $code=$null; $status='NOT_RUN'; $_.Exception.Message | Set-Content (Join-Path $evidence "$name.txt") }
    $results.Add([PSCustomObject]@{name=$name; executable=$executable; arguments=$arguments; started_at=$started; exit_code=$code; status=$status})
    Write-Output "$name : $status (exit=$code)"
    if ($status -ne 'PASS') { throw "Check failed: $name" }
}
function Set-Confirmation([bool]$enabled) {
    $value = if ($enabled) { 'true' } else { 'false' }
    $pattern = [regex]::new('(?s)(\[auth\.email\].*?enable_confirmations\s*=\s*)(true|false)')
    if (-not $pattern.IsMatch($originalConfig)) { throw 'Email confirmation setting missing' }
    $config = $pattern.Replace($originalConfig, '${1}'+$value, 1)
    [System.IO.File]::WriteAllText((Join-Path $root 'supabase/config.toml'),$config)
}
function Start-Local {
    $script:localStarted = $true
    & (Join-Path $PSScriptRoot 'start_isolated_supabase.ps1') -DartExecutable $DartExecutable -SupabaseExecutable $SupabaseExecutable -EvidenceDirectory $evidence
    & (Join-Path $PSScriptRoot 'assert_local_isolation.ps1') -EvidenceDirectory $evidence
    $script:networkId = docker network inspect mixtick-local-tests --format '{{.Id}}'
    $local = & $SupabaseExecutable status -o json | ConvertFrom-Json
    # Public client config only. Raw status (which includes admin keys) is not saved.
    @{SUPABASE_URL='http://127.0.0.1:54321';SUPABASE_PUBLISHABLE_KEY=$local.ANON_KEY;MIXTICK_ALLOW_LOCAL_BACKEND=$true} |
        ConvertTo-Json | Set-Content (Join-Path $root '.tooling/phase03-client.local.json')
}
function Stop-Local {
    & $SupabaseExecutable stop --project-id mixtick-phase02 *> (Join-Path $root '.tooling/phase03-runner-stop-private.txt')
    if ($LASTEXITCODE -ne 0) { throw 'Local stack stop failed' }
    $script:localStarted = $false
}
Push-Location $root
try {
    if ($originalConfig -notmatch '(?m)^project_id\s*=\s*"mixtick-phase02"\s*$') { throw 'Unexpected fixture project' }
    if ($BackendChecks) {
        if (docker ps -q --filter name=mixtick-phase02) { Stop-Local }
        Set-Confirmation $false
        Start-Local
        if ($ResetLocal) {
            $adapterPath = Join-Path $root '.tooling/loopback-docker'
            $beforeResetPath=$env:Path
            $env:Path=$adapterPath+';'+$env:Path
            try { Check 'db-reset' $SupabaseExecutable @('db','reset','--local','--network-id',$networkId) }
            finally { $env:Path=$beforeResetPath }
            & (Join-Path $PSScriptRoot 'assert_local_isolation.ps1') -EvidenceDirectory $evidence
        } else { Check 'migration-up' $SupabaseExecutable @('migration','up','--local','--network-id',$networkId) }
        Check 'sql-tests' $SupabaseExecutable @('test','db','--network-id',$networkId)
        Check 'db-lint' $SupabaseExecutable @('db','lint','--local','--level','warning','--network-id',$networkId)
        Check 'api-regression' $PythonExecutable @('scripts/test_database_api.py','--cli',$SupabaseExecutable,'--evidence-dir',(Join-Path $evidence 'regression-db'))
        Check 'auth-local-auto-confirm' $FlutterExecutable @('test','test_support/auth_profile_local.dart','--dart-define-from-file=.tooling/phase03-client.local.json','--reporter','expanded')
        Stop-Local
        Set-Confirmation $true
        Start-Local
        Check 'auth-local-email-confirm' $FlutterExecutable @('test','test_support/auth_profile_local.dart','--dart-define-from-file=.tooling/phase03-client.local.json','--dart-define=MIXTICK_TEST_CONFIRMATION=true','--reporter','expanded')
        Stop-Local
    }
    Check 'gen-l10n' $FlutterExecutable @('gen-l10n')
    Check 'flutter-analyze' $FlutterExecutable @('analyze')
    Check 'flutter-test' $FlutterExecutable @('test','--reporter','expanded')
    Check 'format-check' $DartExecutable @('format','--output=none','--set-exit-if-changed','lib','test','test_support','integration_test','scripts/loopback_docker.dart')
    Check 'identifiers' $PythonExecutable @('scripts/check_identifiers.py','--strict')
    if ($IncludeAndroidBuild) { Check 'android-debug-build' $FlutterExecutable @('build','apk','--debug') }
} finally {
    if ($localStarted) { Stop-Local }
    [System.IO.File]::WriteAllText((Join-Path $root 'supabase/config.toml'),$originalConfig)
    $env:Path=$originalPath
    $results | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $evidence 'results.json')
    Pop-Location
}
