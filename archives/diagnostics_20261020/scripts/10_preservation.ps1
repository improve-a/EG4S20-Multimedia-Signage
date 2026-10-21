$f='D:\FPGA\EG4S20-NoBot-Frozen\probe_hw_pass_20261020'
$count=0
Get-Content "$f\SHA256SUMS.txt" | ForEach-Object {
 if($_ -match '^([a-f0-9]{64})  (.+)$') {
  $expected=$matches[1];$file=$matches[2]
  if((Get-FileHash -Algorithm SHA256 (Join-Path $f $file)).Hash.ToLower() -ne $expected){throw "Frozen hash changed: $file"}
  $count++
 }
}
Write-Output "PRESERVATION_PASS: $count frozen hashes unchanged"
foreach($r in @('D:\FPGA\EG4S20-NoBot','D:\FPGA\EG4S20-NoBot-HDMIProbe')) {
 Write-Output "STATUS $r"
 git -C $r status --short
 git -C $r rev-parse HEAD
}
Get-FileHash -Algorithm SHA256 'D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\td_project\hx4s20_basic_Runs\phy_1\hx4s20_basic.bit','D:\FPGA\EG4S20-NoBot-HDMIProbe\output\hdmi_probe\delivery\hdmi_probe_001.bit' | ForEach-Object {"$($_.Hash) $($_.Path)"}
