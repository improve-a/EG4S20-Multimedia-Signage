$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$roots=@('D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004','D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001')
foreach($r in $roots){
 "===== $r"
 Get-ChildItem -Recurse -File $r -Include *_map.v,*_map*.v,*.vm,*_syn.v,*_routed*.v,*.v -ErrorAction SilentlyContinue |
   Where-Object { $_.FullName -notmatch '\\src\\|\\source\\' } |
   Select-Object Length,LastWriteTime,FullName | Sort-Object FullName | Format-Table -AutoSize | Out-String -Width 300
}
