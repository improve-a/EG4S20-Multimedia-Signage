$ErrorActionPreference='Stop'
function Summarize($f,$tag){
 "##### $tag $f"
 $L=Get-Content $f
 $cur=$null; $rec=$null; $i=0
 $groups=@{}
 $order=@()
 $g=$null
 foreach($line in $L){
  $i++
  if($line -match '^Path Group\s+:\s+(.+)$'){ $g=$Matches[1].Trim(); if(-not $groups.ContainsKey($g)){ $groups[$g]=[pscustomobject]@{Name=$g;From='';To='';MinPeriod='';Fmax='';Count=0;MinSlack=999.0;Begin='';End='';Check='';Delay='';Skew=''}; $order+=$g } ; $rec=$null; continue }
  if($g -eq $null){continue}
  if($line -match '^From Clock\s+:\s+(.+)$'){ $groups[$g].From=$Matches[1].Trim(); continue }
  if($line -match '^To Clock\s+:\s+(.+)$'){ $groups[$g].To=$Matches[1].Trim(); continue }
  if($line -match '^Min Period\s+:\s+(.+)$'){ $groups[$g].MinPeriod=$Matches[1].Trim(); continue }
  if($line -match '^Fmax\s+:\s+(.+)$'){ $groups[$g].Fmax=$Matches[1].Trim(); continue }
  if($line -match '^Slack\s+:\s+(-?[0-9.]+)ns'){ $rec=[pscustomobject]@{Slack=[double]$Matches[1];Begin='';End='';Check='';Delay='';Skew=''}; $groups[$g].Count++; continue }
  if($rec -ne $null){
   if($line -match '^Begin Point\s+:\s+(.+)$'){ $rec.Begin=$Matches[1].Trim(); continue }
   if($line -match '^End Point\s+:\s+(.+)$'){ $rec.End=$Matches[1].Trim(); continue }
   if($line -match '^Check Type\s+:\s+(.+)$'){ $rec.Check=$Matches[1].Trim(); continue }
   if($line -match '^Data Path Delay\s+:\s+(.+)$'){ $rec.Delay=$Matches[1].Trim(); continue }
   if($line -match '^Clock Skew\s+:\s+(.+)$'){ $rec.Skew=$Matches[1].Trim()
     if($rec.Slack -lt $groups[$g].MinSlack){
       $groups[$g].MinSlack=$rec.Slack;$groups[$g].Begin=$rec.Begin;$groups[$g].End=$rec.End;$groups[$g].Check=$rec.Check;$groups[$g].Delay=$rec.Delay;$groups[$g].Skew=$rec.Skew }
     $rec=$null; continue }
  }
 }
 foreach($n in $order){ $r=$groups[$n]; "{0}`tfrom={1}`tto={2}`tminper={3}`tfmax={4}`tn={5}`tmin={6}`tcheck={7}`tdelay={8}`tskew={9}`n  B={10}`n  E={11}" -f $r.Name,$r.From,$r.To,$r.MinPeriod,$r.Fmax,$r.Count,$r.MinSlack,$r.Check,$r.Delay,$r.Skew,$r.Begin,$r.End }
}
Summarize 'D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\runs\no_bot_legacy_004\final_timing.rpt' 'FAIL'
Summarize 'D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\runs\hdmi_probe_001\final_timing.rpt' 'PASS'
