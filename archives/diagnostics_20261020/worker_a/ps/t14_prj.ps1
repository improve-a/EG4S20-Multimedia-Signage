$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$a='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\td_project\hx4s20_basic_Runs\syn_1\hx4s20_basic.prj'
$b='D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design\td_project\hx4s20_basic_Runs\syn_1\hx4s20_basic.prj'
Compare-Object (Get-Content $a) (Get-Content $b) | ForEach-Object { "{0} {1}" -f $_.SideIndicator,$_.InputObject }
"### hash key sources"
$ua='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\user_source'
$ub='D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design\user_source'
$fs=@('hdl_source\hdmi1.4b_transmitter_core\hdmi_1_4b_transmitter_core_wrapper.enc.v','hdl_source\hdmi_phy_warpper.v','constraints_source\timing.sdc','constraints_source\pin.adc')
foreach($f in $fs){ $x=(Get-FileHash "$ua\$f" -Algorithm SHA256).Hash; $y=(Get-FileHash "$ub\$f" -Algorithm SHA256).Hash; "{0} same={1} A={2} B={3}" -f $f,($x -eq $y),$x.Substring(0,16),$y.Substring(0,16) }
