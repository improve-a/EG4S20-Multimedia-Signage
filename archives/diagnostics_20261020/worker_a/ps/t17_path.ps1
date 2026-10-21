$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$a='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\td_project\hx4s20_basic_Runs\syn_1\hx4s20_basic_gate.timing'
Get-Content $a -TotalCount 200 | Select-Object -Skip 90
