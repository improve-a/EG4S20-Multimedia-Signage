[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
foreach ($r in @('D:\FPGA\EG4S20-Multimedia-Signage','D:\FPGA\EG4S20-NoBot-HDMIProbe','D:\FPGA\EG4S20-Bot-HDMIProbe')) {
  Write-Output ("=== CARDDIRS " + $r + " ===")
  if (-not (Test-Path $r)) { Write-Output "MISSING"; continue }
  Get-ChildItem -LiteralPath $r -Recurse -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match 'card|sd|tf|media|asset|page|hfx' } |
    ForEach-Object { $_.FullName.Substring($r.Length).TrimStart('\') } |
    Sort-Object | Select-Object -First 80
}
Write-Output "=== HFXL ANYWARE ==="
foreach ($r in @('D:\FPGA\EG4S20-Multimedia-Signage','D:\FPGA\EG4S20-NoBot-HDMIProbe')) {
  Get-ChildItem -LiteralPath $r -Recurse -File -Filter '*.hfxl' -ErrorAction SilentlyContinue |
    ForEach-Object { "{0,10}  {1}  {2}" -f $_.Length, $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'), $_.FullName }
}
Write-Output "=== BMP/WAV in source (not output) ==="
foreach ($r in @('D:\FPGA\EG4S20-Multimedia-Signage','D:\FPGA\EG4S20-NoBot-HDMIProbe')) {
  Get-ChildItem -LiteralPath $r -Recurse -File -ErrorAction SilentlyContinue -Include '*.bmp','*.wav' |
    Where-Object { $_.FullName -notmatch '\\output\\' } |
    ForEach-Object { "{0,10}  {1}  {2}" -f $_.Length, $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'), $_.FullName }
}
Write-Output "=== DONE ==="
