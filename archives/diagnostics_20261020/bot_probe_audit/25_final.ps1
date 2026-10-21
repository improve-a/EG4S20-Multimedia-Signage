[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Stop'
$f = 'D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004'
$p = 'D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001'
Write-Output "=== exported tcl hashes (fail vs pass) ==="
foreach ($n in @('exported_syn.tcl','exported_phy.tcl')) {
  foreach ($d in @($f,$p)) {
    $x = Join-Path $d ('runs\' + (Split-Path $d -Leaf) + '\' + $n)
    if (Test-Path -LiteralPath $x) { Write-Output ((Get-FileHash -Algorithm SHA256 -LiteralPath $x).Hash.ToLower() + '  ' + (Split-Path $d -Leaf) + '  ' + $n) } else { Write-Output ("MISSING " + $x) }
  }
}
Write-Output "=== one-shot parse of the frozen ZIPs ==="
Add-Type -AssemblyName System.IO.Compression.FileSystem
foreach ($z in @('D:\FPGA\EG4S20-NoBot-RCA-20261020\baseline_copies\no_bot_legacy_004_source.zip','D:\FPGA\EG4S20-NoBot-RCA-20261020\baseline_copies\hdmi_probe_001_source.zip')) {
  $a = [IO.Compression.ZipFile]::OpenRead($z)
  $n = $a.Entries.Count
  $probe = @($a.Entries | Where-Object { $_.FullName -like '*hdmi_probe.v' }).Count
  Write-Output ((Split-Path $z -Leaf) + " entries=" + $n + " hdmi_probe_entries=" + $probe)
  $a.Dispose()
}
Write-Output "=== applier-produced top.diff hunks ==="
$d = 'D:\FPGA\EG4S20-NoBot-HDMIProbe\evidence\hdmi_probe\top.diff'
$txt = [IO.File]::ReadAllText($d)
Write-Output ("top.diff bytes=" + $txt.Length + " hunks=" + ([regex]::Matches($txt, '(?m)^@@')).Count)
Write-Output ("adds probe instance: " + $txt.Contains('hdmi_probe probe(') + "; removes legacy decoder: " + $txt.Contains('-seg_decoder seg_decoder_m0('))
Write-Output "=== DONE ==="
