$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$a='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\td_project\hx4s20_basic_Runs'
"### A gate.timing head"
Get-Content "$a\syn_1\hx4s20_basic_gate.timing" -TotalCount 70
"### A final_timing head"
Get-Content "$a\phy_1\final_timing.rpt" -TotalCount 60
"### py"
& cmd /c "python --version 2>&1 & py -3 --version 2>&1"
