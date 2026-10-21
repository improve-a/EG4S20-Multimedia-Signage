$ErrorActionPreference='Stop'
$sets=@(
 @('FAIL','D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\runs\no_bot_legacy_004\final_area.rpt','D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\td_project\hx4s20_basic_Runs\phy_1'),
 @('PASS','D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\runs\hdmi_probe_001\final_area.rpt','D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design\td_project\hx4s20_basic_Runs\phy_1'))
foreach($p in $sets){
 $t=$p[0];$ar=$p[1];$ph=$p[2]
 "##### $t clock domains"
 Get-Content $ar | Select-String -Pattern 'Report Clock Domain' -Context 0,16 | ForEach-Object { $_.Line; $_.Context.PostContext }
 "##### $t place.qor"; Get-Content "$ph\place.qor"
 "##### $t route.qor"; Get-Content "$ph\route.qor"
}
