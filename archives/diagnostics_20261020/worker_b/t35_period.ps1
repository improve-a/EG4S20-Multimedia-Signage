$ErrorActionPreference='Stop'
$f='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\runs\no_bot_legacy_004\final_timing.rpt'
Select-String -Path $f -Pattern 'Period Check|period check|Periodic|periodic|Minimum Period|minimum period' | Select-Object -First 20 | ForEach-Object { "{0}: {1}" -f $_.LineNumber,$_.Line.Trim() }
"---- context of first"
$L=Get-Content $f
$n=(Select-String -Path $f -Pattern 'Period Check' | Select-Object -First 1).LineNumber
if($n){ $L[($n-10)..($n+30)] }
