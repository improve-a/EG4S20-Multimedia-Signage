$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$a='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\user_source\hdl_source\top_tf_hdmi_audio.v'
$b='D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design\user_source\hdl_source\top_tf_hdmi_audio.v'
$la=Get-Content $a; $lb=Get-Content $b
$i=0
Compare-Object $la $lb | ForEach-Object { "{0} {1}" -f $_.SideIndicator, $_.InputObject }
"---- B lines 130-180"
$k=0; foreach($l in $lb){ $k++; if($k -ge 130 -and $k -le 180){"{0,4}: {1}" -f $k,$l} }
"---- B lines 330-360"
$k=0; foreach($l in $lb){ $k++; if($k -ge 330 -and $k -le 360){"{0,4}: {1}" -f $k,$l} }
"---- B lines 500-540"
$k=0; foreach($l in $lb){ $k++; if($k -ge 500 -and $k -le 545){"{0,4}: {1}" -f $k,$l} }
