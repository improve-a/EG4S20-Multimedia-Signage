[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
$base = 'D:\FPGA\EG4S20-Multimedia-Signage\output\hardware\hw_20261016T095019Z'
foreach ($f in @(
  "$base\program_sram.tcl",
  "$base\program_sram.stdout.log",
  "$base\program_sram_status.json",
  "$base\program_hdmi_tpg.tcl",
  "$base\program_hdmi_tpg.stdout.log"
)) {
  Write-Output ("===== " + $f)
  if (Test-Path $f) { Get-Content -LiteralPath $f -Raw -Encoding UTF8 } else { Write-Output 'MISSING' }
  Write-Output ''
}
Write-Output "=== DONE ==="
