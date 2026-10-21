[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
foreach ($f in @(
 'D:\FPGA\EG4S20-NoBot-HDMIProbe\docs\DEPENDENCIES.md',
 'D:\FPGA\EG4S20-NoBot-HDMIProbe\docs\HDMI_PROBE_BUILD.md'
)) {
  Write-Output ("===== " + $f)
  Get-Content -LiteralPath $f -Raw -Encoding UTF8
  Write-Output ""
}
Write-Output "=== DONE ==="
