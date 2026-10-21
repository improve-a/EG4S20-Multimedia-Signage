[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Stop'
$src = 'D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design\user_source\hdl_source'
$p = Join-Path $src 'top_tf_hdmi_audio.v'
$t = Get-Content -LiteralPath $p
$pat = 'state_code50|fifo_fault_sync|axis_s_user|axis_s_last|seg_decoder|seg_scan|seg_data|seg_sel|probe_'
for ($i = 0; $i -lt $t.Count; $i++) { if ($t[$i] -match $pat) { Write-Output ("{0}: {1}" -f ($i + 1), $t[$i].TrimEnd()) } }
Write-Output "=== files defining seg_decoder / seg_scan ==="
Get-ChildItem -LiteralPath $src -Recurse -File -Filter *.v | ForEach-Object { $c = Get-Content -LiteralPath $_.FullName -Raw; if ($c -match 'module\s+seg_decoder|module\s+seg_scan') { Write-Output ("FILE " + $_.FullName) } }
Write-Output "=== DONE ==="
