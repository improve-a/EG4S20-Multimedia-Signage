[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Stop'
$p = 'D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design\user_source\hdl_source\top_tf_hdmi_audio.v'
$t = Get-Content -LiteralPath $p
Write-Output ("TOTAL LINES " + $t.Count)
$pat = 'display_state|seg_data_0|button_reset50|sys_pll_lock|video_pll_lock|fx_hs|audio_valid'
for ($i = 0; $i -lt $t.Count; $i++) { if ($t[$i] -match $pat) { Write-Output ("{0}: {1}" -f ($i + 1), $t[$i].TrimEnd()) } }
Write-Output "=== DONE ==="
