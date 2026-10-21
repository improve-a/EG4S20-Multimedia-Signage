$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$r='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\td_project\hx4s20_basic_Runs'
foreach($d in @('syn_1','phy_1','best_result')){
 "===== $d"
 Get-ChildItem -Force "$r\$d" -ErrorAction SilentlyContinue | Select-Object Mode,Length,LastWriteTime,Name | Format-Table -AutoSize | Out-String -Width 250
}
