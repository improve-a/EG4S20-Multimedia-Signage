$ErrorActionPreference='Stop'
[Console]::OutputEncoding=New-Object System.Text.UTF8Encoding($false)
$env:PYTHONIOENCODING='utf-8'
$p=Get-Partition -DriveLetter K
$d=Get-Disk -Number $p.DiskNumber
$v=Get-Volume -DriveLetter K
if($d.Number -ne 3 -or $d.SerialNumber -ne '000000001532' -or $p.Offset -ne 4194304 -or $v.FileSystem -ne 'FAT32' -or $v.UniqueId -ne '\\?\Volume{6ffd0c2a-c496-11f1-ad57-8ce9eefad457}\') {throw 'Card identity changed'}
python 'D:\FPGA\hx4s20_tf_test_20261013\06_copy.py'
exit $LASTEXITCODE
