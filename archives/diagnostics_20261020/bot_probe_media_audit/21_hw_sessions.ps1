[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
foreach ($r in @('D:\FPGA\EG4S20-Multimedia-Signage\output\hardware','D:\FPGA\EG4S20-NoBot\output\hardware')) {
  Write-Output ("=== " + $r)
  if (-not (Test-Path $r)) { Write-Output MISSING; continue }
  Get-ChildItem -LiteralPath $r -Directory | Sort-Object Name | ForEach-Object { "DIR  " + $_.Name + "  " + $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm') }
  Get-ChildItem -LiteralPath $r -File | Sort-Object Name | ForEach-Object { "FILE {0,9} {1}  {2}" -f $_.Length, $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm'), $_.Name }
}
Write-Output "=== harness jtag scripts ==="
foreach ($f in @('D:\FPGA\hx4s20_usb_jtag_harness_20261013\scripts\c_programmer_docs.ps1','D:\FPGA\hx4s20_usb_jtag_harness_20261013\scripts\a_jtag_detail.ps1')) {
  Write-Output ("===== " + $f); if (Test-Path $f) { Get-Content -LiteralPath $f -Raw -Encoding UTF8 } else { Write-Output MISSING }; Write-Output ''
}
Write-Output "=== DONE ==="
