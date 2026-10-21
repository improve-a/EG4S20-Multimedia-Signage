$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$r='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\td_project'
Get-ChildItem -Force $r | Select-Object Mode,Length,LastWriteTime,Name | Format-Table -AutoSize | Out-String -Width 200
"--- runs"
Get-ChildItem -Recurse -Depth 1 -Directory $r -ErrorAction SilentlyContinue | Select-Object FullName | Out-String -Width 300
