[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
$files = @(
 'D:\FPGA\EG4S20-NoBot-HDMIProbe\docs\no_bot_legacy_media.md',
 'D:\FPGA\EG4S20-NoBot-HDMIProbe\output\venue_emergency_ui\tf_card_package\manifest.json',
 'D:\FPGA\EG4S20-NoBot-HDMIProbe\output\venue_emergency_ui\tf_card_package\README.txt',
 'D:\FPGA\EG4S20-NoBot-HDMIProbe\output\venue_unified_offline\media\manifest.json',
 'D:\FPGA\EG4S20-NoBot-HDMIProbe\output\venue_unified_offline\media\README.md',
 'D:\FPGA\EG4S20-NoBot-HDMIProbe\output\venue_unified_offline\media\SHA256SUMS'
)
foreach ($f in $files) {
  Write-Output ("===== FILE " + $f + " =====")
  if (Test-Path $f) { Get-Content -LiteralPath $f -Raw -Encoding UTF8 } else { Write-Output "MISSING" }
  Write-Output ""
}
Write-Output "=== DONE ==="
