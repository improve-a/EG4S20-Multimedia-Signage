$ErrorActionPreference='Stop'
$b1='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\runs\no_bot_legacy_004'
$b2='D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\runs\hdmi_probe_001'
"### FAIL clocks.rpt"; Get-Content "$b1\clocks.rpt"
"### PASS clocks.rpt"; Get-Content "$b2\clocks.rpt"
"### FAIL check_timing head 120"; Get-Content "$b1\check_timing.rpt" -TotalCount 120
"### PASS check_timing head 120"; Get-Content "$b2\check_timing.rpt" -TotalCount 120
