$ErrorActionPreference='Stop'
$d='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\runs\no_bot_legacy_004'
$L=Get-Content "$d\check_timing.rpt"
$start=($L | Select-String -Pattern '^10\. checking no input delay' | Select-Object -First 1).LineNumber
$start
$L[($start-1)..($L.Count-1)] | Select-Object -First 150
