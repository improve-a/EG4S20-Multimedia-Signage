$ErrorActionPreference='Stop'
foreach($p in @(@('FAIL','D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\runs\no_bot_legacy_004'),@('PASS','D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\runs\hdmi_probe_001'))){
 $t=$p[0];$d=$p[1]
 "##### $t final_area head"
 Get-Content "$d\final_area.rpt" -TotalCount 70
}
