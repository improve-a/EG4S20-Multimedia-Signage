$ErrorActionPreference='Stop'
foreach($b in @('D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004','D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001')){
 "##### $b\timing.sdc"
 Get-Content "$b\work\design\user_source\constraints_source\timing.sdc"
 "##### pins.adc diff marker"
 Get-FileHash "$b\work\design\user_source\constraints_source\pin.adc"
}
