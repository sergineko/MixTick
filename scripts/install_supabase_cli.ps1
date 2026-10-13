# Portable project-local tool. No global PATH changes and no Supabase login.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$toolDirectory = Join-Path $projectRoot '.tooling/supabase'
New-Item -ItemType Directory -Path $toolDirectory -Force | Out-Null
$archive = Join-Path $toolDirectory 'supabase_2.120.0_windows_amd64.tar.gz'
Invoke-WebRequest -Uri 'https://github.com/supabase/cli/releases/download/v2.120.0/supabase_2.120.0_windows_amd64.tar.gz' -OutFile $archive
$actualHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualHash -ne '53920013d24bc9e66180f35ceeea9ddc20e65a7afa883421e9c0ba60ad7457ee') {
    throw 'Supabase CLI archive checksum mismatch.'
}
& tar.exe -xf $archive -C $toolDirectory
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $toolDirectory 'supabase.exe') --version
exit $LASTEXITCODE
