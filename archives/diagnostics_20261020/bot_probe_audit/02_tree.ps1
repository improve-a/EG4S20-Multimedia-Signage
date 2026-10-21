[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Stop'
$repo = 'D:\FPGA\EG4S20-NoBot-HDMIProbe'
$base = '72e5c80e223f53953f6bb7b53dbb704e41d7c2d6'
Write-Output "=== SHOW 72e5c80 stat ==="
git -C $repo --no-pager show --stat --oneline $base
Write-Output "=== TREE 42de1db top level ==="
git -C $repo --no-pager ls-tree 42de1dbe4a20ca78f28be54c4bf41bd0dd814481
Write-Output "=== TREE 42de1db project/user_source/hdl_source/ext ==="
git -C $repo --no-pager ls-tree -r 42de1dbe4a20ca78f28be54c4bf41bd0dd814481 -- project/user_source/hdl_source/ext
Write-Output "=== DIFF 72e5c80^ vs 42de1db hdl_source only ==="
git -C $repo --no-pager diff --stat 72e5c80^ 42de1dbe4a20ca78f28be54c4bf41bd0dd814481 -- project/user_source
Write-Output "=== DIFF 72e5c80^ vs 42de1db whole repo except .al ==="
git -C $repo --no-pager diff --stat 72e5c80^ 42de1dbe4a20ca78f28be54c4bf41bd0dd814481
Write-Output "=== DONE ==="
