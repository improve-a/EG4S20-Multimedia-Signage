[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
$roots = @('D:\FPGA\EG4S20-Multimedia-Signage','D:\FPGA\EG4S20-NoBot-HDMIProbe','D:\FPGA\EG4S20-Bot-HDMIProbe')
foreach ($r in $roots) {
  Write-Output ("=== HFXL in " + $r + " ===")
  Get-ChildItem -LiteralPath $r -Recurse -File -ErrorAction SilentlyContinue -Include '*.v','*.sv','*.vh','*.md','*.py','*.tcl','*.txt','*.json' |
    Where-Object { $_.FullName -notmatch '\\output\\' -and $_.Length -lt 2000000 } |
    Select-String -Pattern 'HFXL' -SimpleMatch -List -ErrorAction SilentlyContinue |
    ForEach-Object { $_.Path.Substring($r.Length).TrimStart('\') } | Sort-Object -Unique
}
Write-Output "=== WELCM / UI0 in source ==="
foreach ($r in $roots) {
  Write-Output ("--- " + $r)
  Get-ChildItem -LiteralPath $r -Recurse -File -ErrorAction SilentlyContinue -Include '*.v','*.sv','*.md','*.py','*.json','*.txt' |
    Where-Object { $_.FullName -notmatch '\\output\\' -and $_.Length -lt 2000000 } |
    Select-String -Pattern 'WELCM|UI0[1-6]' -List -ErrorAction SilentlyContinue |
    ForEach-Object { $_.Path.Substring($r.Length).TrimStart('\') } | Sort-Object -Unique
}
Write-Output "=== DONE ==="
