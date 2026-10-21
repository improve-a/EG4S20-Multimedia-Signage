[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Stop'
$p = 'D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design\user_source\hdl_source\top_tf_hdmi_audio.v'
$t = Get-Content -LiteralPath $p
foreach ($r in @(@(196,212), @(258,270), @(498,510))) {
  Write-Output ("--- lines " + $r[0] + ".." + $r[1] + " ---")
  for ($i = $r[0] - 1; $i -lt $r[1]; $i++) { Write-Output ("{0}: {1}" -f ($i + 1), $t[$i].TrimEnd()) }
}
Write-Output "=== DONE ==="
