$ErrorActionPreference='Stop'
$f='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\runs\no_bot_legacy_004\final_timing.rpt'
"lines=" + (Get-Content $f | Measure-Object -Line).Lines
Get-Content $f -TotalCount 80
"### section-like lines"
Select-String -Path $f -Pattern '^(Table of Contents|[-=]{5,}|\d+\.\s|Clock Summary|Timing Summary|Setup|Hold|Recovery|Removal|WNS|TNS|Path Group|Slack)' | Select-Object -First 80 | ForEach-Object { "{0}: {1}" -f $_.LineNumber, $_.Line }
