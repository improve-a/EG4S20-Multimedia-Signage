[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Stop'
Write-Output "=== python ==="
python -c "import sys,zipfile,hashlib;print(sys.version)"
Write-Output "=== baseline_copies ==="
Get-ChildItem 'D:\FPGA\EG4S20-NoBot-RCA-20261020\baseline_copies' | Select-Object Name,Length | Format-Table -AutoSize
Write-Output "=== hashes of source zips ==="
Get-ChildItem 'D:\FPGA\EG4S20-NoBot-RCA-20261020\baseline_copies\*.zip' | ForEach-Object { $h=(Get-FileHash -Algorithm SHA256 $_.FullName).Hash; Write-Output ($h + '  ' + $_.Name) }
Write-Output "=== DONE ==="
