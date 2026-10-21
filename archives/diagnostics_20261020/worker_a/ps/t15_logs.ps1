$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$a='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\td_project\hx4s20_basic_Runs\syn_1'
$b='D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design\td_project\hx4s20_basic_Runs\syn_1'
"### A run.log WARN/ERROR"
Select-String -Path "$a\run.log" -Pattern 'WARN|ERROR|unused|unconnect|optimiz|remov|constant|tie|float|dangl' -CaseSensitive:$false | ForEach-Object { $_.LineNumber.ToString()+": "+$_.Line.Trim() } | Select-Object -First 120
"### B run.log WARN/ERROR"
Select-String -Path "$b\run.log" -Pattern 'WARN|ERROR|unused|unconnect|optimiz|remov|constant|tie|float|dangl' -CaseSensitive:$false | ForEach-Object { $_.LineNumber.ToString()+": "+$_.Line.Trim() } | Select-Object -First 120
