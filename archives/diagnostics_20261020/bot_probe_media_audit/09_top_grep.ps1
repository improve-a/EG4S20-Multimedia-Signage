[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
$r = 'D:\FPGA\EG4S20-Multimedia-Signage'
Write-Output "=== scene_loader / sector0 refs in rtl & top ==="
Get-ChildItem -LiteralPath $r -Recurse -File -Include '*.v','*.sv' -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -notmatch '\\output\\' } |
  Select-String -Pattern 'html_scene_loader|sector0|scene_sector0' -ErrorAction SilentlyContinue |
  ForEach-Object { "{0}:{1}: {2}" -f $_.Path.Substring($r.Length+1), $_.LineNumber, $_.Line.Trim() }
Write-Output "=== HFXL builder script head ==="
Get-Content -LiteralPath "$r\scripts\html_fidelity_hfxl_containers.py" -TotalCount 90 -Encoding UTF8
Write-Output "=== DONE ==="
