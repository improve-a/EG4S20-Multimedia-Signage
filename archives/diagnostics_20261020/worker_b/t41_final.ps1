$ErrorActionPreference='Stop'
$sets=@(
 @('FAIL','D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004'),
 @('PASS','D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001'))
foreach($p in $sets){
 $t=$p[0];$d=$p[1];$rid=if($t -eq 'FAIL'){'no_bot_legacy_004'}else{'hdmi_probe_001'}
 "##### $t"
 (Get-FileHash "$d\work\design\user_source\constraints_source\timing.sdc" -Algorithm SHA256).Hash.ToLower() + " timing.sdc"
 (Get-FileHash "$d\work\design\user_source\constraints_source\pin.adc" -Algorithm SHA256).Hash.ToLower() + " pin.adc"
 Get-Content "$d\runs\$rid\stages.tsv"
}
