$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$a='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\td_project'
$b='D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design\td_project'
$files=@('hx4s20_basic_Runs\syn_1\hx4s20_basic.prj','hx4s20_basic_Runs\syn_1\hx4s20_basic.tcl','hx4s20_basic_Runs\syn_1\settings.cfg','hx4s20_basic_Runs\syn_1\run.bat','hx4s20_basic_Runs\phy_1\settings.cfg','hx4s20_basic_Runs\phy_1\run.bat')
foreach($f in $files){
 $ha=(Get-FileHash "$a\$f" -Algorithm SHA256).Hash
 $hb=(Get-FileHash "$b\$f" -Algorithm SHA256).Hash
 "{0} same={1}`n  A={2}`n  B={3}" -f $f,($ha -eq $hb),$ha,$hb
}
"### A syn settings"; Get-Content "$a\hx4s20_basic_Runs\syn_1\settings.cfg"
"### B syn settings"; Get-Content "$b\hx4s20_basic_Runs\syn_1\settings.cfg"
"### A phy settings"; Get-Content "$a\hx4s20_basic_Runs\phy_1\settings.cfg"
"### B phy settings"; Get-Content "$b\hx4s20_basic_Runs\phy_1\settings.cfg"
