$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$b='D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design\td_project\hx4s20_basic_Runs'
"### B gate.timing 1-45"
Get-Content "$b\syn_1\hx4s20_basic_gate.timing" -TotalCount 45
"### B final_timing 1-45"
Get-Content "$b\phy_1\final_timing.rpt" -TotalCount 45
"### frozen clocks.rpt"
Get-Content 'D:\FPGA\EG4S20-NoBot-Frozen\probe_hw_pass_20261020\reports\clocks.rpt'
