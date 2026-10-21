[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
Write-Output "=== TD install candidates ==="
foreach ($p in @('C:\Anlogic','D:\Anlogic','C:\Program Files\Anlogic','C:\Program Files (x86)\Anlogic','D:\TD','C:\TD','D:\Program Files\Anlogic')) {
  if (Test-Path $p) { Write-Output ("EXISTS " + $p); Get-ChildItem -LiteralPath $p -Directory -ErrorAction SilentlyContinue | ForEach-Object { "   " + $_.Name } }
}
Write-Output "=== td_programmer.exe search (limited) ==="
$roots = @('C:\Anlogic','D:\Anlogic','C:\Program Files','C:\Program Files (x86)')
foreach ($p in $roots) {
  if (Test-Path $p) {
    Get-ChildItem -LiteralPath $p -Recurse -File -Filter 'td_programmer*.exe' -ErrorAction SilentlyContinue -Depth 6 |
      ForEach-Object { "{0,10} {1} {2}" -f $_.Length, $_.LastWriteTime.ToString('yyyy-MM-dd'), $_.FullName }
  }
}
Write-Output "=== TD version / install marker ==="
Get-ChildItem -LiteralPath 'C:\Anlogic' -Recurse -File -Filter '*version*.txt' -ErrorAction SilentlyContinue -Depth 4 | ForEach-Object { $_.FullName }
Write-Output "=== td_programmer on PATH ==="
$c = Get-Command td_programmer -ErrorAction SilentlyContinue
if ($c) { $c.Source } else { Write-Output "not on PATH" }
Write-Output "=== USB / JTAG devices ==="
Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
  Where-Object { $_.FriendlyName -match 'Anlogic|JTAG|FTDI|USB Serial|USB.*Cable|CP210|CH34|Altera|Xilinx' -or $_.Class -match 'USB' } |
  Select-Object Status,Class,FriendlyName,InstanceId | Format-Table -AutoSize | Out-String -Width 220
Write-Output "=== Disk drives ==="
Get-CimInstance Win32_DiskDrive | Select-Object Index,Model,InterfaceType,MediaType,@{n='GB';e={[math]::Round($_.Size/1GB,2)}},SerialNumber | Format-Table -AutoSize | Out-String -Width 220
Write-Output "=== Removable volumes / SD ==="
Get-CimInstance Win32_LogicalDisk | Select-Object DeviceID,DriveType,VolumeName,FileSystem,@{n='GB';e={[math]::Round($_.Size/1GB,2)}} | Format-Table -AutoSize | Out-String -Width 160
Write-Output "=== SD host controllers ==="
Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.Class -match 'SDHost|SCSIAdapter|DiskDrive|USB' } | Select-Object Status,Class,FriendlyName | Format-Table -AutoSize | Out-String -Width 200
Write-Output "=== DONE ==="
