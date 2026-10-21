$ErrorActionPreference='Stop'
foreach($p in @(@('FAIL','D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\runs\no_bot_legacy_004\final_timing.rpt'),@('PASS','D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\runs\hdmi_probe_001\final_timing.rpt'))){
 $L=Get-Content $p[1]
 $n=(Select-String -Path $p[1] -Pattern '^Period Check' | Select-Object -First 1).LineNumber
 "##### $($p[0]) at $n"
 $L[($n-4)..($n+40)]
}
