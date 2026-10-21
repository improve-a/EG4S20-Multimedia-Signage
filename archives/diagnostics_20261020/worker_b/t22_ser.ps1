$ErrorActionPreference='Stop'
function Parse($f,$tag){
 $L=Get-Content $f
 $g=''; $r=$null; $out=@()
 foreach($line in $L){
  if($line -match '^Path Group\s+:\s+(.+)$'){ $g=$Matches[1].Trim(); $r=$null; continue }
  if($line -match '^Slack\s+:\s+(-?[0-9.]+)ns'){ if($r){$out+=$r}; $r=[pscustomobject]@{G=$g;S=[double]$Matches[1];B='';E='';C='';D='';K=''}; continue }
  if($r){
   if($line -match '^Begin Point\s+:\s+(.+)$'){$r.B=$Matches[1];continue}
   if($line -match '^End Point\s+:\s+(.+)$'){$r.E=$Matches[1];continue}
   if($line -match '^Check Type\s+:\s+(.+)$'){$r.C=$Matches[1];continue}
   if($line -match '^Data Path Delay\s+:\s+(.+)$'){$r.D=$Matches[1];continue}
   if($line -match '^Clock Skew\s+:\s+(.+)$'){$r.K=$Matches[1];continue}
  }
 }
 if($r){$out+=$r}
 "##### $tag odd_even paths"
 $out | Where-Object {$_.B -match 'S_odd_even_reg'} | Sort-Object S | ForEach-Object { "S={0} C={1} K={2} D={3}`n  B={4}`n  E={5}" -f $_.S,$_.C,$_.K,$_.D,$_.B,$_.E }
 "##### $tag load_en/shift paths"
 $out | Where-Object {$_.B -match 'S_load_en|S_shift_data' -or $_.E -match 'S_load_en|S_shift_data'} | Sort-Object S | Select-Object -First 12 | ForEach-Object { "S={0} C={1} K={2} D={3}`n  B={4}`n  E={5}" -f $_.S,$_.C,$_.K,$_.D,$_.B,$_.E }
 "##### $tag hr paths ending ODDR"
 $out | Where-Object {$_.E -match 'ODDR|_syn_2.do'} | Sort-Object S | Select-Object -First 10 | ForEach-Object { "S={0} C={1} K={2}`n  B={3}`n  E={4}" -f $_.S,$_.C,$_.K,$_.B,$_.E }
}
Parse 'D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\runs\no_bot_legacy_004\final_timing.rpt' 'FAIL'
Parse 'D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\runs\hdmi_probe_001\final_timing.rpt' 'PASS'
