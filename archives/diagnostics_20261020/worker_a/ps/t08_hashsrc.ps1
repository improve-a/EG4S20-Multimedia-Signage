$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$a='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\user_source\hdl_source'
$b='D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design\user_source\hdl_source'
function GetSrcH($root){ Get-ChildItem -Recurse -File $root | ForEach-Object { [pscustomobject]@{rel=$_.FullName.Substring($root.Length+1).Replace('\','/'); len=$_.Length; sha=(Get-FileHash $_.FullName -Algorithm SHA256).Hash} } }
$ha=GetSrcH $a; $hb=GetSrcH $b
$ma=@{}; $ha|%{$ma[$_.rel]=$_}
$mb=@{}; $hb|%{$mb[$_.rel]=$_}
$all=($ma.Keys+$mb.Keys)|Sort-Object -Unique
foreach($k in $all){
  $x=$ma[$k]; $y=$mb[$k]
  if(-not $x){"ONLY_B $k $($y.len) $($y.sha)"}
  elseif(-not $y){"ONLY_A $k $($x.len) $($x.sha)"}
  elseif($x.sha -ne $y.sha){"DIFF $k A=$($x.len)/$($x.sha.Substring(0,12)) B=$($y.len)/$($y.sha.Substring(0,12))"}
}
"A_count=$($ha.Count) B_count=$($hb.Count)"
