[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Stop'
$src = 'D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design\user_source\hdl_source'
Write-Output "===== seg_decoder.v ====="
Get-Content -LiteralPath (Join-Path $src 'SD\seg_decoder.v')
Write-Output "===== seg_scan.v ====="
Get-Content -LiteralPath (Join-Path $src 'SD\seg_scan.v')
Write-Output "=== DONE ==="
