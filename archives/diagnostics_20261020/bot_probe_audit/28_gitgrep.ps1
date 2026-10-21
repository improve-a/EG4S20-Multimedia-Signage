[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Stop'
$repo = 'D:\FPGA\EG4S20-NoBot-HDMIProbe'
$C = '42de1dbe4a20ca78f28be54c4bf41bd0dd814481'
Write-Output "=== module seg_decoder / seg_scan in git tree ==="
git -C $repo --no-pager grep -l -E "module +seg_(decoder|scan)" $C
Write-Output ("exit=" + $LASTEXITCODE)
Write-Output "=== top_tf_hdmi_audio anywhere in git ==="
git -C $repo --no-pager ls-tree -r --name-only $C | Select-String -Pattern 'top_tf|top\.v'
Write-Output "=== DONE ==="
