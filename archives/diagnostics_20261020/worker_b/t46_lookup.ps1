$ErrorActionPreference='Stop'
function FindSlack($f,$val){
 $L=Get-Content $f
 "##### $f slack=$val"
 for($i=0;$i -lt $L.Count;$i++){
  if($L[$i] -match ('^Slack\s+:\s+'+[regex]::Escape($val)+'ns')){
   $L[$i..([Math]::Min($i+13,$L.Count-1))]
   ""
  }
 }
}
$f1='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\runs\no_bot_legacy_004\final_timing.rpt'
$f2='D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\runs\hdmi_probe_001\final_timing.rpt'
FindSlack $f1 '2.525'
FindSlack $f2 '2.756'
FindSlack $f2 '0.035'
