$ErrorActionPreference='Stop'
"host=" + $env:COMPUTERNAME
"date=" + (Get-Date).ToString('o')
$p1='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004'
$p2='D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001'
foreach($p in @($p1,$p2)){ "== $p exists=" + (Test-Path $p) }
Get-ChildItem -Force $p1 | Select-Object Mode,LastWriteTime,Length,Name | Format-Table -AutoSize | Out-String -Width 200
Get-ChildItem -Force $p2 | Select-Object Mode,LastWriteTime,Length,Name | Format-Table -AutoSize | Out-String -Width 200
