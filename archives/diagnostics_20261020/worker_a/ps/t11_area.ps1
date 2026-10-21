$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$a='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\td_project\hx4s20_basic_Runs\syn_1'
$b='D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design\td_project\hx4s20_basic_Runs\syn_1'
"### A gate.area head"
Get-Content "$a\hx4s20_basic_gate.area" -TotalCount 80
"### A gate.area tail"
Get-Content "$a\hx4s20_basic_gate.area" -Tail 20
