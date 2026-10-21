$ErrorActionPreference='Stop'
$sets=@(
 @('FAIL','D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004'),
 @('PASS','D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001'))
foreach($p in $sets){
 $t=$p[0];$d=$p[1]
 "##### $t syn warnings"
 Select-String -Path "$d\work\design\td_project\hx4s20_basic_Runs\syn_1\run.log" -Pattern 'WARNING|Warning|ERROR|Error|unused|remov|optimi|dangl|constant' | Select-Object -First 40 | ForEach-Object { $_.Line.Trim() }
 "##### $t phy warnings"
 Select-String -Path "$d\work\design\td_project\hx4s20_basic_Runs\phy_1\run.log" -Pattern 'WARNING|Warning|ERROR|Error|seed|Seed|hold|Hold|timing|Timing' | Select-Object -First 40 | ForEach-Object { $_.Line.Trim() }
 "##### $t settings.cfg"
 Get-Content "$d\work\design\td_project\hx4s20_basic_Runs\phy_1\settings.cfg"
 "##### $t status"
 Get-Content "$d\runs\$(if($t -eq 'FAIL'){'no_bot_legacy_004'}else{'hdmi_probe_001'})\status.json"
}
