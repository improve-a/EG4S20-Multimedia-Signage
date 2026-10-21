[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
$r='D:\FPGA\EG4S20-Bot-HDMIProbe'
Write-Output "=== git ==="
git -C $r rev-parse --abbrev-ref HEAD 2>&1
git -C $r rev-parse HEAD 2>&1
git -C $r status --porcelain=v1 2>&1 | Select-Object -First 15
Write-Output "=== top level ==="
Get-ChildItem -LiteralPath $r -Force | ForEach-Object { "{0} {1}" -f $(if($_.PSIsContainer){'DIR '}else{'FILE'}), $_.Name }
Write-Output "=== docs mentioning media/card ==="
Get-ChildItem -LiteralPath $r -Recurse -File -Include '*.md' -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -notmatch '\\output\\' } |
  Select-String -Pattern 'TF|卡|BMP|HFXL|media' -List | ForEach-Object { $_.Path.Substring($r.Length+1) } | Sort-Object -Unique
Write-Output "=== DONE ==="
