[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Stop'
foreach ($p in @('D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\user_source\hdl_source\top_tf_hdmi_audio.v','D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design\user_source\hdl_source\top_tf_hdmi_audio.v')) {
  $t = Get-Content -LiteralPath $p
  for ($i = 0; $i -lt $t.Count; $i++) { if ($t[$i] -match 'O_video_locked|seg_decoder seg_decoder_m0|wire        axis_s_ready|hdmi_probe probe\(') { Write-Output ((Split-Path (Split-Path $p -Parent) -Leaf) + ' ' + ($i + 1) + ': ' + $t[$i].Trim()) } }
}
Write-Output "=== DONE ==="
