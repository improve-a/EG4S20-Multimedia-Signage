[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Stop'
$repo = 'D:\FPGA\EG4S20-NoBot-HDMIProbe'
$C = '42de1dbe4a20ca78f28be54c4bf41bd0dd814481'
function Dump($path) {
  Write-Output ("===== BEGIN " + $path + " =====")
  git -C $repo --no-pager show ($C + ':' + $path)
  Write-Output ("===== END " + $path + " =====")
}
Dump 'scripts/apply_hdmi_probe.py'
Dump 'rtl/ext/hdmi_probe.v'
Write-Output "=== DONE ==="
