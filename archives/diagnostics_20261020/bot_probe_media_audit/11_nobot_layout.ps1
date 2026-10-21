[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
$r = 'D:\FPGA\EG4S20-NoBot-HDMIProbe'
Write-Output "=== GIT ==="
git -C $r rev-parse --abbrev-ref HEAD 2>&1
git -C $r rev-parse HEAD 2>&1
git -C $r log --oneline -5 2>&1
git -C $r status --porcelain=v1 2>&1 | Select-Object -First 20
Write-Output "=== TOP ==="
Get-ChildItem -LiteralPath $r -Force | ForEach-Object { "{0} {1,10} {2}" -f $(if($_.PSIsContainer){'DIR '}else{'FILE'}), $(if($_.PSIsContainer){''}else{$_.Length}), $_.Name }
Write-Output "=== rtl/SD ==="
Get-ChildItem -LiteralPath "$r\rtl\SD" -File -ErrorAction SilentlyContinue | ForEach-Object { "{0,9} {1}" -f $_.Length, $_.Name }
Write-Output "=== output/html_fidelity/no_bot (if any) ==="
if (Test-Path "$r\output\html_fidelity\no_bot") {
  Get-ChildItem -LiteralPath "$r\output\html_fidelity\no_bot" -Recurse -File | ForEach-Object { "{0,10} {1}" -f $_.Length, $_.FullName.Substring($r.Length+1) }
} else { Write-Output "MISSING" }
Write-Output "=== any .img in repo ==="
Get-ChildItem -LiteralPath $r -Recurse -File -Include '*.img' -ErrorAction SilentlyContinue | ForEach-Object { "{0,12} {1} {2}" -f $_.Length, $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm'), $_.FullName }
Write-Output "=== DONE ==="
