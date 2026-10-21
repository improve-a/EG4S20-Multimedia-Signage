$ErrorActionPreference='Stop'
foreach($d in @('D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004','D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001')){
 "##### $d"
 Get-ChildItem "$d\work\design\td_project\hx4s20_basic_Runs\best_result" -File | ForEach-Object { "{0} {1} {2}" -f $_.Length,$_.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'),$_.Name }
 Get-Content "$d\work\design\td_project\hx4s20_basic_Runs\best_result\readMe.txt"
 Get-Content "$d\work\design\td_project\hx4s20_basic_Runs\best_result\hx4s20_basic_phy.ts"
}
