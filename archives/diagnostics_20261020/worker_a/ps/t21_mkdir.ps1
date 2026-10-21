$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$d='D:\FPGA\EG4S20-NoBot-RCA-20261020\worker_a'
if(-not (Test-Path $d)){ New-Item -ItemType Directory -Path $d -Force | Out-Null }
"created=" + (Test-Path $d)
Get-ChildItem 'D:\FPGA\EG4S20-NoBot-RCA-20261020' | Select-Object Mode,Name | Format-Table -AutoSize | Out-String -Width 120
