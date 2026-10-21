$ErrorActionPreference='Stop'
function ShowPath($f,$target,$ctx){
 $L=Get-Content $f
 for($i=0;$i -lt $L.Count;$i++){
  if($L[$i] -match ('^Slack\s+:\s+'+[regex]::Escape($target)+'ns')){
   "##### $f  slack=$target"
   $L[$i..([Math]::Min($i+$ctx,$L.Count-1))]
   return
  }
 }
 "NOT FOUND $target in $f"
}
$f1='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\runs\no_bot_legacy_004\final_timing.rpt'
$f2='D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\runs\hdmi_probe_001\final_timing.rpt'
ShowPath $f1 '6.296' 95
ShowPath $f2 '6.179' 95
