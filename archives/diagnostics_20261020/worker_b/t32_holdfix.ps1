$ErrorActionPreference='Stop'
$sets=@(
 @('FAIL','D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\runs\no_bot_legacy_004'),
 @('PASS','D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\runs\hdmi_probe_001'))
foreach($p in $sets){
 $t=$p[0];$d=$p[1]
 "##### $t hashes"
 foreach($n in @('final_timing.rpt','after_hold_fix.rpt','before_hold_fix.rpt')){ $h=(Get-FileHash -Algorithm SHA256 "$d\$n").Hash.Substring(0,16); "$n $h" }
 "##### $t BEFORE status"
 Get-Content "$d\before_hold_fix.rpt" -TotalCount 32 | Select-Object -Skip 14
 "##### $t BEFORE clock table"
 Get-Content "$d\before_hold_fix.rpt" -TotalCount 52 | Select-Object -Skip 34
}
