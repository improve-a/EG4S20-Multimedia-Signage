[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
$r = 'D:\FPGA\EG4S20-Multimedia-Signage'
Write-Output "=== GIT STATE OLD ==="
git -C $r rev-parse --abbrev-ref HEAD
git -C $r rev-parse HEAD
git -C $r log --oneline -8
Write-Output "=== STATUS (short) ==="
git -C $r status --porcelain=v1 | Select-Object -First 40
Write-Output "=== 20871da ==="
git -C $r log --oneline -1 20871da 2>&1
git -C $r cat-file -t 20871da 2>&1
Write-Output "=== files changed in 20871da ==="
git -C $r show --stat --oneline 20871da 2>&1 | Select-Object -First 40
Write-Output "=== does 20871da contain scene_loader? ==="
git -C $r ls-tree -r --name-only 20871da 2>&1 | Select-String -Pattern 'html_scene_loader|html_resource_locator|hfxl|HFXL|no_bot' | ForEach-Object { $_.Line }
Write-Output "=== DONE ==="
