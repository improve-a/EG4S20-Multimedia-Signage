$f='D:\FPGA\EG4S20-NoBot-Frozen\probe_hw_pass_20261020'
$n='D:\FPGA\EG4S20-NoBot'
$p='D:\FPGA\EG4S20-NoBot-HDMIProbe'
foreach($file in @("$n\AGENTS.md","$f\ASTRA_HANDOFF.md","$f\FROZEN_MANIFEST.json","$f\SHA256SUMS.txt","$f\delivery\manifest.json","$f\delivery\HDMI_PROBE_BUILD.md","$n\docs\no_bot_legacy_delivery.md")) {
  Write-Output "=== FILE $file ==="; Get-Content -Encoding UTF8 $file
}
Write-Output '=== TAG/BUNDLE ==='
git -C $p show --no-patch hw-pass-no-bot-probe-20261020
git -C $p bundle verify "$f\git\probe_hw_pass_20261020.bundle" 2>&1 | ForEach-Object { "$_" }
Write-Output '=== DELIVERY MANIFESTS ==='
Get-ChildItem "$n\output\html_fidelity" -Recurse -File -Filter '*manifest*.json' | Where-Object { $_.FullName -notmatch '\\work\\|\\assets\\|\\sim' } | ForEach-Object { $_.FullName }
Write-Output '=== PROBE BUILD CONTENTS ==='
Get-ChildItem "$p\output\hdmi_probe" -Directory -Recurse | Where-Object { $_.FullName -notmatch '\\work\\design\\user_source' } | ForEach-Object {$_.FullName}
Write-Output '=== SOURCE FROZEN ==='
Get-ChildItem "$f\source" -Recurse -File | ForEach-Object { "$($_.FullName) $($_.Length)" }
