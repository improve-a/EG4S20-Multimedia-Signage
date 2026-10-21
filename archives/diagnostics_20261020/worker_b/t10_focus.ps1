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
 "##### $tag total=" + $out.Count
 foreach($gg in @('^video_clk -> video_clk','^video_clk -> hdmi_5x_clk','^hdmi_5x_clk -> hdmi_5x_clk')){
  "=== group $gg"
  foreach($cc in @('setup','hold','removal','recovery')){
   $sel=$out | Where-Object {$_.G -match $gg -and $_.C -eq $cc} | Sort-Object S
   if($sel){ $x=$sel[0]; "  {0}: min={1} n={2}`n    B={3}`n    E={4}`n    D={5} K={6}" -f $cc,$x.S,$sel.Count,$x.B,$x.E,$x.D,$x.K }
  }
 }
}
Parse 'D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\runs\no_bot_legacy_004\final_timing.rpt' 'FAIL'
Parse 'D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\runs\hdmi_probe_001\final_timing.rpt' 'PASS'
