[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
Add-Type -AssemblyName System.IO.Compression.FileSystem
$newZip = 'D:\FPGA\EG4S20-Bot-HDMIProbe\artifacts\bot_hdmi_probe_001_source.zip'
$z = [IO.Compression.ZipFile]::OpenRead($newZip)
$e = $z.GetEntry('audit/bot_probe_audit.json')
$ms = New-Object IO.MemoryStream; $s = $e.Open(); $s.CopyTo($ms); $s.Close()
Write-Output "=== audit/bot_probe_audit.json ==="
Write-Output ([Text.Encoding]::UTF8.GetString($ms.ToArray()))
$e2 = $z.GetEntry('audit/probe_only.diff')
$ms2 = New-Object IO.MemoryStream; $s2 = $e2.Open(); $s2.CopyTo($ms2); $s2.Close()
$d = [Text.Encoding]::UTF8.GetString($ms2.ToArray())
$lines = $d -split "`n"
Write-Output "=== audit/probe_only.diff ==="
Write-Output ("lines=" + $lines.Count + " firstLine=" + $lines[0] + " | lastNonEmpty=" + ($lines | Where-Object { $_.Length -gt 0 } | Select-Object -Last 1))
$lines | Select-Object -First 3 | ForEach-Object { Write-Output ("  " + $_) }
$z.Dispose()
