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
 "##### $tag total_paths=" + $out.Count
 "--- by check type"
 $out | Group-Object C | ForEach-Object { "{0}`tcount={1}`tmin={2}" -f $_.Name,$_.Count,($_.Group | Measure-Object S -Minimum).Minimum }
 "--- ALL setup paths slack<1.0"
 $out | Where-Object {$_.C -eq 'setup' -and $_.S -lt 1.0} | Sort-Object S | Select-Object -First 40 | ForEach-Object { "S={0}`tG={1}`n B={2}`n E={3}`n D={4} K={5}" -f $_.S,$_.G,$_.B,$_.E,$_.D,$_.K }
 "--- ALL removal paths (any slack) sorted"
 $out | Where-Object {$_.C -eq 'removal'} | Sort-Object S | Select-Object -First 30 | ForEach-Object { "S={0}`tG={1}`n B={2}`n E={3}`n D={4} K={5}" -f $_.S,$_.G,$_.B,$_.E,$_.D,$_.K }
 "--- video->5x all checks"
 $out | Where-Object {$_.G -match 'video_clk -> hdmi_5x_clk'} | Sort-Object S | Select-Object -First 12 | ForEach-Object { "S={0}`tC={1}`n B={2}`n E={3}`n D={4} K={5}" -f $_.S,$_.C,$_.B,$_.E,$_.D,$_.K }
 "--- 5x intra all checks"
 $out | Where-Object {$_.G -match '^hdmi_5x_clk -> hdmi_5x_clk'} | Sort-Object S | Select-Object -First 10 | ForEach-Object { "S={0}`tC={1}`n B={2}`n E={3}`n D={4} K={5}" -f $_.S,$_.C,$_.B,$_.E,$_.D,$_.K }
}
Parse 'D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\runs\no_bot_legacy_004\final_timing.rpt' 'FAIL'
Parse 'D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\runs\hdmi_probe_001\final_timing.rpt' 'PASS'
