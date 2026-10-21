$f='D:\FPGA\EG4S20-NoBot-Frozen\probe_hw_pass_20261020'
$n='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004'
$p='D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001'
Write-Output '=== VERIFY FROZEN SHA256SUMS ==='
$count=0
Get-Content "$f\SHA256SUMS.txt" | ForEach-Object {
 if ($_ -match '^([a-f0-9]{64})  (.+)$') {
  $expected=$matches[1]; $name=$matches[2]; $h=(Get-FileHash -Algorithm SHA256 (Join-Path $f $name)).Hash.ToLower()
  if($h -ne $expected) { throw "HASH MISMATCH $name" }; $count++
 }
}
Write-Output "PASS $count frozen hashes"
foreach($b in @($n,$p)) {
 Write-Output "=== BUILD $b ==="
 Get-ChildItem $b -Force | ForEach-Object {"$($_.Name) $($_.Length)"}
 $id=Split-Path $b -Leaf
 foreach($name in @('status.json','job.json','inputs.json','artifacts.json')) {
  $path="$b\runs\$id\$name"
  if(Test-Path $path) { Write-Output "=== $path ==="; Get-Content $path -Encoding UTF8 }
 }
 Get-ChildItem "$b\work\design\td_project\hx4s20_basic_Runs" -Recurse -File | ForEach-Object {"ARTIFACT $($_.FullName) $($_.Length)"}
 Get-FileHash -Algorithm SHA256 "$b\work\design\td_project\hx4s20_basic_Runs\phy_1\hx4s20_basic.bit" | Format-List
}
Write-Output '=== HARDWARE PROGRAM FILE REFERENCES ==='
Get-Content 'D:\FPGA\EG4S20-NoBot\output\hardware\no_bot_retest_20261019T152547Z\sram.tcl'
Write-Output '=== BUILD SCRIPTS ==='
Get-ChildItem 'D:\FPGA\EG4S20-NoBot-HDMIProbe\scripts' -File | ForEach-Object {$_.Name}
Get-Content 'D:\FPGA\EG4S20-NoBot-HDMIProbe\harness\build.tcl'
