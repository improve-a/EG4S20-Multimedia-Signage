$ErrorActionPreference='Stop'
$d='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\runs\no_bot_legacy_004'
Get-Content "$d\final_area.rpt" | Select-Object -Skip 70 -First 60
"### markers"
Select-String -Path "$d\final_area.rpt" -Pattern '^(Module|Instance|Hierarchy|Resource|Area|Cell|Statistics)' | ForEach-Object { "{0}: {1}" -f $_.LineNumber,$_.Line }
