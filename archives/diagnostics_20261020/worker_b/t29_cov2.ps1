$ErrorActionPreference='Stop'
$d='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\runs\no_bot_legacy_004'
$L=Get-Content "$d\check_timing.rpt"
"total=" + $L.Count
$L | Select-Object -Last 170
