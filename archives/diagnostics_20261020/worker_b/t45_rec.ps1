$ErrorActionPreference='Stop'
function Parse($f,$tag){
 $L=Get-Content $f; $g=''; $r=$null; $out=@()
 foreach($line in $L){
  if($line -match '^Path Group\s+:\s+(.+)$'){ $g=$Matches[1].Trim(); $r=$null; continue }
  if($line -match '^Slack\s+:\s+(-?[0-9.]+)ns'){ if($r){$out+=$r}; $r=[pscustomobject]@{G=$g;S=[double]$Matches[1];B='';E='';C=''}; continue }
  if($r){ if($line -match '^Begin Point\s+:\s+(.+)$'){$r.B=$Matches[1];continue}; if($line -match '^End Point\s+:\s+(.+)$'){$r.E=$Matches[1];continue}; if($line -match '^Check Type\s+:\s+(.+)$'){$r.C=$Matches[1];continue} }
 }
 if($r){$out+=$r}
 "##### $tag recovery all"
 $out | Where-Object {$_.C -eq 'recovery'} | Sort-Object S | Select-Object -First 8 | ForEach-Object { "S={0} G={1}`n  B={2}`n  E={3}" -f $_.S,$_.G,$_.B,$_.E }
}
Parse 'D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\runs\no_bot_legacy_004\final_timing.rpt' 'FAIL'
Parse 'D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\runs\hdmi_probe_001\final_timing.rpt' 'PASS'
