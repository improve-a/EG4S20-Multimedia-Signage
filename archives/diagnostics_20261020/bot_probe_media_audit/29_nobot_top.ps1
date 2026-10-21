[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
$r='D:\FPGA\EG4S20-NoBot-HDMIProbe'
Write-Output "=== NoBot rtl files ==="
Get-ChildItem -LiteralPath "$r\rtl" -File | ForEach-Object { "{0,9} {1}" -f $_.Length, $_.Name }
Write-Output "=== NoBot rtl\ext (count + scene/panel presence) ==="
$e = Get-ChildItem -LiteralPath "$r\rtl\ext" -File -ErrorAction SilentlyContinue
"count=" + $e.Count
$e | Where-Object { $_.Name -match 'scene|panel|layer|bmp|audio|wav|resource' } | ForEach-Object { "{0,9} {1}" -f $_.Length, $_.Name }
Write-Output "=== NoBot top-level module / params ==="
Get-ChildItem -LiteralPath $r -Recurse -File -Filter '*.v' | Where-Object { $_.FullName -notmatch '\\output\\|\\artifacts\\|\\tests\\|\\tb\\' } |
  Select-String -Pattern 'module top|ENABLE_LAYER_RESOURCES|ENABLE_EXHIBIT' | ForEach-Object { "{0}:{1}: {2}" -f $_.Path.Substring($r.Length+1), $_.LineNumber, $_.Line.Trim() }
Write-Output "=== old repo: which build used plain BMP (ext_full_005)? ==="
Get-ChildItem -LiteralPath 'D:\FPGA\EG4S20-Multimedia-Signage\output\html_fidelity\builds' -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'ext_full|full' } | ForEach-Object { $_.Name }
Write-Output "=== DONE ==="
