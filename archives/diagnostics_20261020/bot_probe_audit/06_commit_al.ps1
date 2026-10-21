[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Stop'
$repo = 'D:\FPGA\EG4S20-NoBot-HDMIProbe'
$C = '42de1dbe4a20ca78f28be54c4bf41bd0dd814481'
Write-Output "=== DIFF 72e5c80..42de1db scripts/apply_hdmi_probe.py ==="
git -C $repo --no-pager diff 72e5c80e223f53953f6bb7b53dbb704e41d7c2d6 $C -- scripts/apply_hdmi_probe.py
Write-Output "=== DIFF 72e5c80..42de1db project .al (only +/- lines referencing hdmi_probe or Path or File) ==="
git -C $repo --no-pager diff 72e5c80e223f53953f6bb7b53dbb704e41d7c2d6 $C -- project/td_project/hx4s20_basic.al | Select-String -Pattern 'hdmi_probe|<Project |CompileOrder|DiskUsage|UsedInSyn' | Select-Object -First 20
Write-Output "=== .al at C: hdmi_probe entry with context ==="
$al = git -C $repo --no-pager show ($C + ':project/td_project/hx4s20_basic.al')
$i = 0
for ($i=0; $i -lt $al.Count; $i++) { if ($al[$i] -match 'hdmi_probe') { $s=[Math]::Max(0,$i-4); $e=[Math]::Min($al.Count-1,$i+6); $s..$e | ForEach-Object { Write-Output ("{0}: {1}" -f $_, $al[$_]) }; Write-Output '---' } }
Write-Output "=== .al header lines 1..8 ==="
$al[0..7] | ForEach-Object { Write-Output $_ }
Write-Output "=== .al total lines ==="
$al.Count
Write-Output "=== DONE ==="
