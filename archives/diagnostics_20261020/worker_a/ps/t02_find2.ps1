$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$roots=@('D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004','D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001')
foreach($r in $roots){
 "===== $r"
 Get-ChildItem -Recurse -File $r -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match '_map|\.vm$|netlist|_syn|\.edf$|\.edn$|\.blif$' } |
  Select-Object Length,FullName | Sort-Object FullName | Format-Table -AutoSize | Out-String -Width 300
}
