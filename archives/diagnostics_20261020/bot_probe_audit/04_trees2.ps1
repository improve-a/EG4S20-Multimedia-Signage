[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Stop'
$repo = 'D:\FPGA\EG4S20-NoBot-HDMIProbe'
$C = '42de1dbe4a20ca78f28be54c4bf41bd0dd814481'
Write-Output "=== TREE tb ==="
git -C $repo --no-pager ls-tree -r --name-only $C -- tb
Write-Output "=== TREE tests ==="
git -C $repo --no-pager ls-tree -r --name-only $C -- tests
Write-Output "=== TREE scripts ==="
git -C $repo --no-pager ls-tree -r --name-only $C -- scripts
Write-Output "=== TREE docs ==="
git -C $repo --no-pager ls-tree -r --name-only $C -- docs
Write-Output "=== TREE harness ==="
git -C $repo --no-pager ls-tree -r --name-only $C -- harness
Write-Output "=== TREE output ==="
git -C $repo --no-pager ls-tree -r --name-only $C -- output
Write-Output "=== DONE ==="
