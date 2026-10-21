$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$a='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004'
$b='D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001'
$files=@(
 'work\design\user_source\hdl_source\top_tf_hdmi_audio.v',
 'work\design\user_source\hdl_source\ext\hdmi_probe.v',
 'work\design\td_project\hx4s20_basic_Runs\syn_1\hx4s20_basic_gate.db',
 'work\design\td_project\hx4s20_basic_Runs\syn_1\hx4s20_basic_gate.area',
 'work\design\td_project\hx4s20_basic_Runs\phy_1\hx4s20_basic.bit',
 'work\design\td_project\hx4s20_basic_Runs\phy_1\final_timing.rpt'
)
foreach($f in $files){
 $pa="$a\$f"; $pb="$b\$f"
 $ha='MISSING'; $la=0; $hb='MISSING'; $lb=0
 if(Test-Path $pa){$ha=(Get-FileHash $pa -Algorithm SHA256).Hash; $la=(Get-Item $pa).Length}
 if(Test-Path $pb){$hb=(Get-FileHash $pb -Algorithm SHA256).Hash; $lb=(Get-Item $pb).Length}
 "{0}`n  A {1} {2}`n  B {3} {4}" -f $f,$ha,$la,$hb,$lb
}
