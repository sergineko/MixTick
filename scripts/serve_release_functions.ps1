param([string]$EvidenceDirectory='docs/reports/phase08/evidence')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Push-Location $root
$oldPath=$env:Path
try {
  if ((Get-Content supabase/config.toml -Raw) -notmatch '(?m)^project_id\s*=\s*"mixtick-phase02"\s*$') {throw 'Unexpected project'}
  & scripts/assert_local_isolation.ps1 -EvidenceDirectory $EvidenceDirectory
  $env:DO_NOT_TRACK='1'
  $env:CI='true'
  $env:Path=(Join-Path $root '.tooling/loopback-docker')+';'+$oldPath
  $secretPath=Join-Path $root '.tooling/phase08-functions.env'
  if (-not (Test-Path -LiteralPath $secretPath)) {
    $secret=[Convert]::ToHexString([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
    [System.IO.File]::WriteAllText($secretPath,'MIXTICK_WORKER_SECRET='+$secret+"`n")
  }
  $network=docker network inspect mixtick-local-tests --format '{{.Id}}'
  # Local serving only. No --no-verify-jwt: each function uses its own config.
  & .tooling/supabase/supabase.exe functions serve --env-file $secretPath --network-id $network
  exit $LASTEXITCODE
} finally {$env:Path=$oldPath; Pop-Location}
