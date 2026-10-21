[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Stop'
$repo = 'D:\FPGA\EG4S20-NoBot-HDMIProbe'
Write-Output "=== REPO $repo ==="
git -C $repo rev-parse HEAD
git -C $repo rev-parse --abbrev-ref HEAD
Write-Output "=== STATUS (porcelain, no optional locks) ==="
git -C $repo --no-optional-locks status --porcelain
Write-Output "=== LOG 12 ==="
git -C $repo --no-pager log --oneline -n 12 --decorate
Write-Output "=== SHOW 42de1db (stat) ==="
git -C $repo --no-pager show --stat --oneline 42de1dbe4a20ca78f28be54c4bf41bd0dd814481
Write-Output "=== NAME-STATUS of that commit ==="
git -C $repo --no-pager show --name-status --format=%H%n%P%n%an%n%ad%n%s 42de1dbe4a20ca78f28be54c4bf41bd0dd814481
Write-Output "=== TAGS pointing near ==="
git -C $repo tag -l --format='%(refname:short) %(objectname) %(*objectname)'
Write-Output "=== BRANCHES ==="
git -C $repo branch -a -v
Write-Output "=== DONE ==="
