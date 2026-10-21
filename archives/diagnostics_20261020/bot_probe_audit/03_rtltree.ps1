[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Stop'
$repo = 'D:\FPGA\EG4S20-NoBot-HDMIProbe'
$C = '42de1dbe4a20ca78f28be54c4bf41bd0dd814481'
Write-Output "=== FULL TREE rtl ==="
git -C $repo --no-pager ls-tree -r $C -- rtl
Write-Output "=== FULL TREE project (names only) ==="
git -C $repo --no-pager ls-tree -r --name-only $C -- project
Write-Output "=== FULL TREE project/user_source ==="
git -C $repo --no-pager ls-tree -r --name-only $C -- project/user_source
Write-Output "=== DIRS project ==="
git -C $repo --no-pager ls-tree $C -- project
Write-Output "=== DONE ==="
