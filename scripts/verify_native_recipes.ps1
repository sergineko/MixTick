param(
  [string]$Device='emulator-5554',
  [string]$FlutterExecutable='C:\Users\Sergio\develop\flutter\bin\flutter.bat',
  [string]$PythonExecutable='C:\Users\Sergio\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe',
  [string]$AdbExecutable='C:\Users\Sergio\AppData\Local\Android\Sdk\platform-tools\adb.exe',
  [string]$EvidenceDirectory='docs/reports/phase04/evidence'
)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$evidence=Join-Path $root $EvidenceDirectory
$previews=Join-Path (Split-Path -Parent $evidence) 'previews'
$raw=Join-Path $root '.tooling/phase04-native-private.txt'
$helper=$null
$priorPath=$env:Path
$previousNight=$null
$ownedGallery=$null
$result=$null
function Protect-RecipeOutput([string]$line) {
  $line=$line -replace 'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+','[TOKEN REDACTED]'
  $line=$line -replace 'P4_FIXTURE:\{[^\r\n]+\}','P4_FIXTURE:[recorded locally for cleanup]'
  $line=$line -replace '([?&](code|token|token_hash)=)[^\s&"<>]+','$1[REDACTED]'
  $line
}
Push-Location $root
try {
  [System.IO.File]::WriteAllText($raw,'')
  [System.IO.File]::WriteAllText((Join-Path $root '.tooling/phase04-gallery-helper.txt'),'')
  [System.IO.File]::WriteAllText((Join-Path $root '.tooling/phase04-gallery-helper-errors.txt'),'')
  New-Item -ItemType Directory -Force $evidence | Out-Null
  & (Join-Path $PSScriptRoot 'assert_local_isolation.ps1') -EvidenceDirectory $evidence
  $local=& .tooling/supabase/supabase.exe status -o json | ConvertFrom-Json
  @{SUPABASE_URL='http://10.0.2.2:54321';SUPABASE_PUBLISHABLE_KEY=$local.ANON_KEY;MIXTICK_ALLOW_LOCAL_BACKEND=$true} | ConvertTo-Json | Set-Content .tooling/phase04-android.local.json
  $env:Path=(Split-Path -Parent $FlutterExecutable)+';'+$env:Path
  $previousNight=((& $AdbExecutable -s $Device shell cmd uimode night) -join '').Replace('Night mode:','').Trim()
  if ($previousNight -notin @('yes','no','auto','custom')) { throw 'Unrecognized prior emulator night mode' }
  & $AdbExecutable -s $Device shell cmd uimode night no *> .tooling/phase04-night-mode.txt
  $imageName='MixTick-Phase04-'+([guid]::NewGuid().ToString('N').Substring(0,10))+'.png'
  $imageName | Set-Content .tooling/phase04-gallery-name.txt
  $ownedGallery='/sdcard/Pictures/'+$imageName
  & $AdbExecutable -s $Device push .tooling/phase04-gallery.png $ownedGallery *> .tooling/phase04-gallery-push.txt
  if ($LASTEXITCODE -ne 0) { throw 'Gallery fixture push failed' }
  & $AdbExecutable -s $Device shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d ('file://'+$ownedGallery) *> .tooling/phase04-gallery-scan.txt
  & $AdbExecutable -s $Device shell getprop ro.build.version.release | Set-Content (Join-Path $evidence 'native-android-version.txt')
  [System.IO.File]::WriteAllText($raw,'')
  # Ensure a fresh engine; --no-uninstall preserves secure app data but a
  # previous failed Photo Picker activity must not obscure the next launch.
  $activityText=(& $AdbExecutable -s $Device shell dumpsys activity activities) -join "`n"
  if ($activityText -match '(?im)^.*(?:mTopFullscreenOpaqueWindowState|topResumedActivity|mResumedActivity).*(?:photopicker|providers\.media)') {
    & $AdbExecutable -s $Device shell input keyevent BACK
  }
  & $AdbExecutable -s $Device shell am force-stop es.sergiotech.mixtick
  $helperArgs=@(('"'+(Join-Path $PSScriptRoot 'drive_recipe_gallery.py')+'"'),'--adb',('"'+$AdbExecutable+'"'),'--device',$Device,'--log',('"'+$raw+'"'),'--image-name',$imageName,'--previews',('"'+$previews+'"'))
  $helper=Start-Process -FilePath $PythonExecutable -ArgumentList $helperArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput .tooling/phase04-gallery-helper.txt -RedirectStandardError .tooling/phase04-gallery-helper-errors.txt
  $started=[DateTimeOffset]::Now.ToString('o')
  $testArguments=@('test','integration_test/recipe_native_test.dart','-d',$Device,'--no-uninstall','--dart-define-from-file=.tooling/phase04-android.local.json','--reporter','expanded')
  & $FlutterExecutable @testArguments *> $raw
  $nativeCode=$LASTEXITCODE
  $result=[pscustomobject]@{name='native-recipes';executable=$FlutterExecutable;arguments=$testArguments;started_at=$started;exit_code=$nativeCode;status=$(if($nativeCode -eq 0){'PASS'}else{'FAIL'})}
  if (-not $helper.WaitForExit(15000)) { Stop-Process -Id $helper.Id -Force; throw 'Gallery companion did not finish' }
  $helper.Refresh()
  if ($nativeCode -ne 0 -or $helper.ExitCode -ne 0) { throw 'Native recipe test or gallery companion failed; inspect redacted evidence/private output' }
  Write-Output 'PASS: native recipe UI and actual gallery cancel/select'
} finally {
  if ($helper -and -not $helper.HasExited) { Stop-Process -Id $helper.Id -Force }
  if (Test-Path $raw) {
    $text=Get-Content $raw -Raw
    $owned=@([regex]::Matches($text,'P4_FIXTURE:(\{[^\r\n]+\})') | ForEach-Object { $_.Groups[1].Value | ConvertFrom-Json })
    @{users=$owned;photos=@()} | ConvertTo-Json -Depth 4 | Set-Content .tooling/phase04-native-fixtures.json
    Get-Content $raw | ForEach-Object { Protect-RecipeOutput ([string]$_) } | Set-Content (Join-Path $evidence 'native-recipes.txt')
    & $PythonExecutable scripts/cleanup_recipe_fixtures.py --fixtures .tooling/phase04-native-fixtures.json *> (Join-Path $evidence 'native-fixture-cleanup.txt')
    if ($LASTEXITCODE -ne 0) { Write-Error 'Native fixture cleanup failed' }
  }
  if (Test-Path .tooling/phase04-gallery-helper.txt) { Get-Content .tooling/phase04-gallery-helper.txt | Set-Content (Join-Path $evidence 'native-gallery.txt') }
  if (Test-Path .tooling/phase04-gallery-helper-errors.txt) { Get-Content .tooling/phase04-gallery-helper-errors.txt | Set-Content (Join-Path $evidence 'native-gallery-errors.txt') }
  if ($previousNight -in @('yes','no','auto','custom')) { & $AdbExecutable -s $Device shell cmd uimode night $previousNight *> .tooling/phase04-night-restore.txt }
  if ($ownedGallery -match '^/sdcard/Pictures/MixTick-Phase04-[0-9a-f]{10}\.png$') {
    $mediaRows=& $AdbExecutable -s $Device shell content query --uri content://media/external/images/media --projection _id:_display_name
    foreach ($row in $mediaRows) {
      if ([string]$row -match ('_display_name='+[regex]::Escape($imageName)+'(,|$)')) {
        $mediaId=[regex]::Match([string]$row,'_id=(\d+)').Groups[1].Value
        if ($mediaId -match '^\d+$') { & $AdbExecutable -s $Device shell content delete --uri ('content://media/external/images/media/'+$mediaId) *> .tooling/phase04-gallery-metadata-remove.txt }
      }
    }
    & $AdbExecutable -s $Device shell rm -f $ownedGallery *> .tooling/phase04-gallery-remove.txt
  }
  if ($result) { $result | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $evidence 'native-results.json') }
  $env:Path=$priorPath
  Pop-Location
}
