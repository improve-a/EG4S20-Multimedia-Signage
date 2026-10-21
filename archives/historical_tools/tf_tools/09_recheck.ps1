$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
[Console]::OutputEncoding=New-Object System.Text.UTF8Encoding($false)
$p=Get-Partition -DriveLetter K
$d=Get-Disk -Number $p.DiskNumber
$v=Get-Volume -DriveLetter K
if($d.Number -ne 3 -or $d.SerialNumber -ne '000000001532' -or $p.Offset -ne 4194304 -or $v.FileSystem -ne 'FAT32') {throw 'Card identity changed'}
$r=[ordered]@{utc=[DateTime]::UtcNow.ToString('o');pid=$PID;volume=($v|Select-Object DriveLetter,FileSystem,HealthStatus,SizeRemaining);files=@(Get-ChildItem 'K:\' -Force -Recurse -File|ForEach-Object {[ordered]@{path=$_.FullName;size=$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}})}
$r|ConvertTo-Json -Depth 6|Set-Content 'D:\FPGA\hx4s20_tf_test_20261013\recheck_after_user_delete.json' -Encoding utf8
$r|ConvertTo-Json -Depth 6
