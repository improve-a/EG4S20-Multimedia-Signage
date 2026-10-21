$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
[Console]::OutputEncoding=New-Object System.Text.UTF8Encoding($false)
$env:PYTHONIOENCODING='utf-8'
$d=Get-Disk -Number (Get-Partition -DriveLetter K).DiskNumber
if($d.Number -ne 3 -or $d.SerialNumber -ne '000000001532') {throw 'Card identity changed'}
$c=Get-Command Write-VolumeCache -ErrorAction SilentlyContinue
if($c) {Write-VolumeCache -DriveLetter K; Write-Output 'Write-VolumeCache K completed'}
python 'D:\FPGA\hx4s20_tf_test_20261013\10_layout_plan.py'
exit $LASTEXITCODE
