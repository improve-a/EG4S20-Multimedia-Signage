[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$z = 'D:\FPGA\EG4S20-NoBot-RCA-20261020\baseline_copies\hdmi_probe_001_source.zip'
$a = [IO.Compression.ZipFile]::OpenRead($z)
foreach ($e in $a.Entries) {
  if ($e.FullName -match 'top_tf_hdmi_audio|hdmi_probe\.v|hx4s20_basic\.al|timing\.sdc|pin\.adc') {
    $s = $e.Open(); $ms = New-Object IO.MemoryStream; $s.CopyTo($ms); $s.Close()
    $h = [BitConverter]::ToString(([Security.Cryptography.SHA256]::Create()).ComputeHash($ms.ToArray())).Replace('-','').ToLower()
    Write-Output ("ZIP {0}  {1}  {2}" -f $h, $ms.Length, $e.FullName)
  }
}
$a.Dispose()
Write-Output "=== WORK .al DIFF (fail work vs pass work) ==="
$fa = 'D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\td_project\hx4s20_basic.al'
$pa = 'D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design\td_project\hx4s20_basic.al'
git --no-pager diff --no-index --no-color -- $fa $pa | Select-Object -First 40
Write-Output "=== constraints hashes ==="
foreach ($r in @('D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design','D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design')) {
  foreach ($f in @('user_source\constraints_source\pin.adc','user_source\constraints_source\timing.sdc')) {
    $p = Join-Path $r $f
    if (Test-Path -LiteralPath $p) { Write-Output ((Get-FileHash -Algorithm SHA256 -LiteralPath $p).Hash.ToLower() + '  ' + $f + '  @' + $r.Split('\')[2]) }
  }
}
Write-Output "=== DONE ==="
