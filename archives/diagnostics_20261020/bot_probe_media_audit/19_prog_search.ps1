[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
Write-Output "=== files with prog/download/jtag in name ==="
foreach ($r in @('D:\FPGA\EG4S20-Multimedia-Signage','D:\FPGA\EG4S20-NoBot','D:\FPGA\hx4s20_usb_jtag_harness_20261013')) {
  Write-Output ("--- " + $r)
  if (-not (Test-Path $r)) { Write-Output "MISSING"; continue }
  Get-ChildItem -LiteralPath $r -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match 'program|download|jtag|hw_server|hwserver|alps|svf2aje|bitgen|\.bit$' -and $_.FullName -notmatch '\\runs\\' } |
    Select-Object -First 40 | ForEach-Object { "{0,12} {1} {2}" -f $_.Length, $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm'), $_.FullName.Substring($r.Length+1) }
}
Write-Output "=== text refs to programmer tools ==="
foreach ($r in @('D:\FPGA\EG4S20-Multimedia-Signage','D:\FPGA\EG4S20-NoBot')) {
  Get-ChildItem -LiteralPath $r -Recurse -File -ErrorAction SilentlyContinue -Include '*.py','*.tcl','*.ps1','*.bat','*.cmd','*.md','*.json' |
    Where-Object { $_.FullName -notmatch '\\output\\|\\artifacts\\|\\evidence\\' -and $_.Length -lt 300000 } |
    Select-String -Pattern 'alps\.exe|hwserver|hw_server|svf2aje|td_commands_prompt|td_programmer|Programmer' -ErrorAction SilentlyContinue |
    ForEach-Object { "{0}:{1}: {2}" -f $_.Path.Substring($r.Length+1), $_.LineNumber, $_.Line.Trim() }
}
Write-Output "=== DONE ==="
