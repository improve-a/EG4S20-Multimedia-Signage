$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$a='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\td_project\hx4s20_basic_Runs'
$b='D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design\td_project\hx4s20_basic_Runs'
"@@@A_GATE"
Get-Content "$a\syn_1\hx4s20_basic_gate.area"
"@@@B_GATE"
Get-Content "$b\syn_1\hx4s20_basic_gate.area"
"@@@A_PHY"
Get-Content "$a\phy_1\hx4s20_basic_phy.area"
"@@@B_PHY"
Get-Content "$b\phy_1\hx4s20_basic_phy.area"
