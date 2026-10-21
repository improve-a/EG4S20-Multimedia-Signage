$root='D:\FPGA\EG4S20-NoBot-RCA-20261020'
New-Item -ItemType Directory -Force "$root\scripts" | Out-Null
Write-Output '=== TOOLS ==='
Get-Command python,git | Select-Object Name,Source | Format-Table
Write-Output '=== VERIFY TAG ==='
git -C 'D:\FPGA\EG4S20-NoBot-HDMIProbe' rev-parse 'hw-pass-no-bot-probe-20261020^{}'
git -C 'D:\FPGA\EG4S20-NoBot-HDMIProbe' bundle verify 'D:\FPGA\EG4S20-NoBot-Frozen\probe_hw_pass_20261020\git\probe_hw_pass_20261020.bundle'
if($LASTEXITCODE -ne 0) {throw 'bundle failed'}
Write-Output '=== BUILD SCRIPT CONTENTS ==='
foreach($name in @('build.py','prepare_snapshot.py','apply_hdmi_probe.py','remote.py')) {
 Write-Output "=== $name ==="
 Get-Content "D:\FPGA\EG4S20-NoBot-HDMIProbe\scripts\$name" -Encoding UTF8
}
