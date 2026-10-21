$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$a='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\td_project\hx4s20_basic_Runs'
$b='D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design\td_project\hx4s20_basic_Runs'
foreach($p in @(@('A',$a),@('B',$b))){
 "##### " + $p[0] + " gate.qor"
 Get-Content "$($p[1])\syn_1\gate.qor" | Select-Object -First 60
 "##### " + $p[0] + " place.qor"
 Get-Content "$($p[1])\phy_1\place.qor"
 "##### " + $p[0] + " route.qor"
 Get-Content "$($p[1])\phy_1\route.qor"
}
