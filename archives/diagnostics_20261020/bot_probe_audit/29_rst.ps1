[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$p = 'D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design\user_source\hdl_source\top_tf_hdmi_audio.v'
$t = Get-Content -LiteralPath $p
for ($i = 0; $i -lt $t.Count; $i++) { if ($t[$i] -match 'rs_video|I_rst\b|video_rst\b') { Write-Output ("{0}: {1}" -f ($i+1), $t[$i].Trim()) } }
