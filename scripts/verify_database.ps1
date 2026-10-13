param(
    [string]$SupabaseExecutable = '',
    [string]$PythonExecutable = 'python',
    [string]$FlutterExecutable = 'flutter',
    [string]$DartExecutable = 'dart',
    [switch]$BackendOnly,
    [switch]$KeepLocalRunning,
    [switch]$StartLocal,
    [switch]$ResetLocal
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$evidenceDirectory = Join-Path $projectRoot 'docs/reports/phase02/evidence'
New-Item -ItemType Directory -Path $evidenceDirectory -Force | Out-Null
$results = [System.Collections.Generic.List[object]]::new()
$env:DO_NOT_TRACK = '1'
$env:CI = 'true'
$startedHere = $false
if (-not $SupabaseExecutable) {
    $portableCli = Join-Path $projectRoot '.tooling/supabase/supabase.exe'
    $SupabaseExecutable = if (Test-Path -LiteralPath $portableCli) { $portableCli } else { 'supabase' }
}
if (Test-Path -LiteralPath $FlutterExecutable) {
    $env:Path = (Split-Path -Parent $FlutterExecutable) + ';' + $env:Path
}

function Remove-LocalSecrets {
    param([string]$Line)
    # CLI status/start also return privileged LOCAL setup keys. Never save them.
    $Line = $Line -replace '"(?:JWT_SECRET|SERVICE_ROLE_KEY|SECRET_KEY|ANON_KEY|PUBLISHABLE_KEY|S3_PROTOCOL_ACCESS_KEY_ID|S3_PROTOCOL_ACCESS_KEY_SECRET|DB_URL)"\s*:\s*"[^"]*"', '"LOCAL_CONFIG":"[REDACTED]"'
    $Line = $Line -replace 'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+', '[TOKEN REDACTED]'
    $Line -replace 'sb_(?:secret|publishable)_[A-Za-z0-9_-]+', '[LOCAL KEY REDACTED]'
}

function Invoke-Check {
    param([string]$Name, [string]$Executable, [string[]]$Arguments)
    $started = [DateTimeOffset]::Now.ToString('o')
    Write-Output "Executing: $Executable $($Arguments -join ' ')"
    try {
        & $Executable @Arguments 2>&1 |
            ForEach-Object { Remove-LocalSecrets ([string]$_) } |
            Tee-Object -FilePath (Join-Path $evidenceDirectory "$Name.txt")
        $resultCode = $LASTEXITCODE
        $status = if ($resultCode -eq 0) { 'PASS' } else { 'FAIL' }
        if ($Name -eq 'db-lint' -and $resultCode -eq 0) {
            $jsonLine = Get-Content -LiteralPath (Join-Path $evidenceDirectory "$Name.txt") | Where-Object { $_ -match '^\{' } | Select-Object -Last 1
            if ($jsonLine) {
                $lintResult = $jsonLine | ConvertFrom-Json
                if ($lintResult.results | Where-Object { $_.issues.Count -gt 0 }) { $status = 'FAIL' }
            }
        }
    } catch {
        $_.Exception.Message | Set-Content -LiteralPath (Join-Path $evidenceDirectory "$Name.txt")
        $resultCode = $null
        $status = 'NOT_RUN'
    }
    $results.Add([PSCustomObject]@{
        name = $Name; executable = $Executable; arguments = $Arguments
        started_at = $started; exit_code = $resultCode; status = $status
    })
    Write-Output "$Name : $status (exit=$resultCode)"
}

Push-Location $projectRoot
try {
    $localConfig = Get-Content -LiteralPath supabase/config.toml -Raw
    if ($localConfig -notmatch '(?m)^project_id\s*=\s*"mixtick-phase02"\s*$') {
        throw 'Refusing tests/reset for any project other than mixtick-phase02.'
    }
    Invoke-Check 'cli-version' $SupabaseExecutable @('--version')
    Invoke-Check 'docker-version' 'docker' @('version', '--format', '{{.Server.Version}}')
    $networkId = docker network inspect mixtick-local-tests --format '{{.Id}}' 2>$null
    if (-not $networkId -and $StartLocal) {
        $networkId = docker network create -o 'com.docker.network.bridge.host_binding_ipv4=127.0.0.1' mixtick-local-tests
        if ($LASTEXITCODE -ne 0) { throw 'Cannot create project-local loopback network.' }
    }
    if (-not $networkId) { throw 'Local test network missing. Run with -StartLocal after starting Docker.' }
    if ($StartLocal) {
        $startedHere = $true
        & (Join-Path $PSScriptRoot 'start_isolated_supabase.ps1') -SupabaseExecutable $SupabaseExecutable -DartExecutable $DartExecutable -EvidenceDirectory $evidenceDirectory
        if ($LASTEXITCODE -ne 0) { throw 'Isolated startup failed' }
        & (Join-Path $PSScriptRoot 'assert_local_isolation.ps1') -EvidenceDirectory $evidenceDirectory
        $ports = docker ps --filter name=mixtick-phase02 --format '{{.Names}} {{.Ports}}'
        $ports | Set-Content -LiteralPath (Join-Path $evidenceDirectory 'local-containers.txt')
        if ($ports -match '0\.0\.0\.0:|\[::\]:') {
            throw 'Refusing an exposed test stack'
        }
    }
    # Reset is explicitly opt-in, scoped to this local fixture project only.
    if ($ResetLocal) {
        # CLI reset may recreate the DB container: keep explicit loopback mapping.
        $realDocker = (Get-Command docker -CommandType Application | Select-Object -First 1).Source
        $adapterDirectory = Join-Path $projectRoot '.tooling/loopback-docker'
        New-Item -ItemType Directory -Force -Path $adapterDirectory | Out-Null
        & $DartExecutable compile exe "-DMIXTICK_REAL_DOCKER=$realDocker" scripts/loopback_docker.dart -o (Join-Path $adapterDirectory 'docker.exe')
        if ($LASTEXITCODE -ne 0) { throw 'Isolation adapter failed' }
        $beforeResetPath = $env:Path
        $env:Path = $adapterDirectory + ';' + $env:Path
        try {
        Invoke-Check 'db-reset' $SupabaseExecutable @('db', 'reset', '--local', '--network-id', $networkId)
        } finally { $env:Path = $beforeResetPath }
        & (Join-Path $PSScriptRoot 'assert_local_isolation.ps1') -EvidenceDirectory $evidenceDirectory
    }
    Invoke-Check 'sql-tests' $SupabaseExecutable @('test', 'db', '--network-id', $networkId)
    Invoke-Check 'db-lint' $SupabaseExecutable @('db', 'lint', '--local', '--level', 'warning', '--network-id', $networkId)
    Invoke-Check 'api-tests' $PythonExecutable @('scripts/test_database_api.py', '--cli', $SupabaseExecutable)
    if (-not $BackendOnly) {
        Invoke-Check 'flutter-analyze' $FlutterExecutable @('analyze')
        Invoke-Check 'flutter-test' $FlutterExecutable @('test', '--reporter', 'expanded')
        Invoke-Check 'format-check' $DartExecutable @('format', '--output=none', '--set-exit-if-changed', 'lib', 'test')
        Invoke-Check 'identifiers' $PythonExecutable @('scripts/check_identifiers.py', '--strict')
    }
} finally {
    if ($startedHere -and -not $KeepLocalRunning) {
        Invoke-Check 'local-stop' $SupabaseExecutable @('stop', '--project-id', 'mixtick-phase02')
    }
    $results | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $evidenceDirectory 'results.json') -Encoding utf8
    Pop-Location
}
if ($results.Where({ $_.status -ne 'PASS' }).Count -gt 0) { exit 1 }
exit 0
