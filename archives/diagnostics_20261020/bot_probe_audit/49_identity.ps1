[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
Write-Output "=== zip hashes ==="
foreach ($z in @('D:\FPGA\EG4S20-Bot-HDMIProbe\artifacts\bot_hdmi_probe_001_source.zip','D:\FPGA\EG4S20-Multimedia-Signage\artifacts\timing_fix_20261016_02_source.zip','D:\FPGA\EG4S20-NoBot-HDMIProbe\artifacts\hdmi_probe_001_source.zip')) { Write-Output ((Get-FileHash -Algorithm SHA256 -LiteralPath $z).Hash.ToLower() + "  " + $z) }
Write-Output "=== git object 9a27bbe7 in Bot-HDMIProbe (object read only, no status) ==="
$repo = 'D:\FPGA\EG4S20-Bot-HDMIProbe'
Write-Output ("type: " + (git -C $repo cat-file -t 9a27bbe73079d987bb4592b6a724b07cc33e5d9e 2>&1))
git -C $repo --no-pager show -s --format='%H%n%P%n%an%n%ad%n%s' 9a27bbe73079d987bb4592b6a724b07cc33e5d9e 2>&1
Write-Output "=== does Bot repo tree contain the probe module and .al entry? ==="
git -C $repo --no-pager ls-tree -r --name-only 9a27bbe73079d987bb4592b6a724b07cc33e5d9e 2>&1 | Select-String -Pattern 'hdmi_probe|hx4s20_basic.al|bot_probe_build|bot_top' | Select-Object -First 12
Write-Output "=== ext module inventory (new zip) ==="
