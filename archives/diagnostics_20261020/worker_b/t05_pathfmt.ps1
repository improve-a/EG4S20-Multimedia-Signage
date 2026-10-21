$ErrorActionPreference='Stop'
$f='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\runs\no_bot_legacy_004\final_timing.rpt'
$L=Get-Content $f
$L[82..190]
