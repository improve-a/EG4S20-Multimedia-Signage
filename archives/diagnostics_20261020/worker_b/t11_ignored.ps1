$ErrorActionPreference='Stop'
foreach($p in @(@('FAIL','D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\runs\no_bot_legacy_004'),@('PASS','D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\runs\hdmi_probe_001'))){
 $t=$p[0];$d=$p[1]
 "##### $t ignored_timing head"
 Get-Content "$d\ignored_timing.rpt" -TotalCount 45
 "##### $t ignored sections"
 Select-String -Path "$d\ignored_timing.rpt" -Pattern '^(Table of Contents|\d+\.\s|Path Group|---)' | Select-Object -First 30 | ForEach-Object { "{0}: {1}" -f $_.LineNumber,$_.Line }
 "##### $t exceptions head"
 Get-Content "$d\exceptions.rpt" -TotalCount 25
 "##### $t exceptions section lines"
 Select-String -Path "$d\exceptions.rpt" -Pattern '^(Table of Contents|\d+\.\s|Path Group|Slack)' | Select-Object -First 25 | ForEach-Object { "{0}: {1}" -f $_.LineNumber,$_.Line }
}
