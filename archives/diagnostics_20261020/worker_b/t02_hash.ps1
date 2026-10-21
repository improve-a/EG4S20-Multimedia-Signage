$ErrorActionPreference='Stop'
$files=@(
 'D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\td_project\hx4s20_basic_Runs\phy_1\hx4s20_basic.bit',
 'D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\td_project\hx4s20_basic_Runs\best_result\hx4s20_basic.bit',
 'D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design\td_project\hx4s20_basic_Runs\phy_1\hx4s20_basic.bit',
 'D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design\td_project\hx4s20_basic_Runs\best_result\hx4s20_basic.bit',
 'D:\FPGA\EG4S20-NoBot-Frozen\probe_hw_pass_20261020\bit\hdmi_probe_001.bit')
foreach($f in $files){ if(Test-Path $f){ $h=(Get-FileHash -Algorithm SHA256 $f).Hash.ToLower(); $i=Get-Item $f; "OK  $($i.Length) $h $f" } else { "MISS $f" } }
