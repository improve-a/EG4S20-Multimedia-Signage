$ErrorActionPreference='Stop'
foreach($f in @('D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\runs\no_bot_legacy_004\final_timing.rpt','D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\runs\hdmi_probe_001\final_timing.rpt')){
 "##### $f"
 Get-Content $f -TotalCount 70 | Select-Object -Skip 8
}
