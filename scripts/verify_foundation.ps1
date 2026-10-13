param(
    [string]$FlutterExecutable = 'flutter',
    [string]$DartExecutable = 'dart',
    [string]$PythonExecutable = 'python',
    [switch]$IncludeAndroidBuild
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$evidenceDirectory = Join-Path $projectRoot 'docs/reports/evidence'
New-Item -ItemType Directory -Path $evidenceDirectory -Force | Out-Null
$results = [System.Collections.Generic.List[object]]::new()
$env:CI = 'true'
if (Test-Path -LiteralPath $FlutterExecutable) {
    $env:Path = (Split-Path -Parent $FlutterExecutable) + ';' + $env:Path
}

function Invoke-Check {
    param([string]$Name, [string]$Executable, [string[]]$Arguments)
    $logPath = Join-Path $evidenceDirectory "$Name.txt"
    Write-Output "Executing: $Executable $($Arguments -join ' ')"
    try {
        & $Executable @Arguments 2>&1 | Tee-Object -FilePath $logPath
        $resultCode = $LASTEXITCODE
        $status = if ($resultCode -eq 0) { 'PASS' } else { 'FAIL' }
    } catch {
        $_.Exception.Message | Set-Content -LiteralPath $logPath
        $resultCode = $null
        $status = 'NOT_RUN'
    }
    $results.Add([PSCustomObject]@{
        name = $Name
        executable = $Executable
        arguments = $Arguments
        exit_code = $resultCode
        status = $status
    })
    Write-Output "$Name : $status (exit=$resultCode)"
}

Push-Location $projectRoot
try {
    Invoke-Check 'flutter-version' $FlutterExecutable @('--version')
    Invoke-Check 'dart-version' $DartExecutable @('--version')
    Invoke-Check 'flutter-doctor' $FlutterExecutable @('doctor', '-v')
    Invoke-Check 'pub-get' $FlutterExecutable @('pub', 'get')
    Invoke-Check 'gen-l10n' $FlutterExecutable @('gen-l10n')
    Invoke-Check 'format' $DartExecutable @('format', 'lib', 'test')
    Invoke-Check 'format-check' $DartExecutable @('format', '--output=none', '--set-exit-if-changed', 'lib', 'test')
    Invoke-Check 'analyze' $FlutterExecutable @('analyze')
    Invoke-Check 'test' $FlutterExecutable @('test', '--reporter', 'expanded')
    Invoke-Check 'identifiers' $PythonExecutable @('scripts/check_identifiers.py', '--strict')
    if ($IncludeAndroidBuild) {
        Invoke-Check 'android-debug-build' $FlutterExecutable @('build', 'apk', '--debug')
    }
    $results | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $evidenceDirectory 'results.json') -Encoding utf8
} finally {
    Pop-Location
}

if ($results.Where({ $_.status -ne 'PASS' }).Count -gt 0) { exit 1 }
exit 0
