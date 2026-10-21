[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
foreach ($f in @(
 'D:\FPGA\EG4S20-NoBot\output\hardware\no_bot_20261019T140608Z\card_before\manifest.json',
 'D:\FPGA\EG4S20-NoBot\output\hardware\no_bot_20261019T140608Z\card_deployed\deployment.json'
)) {
  Write-Output ("===== " + $f)
  if (Test-Path $f) { Get-Content -LiteralPath $f -Raw -Encoding UTF8 | Select-Object -First 1 } else { Write-Output MISSING }
  Write-Output ''
}
Write-Output "=== DONE ==="
