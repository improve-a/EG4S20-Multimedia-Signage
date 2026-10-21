[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Stop'
$fail = 'D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\user_source\hdl_source'
$pass = 'D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design\user_source\hdl_source'
Write-Output "=== EXISTENCE ==="
Write-Output ("fail top: " + (Test-Path (Join-Path $fail 'top_tf_hdmi_audio.v')))
Write-Output ("pass top: " + (Test-Path (Join-Path $pass 'top_tf_hdmi_audio.v')))
Write-Output ("fail probe: " + (Test-Path (Join-Path $fail 'ext\hdmi_probe.v')))
Write-Output ("pass probe: " + (Test-Path (Join-Path $pass 'ext\hdmi_probe.v')))
Write-Output "=== SHA256 ==="
Get-FileHash -Algorithm SHA256 (Join-Path $fail 'top_tf_hdmi_audio.v') | ForEach-Object { Write-Output ("FAILTOP " + $_.Hash) }
Get-FileHash -Algorithm SHA256 (Join-Path $pass 'top_tf_hdmi_audio.v') | ForEach-Object { Write-Output ("PASSTOP " + $_.Hash) }
if (Test-Path (Join-Path $pass 'ext\hdmi_probe.v')) { Get-FileHash -Algorithm SHA256 (Join-Path $pass 'ext\hdmi_probe.v') | ForEach-Object { Write-Output ("PASSPROBE " + $_.Hash) } }
Write-Output "=== SIZES ==="
Get-Item (Join-Path $fail 'top_tf_hdmi_audio.v') | Select-Object Length,LastWriteTime | Format-List
Get-Item (Join-Path $pass 'top_tf_hdmi_audio.v') | Select-Object Length,LastWriteTime | Format-List
Write-Output "=== GIT DIFF --no-index top ==="
git --no-pager diff --no-index --no-color -- ($fail + '\top_tf_hdmi_audio.v') ($pass + '\top_tf_hdmi_audio.v')
Write-Output "=== END DIFF (exit above may be 1) ==="
Write-Output "=== DONE ==="
