[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
Write-Output "=== HOST ==="
hostname
(Get-Date).ToString('o')
Write-Output "=== ROOTS ==="
foreach ($p in @('D:\FPGA\EG4S20-Multimedia-Signage','D:\FPGA\EG4S20-NoBot-HDMIProbe','D:\FPGA\EG4S20-Bot-HDMIProbe')) {
  if (Test-Path $p) { Write-Output ("EXISTS  " + $p) } else { Write-Output ("MISSING " + $p) }
}
Write-Output "=== VOLUMES ==="
Get-Volume | Select-Object DriveLetter,FileSystemLabel,FileSystem,DriveType,HealthStatus,@{n='SizeGB';e={[math]::Round($_.Size/1GB,2)}},@{n='FreeGB';e={[math]::Round($_.SizeRemaining/1GB,2)}} | Format-Table -AutoSize | Out-String -Width 200
Write-Output "=== DISKS ==="
Get-Disk | Select-Object Number,FriendlyName,BusType,OperationalStatus,PartitionStyle,@{n='SizeGB';e={[math]::Round($_.Size/1GB,2)}} | Format-Table -AutoSize | Out-String -Width 200
