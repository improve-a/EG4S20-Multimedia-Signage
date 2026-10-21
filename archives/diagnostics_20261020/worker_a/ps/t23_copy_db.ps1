$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$d='D:\FPGA\EG4S20-NoBot-RCA-20261020\worker_a'
$a='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\td_project\hx4s20_basic_Runs\syn_1\hx4s20_basic_gate.db'
$b='D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design\td_project\hx4s20_basic_Runs\syn_1\hx4s20_basic_gate.db'
Copy-Item $a "$d\a_gate.db" -Force
Copy-Item $b "$d\b_gate.db" -Force
Get-ChildItem $d | Select-Object Length,Name | Format-Table -AutoSize | Out-String -Width 120
"sha A=" + (Get-FileHash "$d\a_gate.db" -Algorithm SHA256).Hash
"sha B=" + (Get-FileHash "$d\b_gate.db" -Algorithm SHA256).Hash
