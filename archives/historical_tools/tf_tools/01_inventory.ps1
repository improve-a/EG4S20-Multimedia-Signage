$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
[Console]::OutputEncoding=New-Object System.Text.UTF8Encoding($false)
$root='D:\FPGA\hx4s20_tf_test_20261013'
New-Item -ItemType Directory -Force $root | Out-Null
$base='G:\macshare\嵌赛\HX4S20_Contest_202606'
$card=@(Get-ChildItem 'K:\' -Force -Recurse -ErrorAction Stop | Select-Object FullName,Length,Attributes,LastWriteTimeUtc)
$card|ConvertTo-Json -Depth 4|Set-Content "$root\card_before_inventory.json" -Encoding utf8
$dirs=@(Get-ChildItem -LiteralPath $base -Force | Select-Object Name,FullName,Attributes)
$projects=@(Get-ChildItem -LiteralPath $base -Recurse -File | Where-Object {$_.Name -match '赛题|题一|HX4S20C|sd_read|sd_ctrl|bmp|BMP' -or $_.Extension -in '.zip','.rar','.7z'} | Select-Object FullName,Length)
$part=Get-Partition -DriveLetter K
$disk=Get-Disk -Number $part.DiskNumber
$r=[ordered]@{utc=[DateTime]::UtcNow.ToString('o');pid=$PID;volume=(Get-Volume -DriveLetter K|Select-Object DriveLetter,FileSystem,FileSystemLabel,Size,SizeRemaining,HealthStatus,UniqueId);partition=($part|Select-Object DiskNumber,PartitionNumber,Offset,Size,Type);disk=($disk|Select-Object Number,FriendlyName,SerialNumber,BusType,PartitionStyle,LogicalSectorSize,PhysicalSectorSize,Size,IsBoot,IsSystem);card_entry_count=$card.Count;card_entries=$card;source_dirs=$dirs;relevant_files=$projects}
$r|ConvertTo-Json -Depth 6|Tee-Object -FilePath "$root\inventory.json"
