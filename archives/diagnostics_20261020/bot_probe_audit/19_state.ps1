[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Stop'
$src = 'D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design\user_source\hdl_source'
$t = Get-Content -LiteralPath (Join-Path $src 'top_tf_hdmi_audio.v')
Write-Output "=== state_code / display_state / led readers in pass top ==="
for ($i = 0; $i -lt $t.Count; $i++) { if ($t[$i] -match 'state_code|display_state|LED|led') { Write-Output ("{0}: {1}" -f ($i + 1), $t[$i].TrimEnd()) } }
Write-Output "=== reset_sync module ==="
Get-Content -LiteralPath (Join-Path $src 'reset_sync.v')
Write-Output "=== DONE ==="
