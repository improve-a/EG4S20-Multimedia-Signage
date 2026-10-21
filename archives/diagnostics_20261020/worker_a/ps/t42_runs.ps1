$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$a='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\runs'
$b='D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\runs'
foreach($p in @($a,$b)){
 "##### $p"
 Get-ChildItem -Recurse -File $p -ErrorAction SilentlyContinue | Select-Object Length,FullName | Format-Table -AutoSize | Out-String -Width 250
}
