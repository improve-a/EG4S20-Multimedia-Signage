$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
[Console]::OutputEncoding=New-Object System.Text.UTF8Encoding($false)
$d=Get-Disk -Number (Get-Partition -DriveLetter K).DiskNumber
if($d.Number -ne 3 -or $d.SerialNumber -ne '000000001532') {throw 'Card identity changed'}
Write-VolumeCache -DriveLetter K -ErrorAction Stop
$r=[ordered]@{utc=[DateTime]::UtcNow.ToString('o');pid=$PID;operation='Write-VolumeCache -DriveLetter K';cache_flush='PASS';harness_file_handles='closed';os_ejected=$false;volume=(Get-Volume -DriveLetter K|Select-Object DriveLetter,FileSystem,HealthStatus,SizeRemaining)}
$r|ConvertTo-Json -Depth 4|Set-Content 'D:\FPGA\hx4s20_tf_test_20261013\final_flush_after_relocation.json' -Encoding utf8
$r|ConvertTo-Json -Depth 4
