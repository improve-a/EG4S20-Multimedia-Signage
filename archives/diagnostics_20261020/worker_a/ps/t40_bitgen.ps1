$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$a='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\td_project\hx4s20_basic_Runs\phy_1'
$b='D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design\td_project\hx4s20_basic_Runs\phy_1'
foreach($f in @('.bitgen_param.f','run.bat','settings.cfg')){
 $x="$a\$f"; $y="$b\$f"
 "### $f"
 "A " + (Get-FileHash $x -Algorithm SHA256).Hash
 "B " + (Get-FileHash $y -Algorithm SHA256).Hash
 Get-Content $x
}
