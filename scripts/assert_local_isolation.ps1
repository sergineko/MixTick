param([string]$EvidenceDirectory = 'docs/reports/phase03/evidence')
$ErrorActionPreference = 'Stop'
$version = docker version --format '{{.Server.Version}}'
if ([int]($version -split '\.')[0] -lt 28) { throw 'Docker >=28 required for localhost port isolation' }
$ids = @(docker ps -q --filter name=mixtick-phase02)
if (-not $ids) { throw 'Local fixture project is not running' }
$containers = docker inspect @ids | ConvertFrom-Json
$ports = [System.Collections.Generic.HashSet[int]]::new()
foreach ($container in $containers) {
    foreach ($property in $container.NetworkSettings.Ports.PSObject.Properties) {
        foreach ($binding in $property.Value) {
            if ($binding.HostIp -ne '127.0.0.1') { throw 'Non-loopback Docker publication' }
            [void]$ports.Add([int]$binding.HostPort)
        }
    }
}
if ($ports.Count -ne 3) { throw 'Unexpected local published port inventory' }
$listeners = @(Get-NetTCPConnection -State Listen | Where-Object LocalPort -In @($ports))
if ($listeners.Count -ne 3 -or ($listeners | Where-Object LocalAddress -ne '127.0.0.1')) { throw 'Host listeners are not exclusively loopback' }
$addresses = @(Get-NetIPAddress | Where-Object { $_.IPAddress -notin @('127.0.0.1','::1') -and $_.AddressState -eq 'Preferred' })
$attempted = 0
$connected = 0
foreach ($address in $addresses) {
    foreach ($port in $ports) {
        $client = [System.Net.Sockets.TcpClient]::new()
        try {
            $attempted++
            $task = $client.ConnectAsync([System.Net.IPAddress]::Parse($address.IPAddress),$port)
            if ($task.Wait(400) -and $client.Connected) { $connected++ }
        } catch { } finally { $client.Dispose() }
    }
}
$result = [PSCustomObject]@{ docker_version=$version; docker_bindings='127.0.0.1 only';
    host_listeners=@($listeners | Select-Object LocalAddress,LocalPort); non_loopback_attempts=$attempted; non_loopback_connections=$connected;
    status= $(if ($connected -eq 0) { 'PASS' } else { 'FAIL' }) }
New-Item -ItemType Directory -Force -Path $EvidenceDirectory | Out-Null
$result | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $EvidenceDirectory 'isolation.json')
if ($connected -gt 0) { throw 'Non-loopback reachability detected' }
Write-Output "PASS: explicit loopback bindings/listeners; $attempted other-interface probes, 0 connections"
