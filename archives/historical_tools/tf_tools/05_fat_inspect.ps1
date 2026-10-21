$ErrorActionPreference='Stop'
[Console]::OutputEncoding=New-Object System.Text.UTF8Encoding($false)
$env:PYTHONIOENCODING='utf-8'
$d=Get-Disk -Number (Get-Partition -DriveLetter K).DiskNumber
if($d.Number -ne 3 -or $d.SerialNumber -ne '000000001532') {throw 'Card identity changed'}
python 'D:\FPGA\hx4s20_tf_test_20261013\05_fat_inspect.py'
exit $LASTEXITCODE
