[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zips = @(
 'D:\FPGA\EG4S20-Multimedia-Signage\artifacts\timing_fix_20261016_02_source.zip',
 'D:\FPGA\EG4S20-Bot-HDMIProbe\artifacts\timing_fix_20261016_02_source.zip'
)
foreach ($z in $zips) {
  Write-Output ("=== " + $z)
  if (-not (Test-Path $z)) { Write-Output MISSING; continue }
  "{0,10} {1}  sha256={2}" -f (Get-Item $z).Length, (Get-Item $z).LastWriteTime.ToString('yyyy-MM-dd HH:mm'), (Get-FileHash $z -Algorithm SHA256).Hash
  $a = [System.IO.Compression.ZipFile]::OpenRead($z)
  $e = $a.Entries | Where-Object { $_.FullName -like '*ext/html_scene_loader.v' } | Select-Object -First 1
  if ($e) {
    $r = New-Object System.IO.StreamReader($e.Open())
    $t = $r.ReadToEnd(); $r.Close()
    ($t -split "`n") | Select-String -Pattern 'SET_ID|BASE_WORDS|LENGTH_WORDS' | Select-Object -First 4 | ForEach-Object { $_.Line.Trim() }
  } else { Write-Output 'scene_loader not in zip' }
  $e2 = $a.Entries | Where-Object { $_.FullName -like '*SD/sd_card_bmp.v' } | Select-Object -First 1
  if ($e2) { Write-Output ('sd_card_bmp.v in zip: ' + $e2.Length + ' bytes') }
  $a.Dispose()
}
Write-Output "=== DONE ==="
