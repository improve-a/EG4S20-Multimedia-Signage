[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
foreach ($r in @('D:\FPGA\EG4S20-NoBot-HDMIProbe','D:\FPGA\EG4S20-NoBot','D:\FPGA\EG4S20-Bot-HDMIProbe')) {
  Write-Output ("=== " + $r)
  if (-not (Test-Path $r)) { Write-Output MISSING; continue }
  Get-ChildItem -LiteralPath "$r\rtl" -Recurse -File -Filter '*.v' -ErrorAction SilentlyContinue |
    Select-String -Pattern 'ENABLE_LAYER_RESOURCES\s*\(\s*\d|ENABLE_EXHIBIT\s*\(\s*\d|SCAN_TARGET_COUNT|ENABLE_CONTENT_MODES\s*\(\s*\d' |
    ForEach-Object { "{0}:{1}: {2}" -f $_.Filename, $_.LineNumber, $_.Line.Trim() }
}
Write-Output "=== DONE ==="
