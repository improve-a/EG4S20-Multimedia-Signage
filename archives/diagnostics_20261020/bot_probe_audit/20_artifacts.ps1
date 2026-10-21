[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Stop'
$b = 'D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001'
Write-Output "=== top-level of build dir ==="
Get-ChildItem -LiteralPath $b | Select-Object Mode,Name | Format-Table -AutoSize
Write-Output "=== dirs/search for mapped verilog or async_reg attrs ==="
Get-ChildItem -LiteralPath $b -Recurse -File -Include *.v,*.vm,*.edf,*.edn -ErrorAction SilentlyContinue | Select-Object -First 20 FullName,Length | Format-Table -AutoSize
Write-Output "=== evidence dir ==="
Get-ChildItem -LiteralPath 'D:\FPGA\EG4S20-NoBot-HDMIProbe\evidence\hdmi_probe' -ErrorAction SilentlyContinue | Select-Object Name,Length | Format-Table -AutoSize
Write-Output "=== DONE ==="
