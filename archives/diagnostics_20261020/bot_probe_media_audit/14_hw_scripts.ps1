[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
Write-Output "=== script files mentioning programmer/jtag/download in repos ==="
foreach ($r in @('D:\FPGA\EG4S20-Multimedia-Signage','D:\FPGA\EG4S20-NoBot-HDMIProbe','D:\FPGA\EG4S20-Bot-HDMIProbe')) {
  Write-Output ("--- " + $r)
  Get-ChildItem -LiteralPath $r -Recurse -File -ErrorAction SilentlyContinue -Include '*.py','*.ps1','*.tcl','*.bat','*.cmd','*.md' |
    Where-Object { $_.FullName -notmatch '\\output\\|\\artifacts\\' -and $_.Length -lt 500000 } |
    Select-String -Pattern 'td_programmer|Programmer|openFPGALoader|jtag|JTAG|download|烧录|下载' -List -ErrorAction SilentlyContinue |
    ForEach-Object { $_.Path.Substring($r.Length+1) } | Sort-Object
}
Write-Output "=== DONE ==="
