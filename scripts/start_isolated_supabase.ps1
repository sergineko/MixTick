param(
    [string]$DartExecutable = 'C:\Users\Sergio\develop\flutter\bin\dart.bat',
    [string]$SupabaseExecutable = '',
    [string]$EvidenceDirectory = 'docs/reports/phase03/evidence'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
$previousPath = $env:Path
try {
    if (-not $SupabaseExecutable) { $SupabaseExecutable = Join-Path $projectRoot '.tooling/supabase/supabase.exe' }
    if ((Get-Content supabase/config.toml -Raw) -notmatch '(?m)^project_id\s*=\s*"mixtick-phase02"\s*$') { throw 'Unexpected local project' }
    $realDocker = (Get-Command docker -CommandType Application | Select-Object -First 1).Source
    if (docker ps -q --filter name=mixtick-phase02) { throw 'Stop the existing project before isolated startup' }
    $adapterDirectory = Join-Path $projectRoot '.tooling/loopback-docker'
    New-Item -ItemType Directory -Force -Path $adapterDirectory, $EvidenceDirectory | Out-Null
    & $DartExecutable compile exe "-DMIXTICK_REAL_DOCKER=$realDocker" scripts/loopback_docker.dart -o (Join-Path $adapterDirectory 'docker.exe')
    if ($LASTEXITCODE -ne 0) { throw 'Adapter compilation failed' }
    $networkId = docker network inspect mixtick-local-tests --format '{{.Id}}' 2>$null
    if (-not $networkId) { $networkId = docker network create -o 'com.docker.network.bridge.host_binding_ipv4=127.0.0.1' mixtick-local-tests }
    $env:MIXTICK_REAL_DOCKER = $realDocker
    $env:Path = $adapterDirectory + ';' + $previousPath
    $env:DO_NOT_TRACK = '1'
    $env:CI = 'true'
    # No raw CLI output enters evidence: local setup also contains admin keys.
    & $SupabaseExecutable start --network-id $networkId -x 'studio,imgproxy,edge-runtime,logflare,vector,supavisor,postgres-meta' *> '.tooling/phase03-start-private.txt'
    if ($LASTEXITCODE -ne 0) { throw 'Local start failed; inspect ignored private output' }
    $containers = docker ps -q --filter name=mixtick-phase02
    if (-not $containers) { throw 'No project containers' }
    $inspection = docker inspect @containers | ConvertFrom-Json
    foreach ($container in $inspection) {
        foreach ($port in $container.NetworkSettings.Ports.PSObject.Properties) {
            foreach ($binding in $port.Value) {
                if ($binding.HostIp -ne '127.0.0.1') { throw 'Non-loopback binding detected' }
            }
        }
    }
    docker ps --filter name=mixtick-phase02 --format '{{.Names}} {{.Ports}}' | Set-Content (Join-Path $EvidenceDirectory 'isolated-containers.txt')
    'PASS: every published project port explicitly bound to 127.0.0.1; no wildcard/IPv6 binding' | Tee-Object -FilePath (Join-Path $EvidenceDirectory 'isolated-start.txt')
} catch {
    & $SupabaseExecutable stop --project-id mixtick-phase02 *> '.tooling/phase03-stop-private.txt'
    throw
} finally {
    $env:Path = $previousPath
    Remove-Item Env:MIXTICK_REAL_DOCKER -ErrorAction SilentlyContinue
    Pop-Location
}
