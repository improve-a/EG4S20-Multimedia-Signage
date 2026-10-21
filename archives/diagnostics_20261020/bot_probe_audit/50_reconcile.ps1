[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Load($path) { $z = [IO.Compression.ZipFile]::OpenRead($path); $h = @{}; foreach ($e in $z.Entries) { $ms = New-Object IO.MemoryStream; $s = $e.Open(); $s.CopyTo($ms); $s.Close(); $h[$e.FullName] = $ms.ToArray() }; $z.Dispose(); return $h }
$nh = Load 'D:\FPGA\EG4S20-Bot-HDMIProbe\artifacts\bot_hdmi_probe_001_source.zip'
$m = [Text.Encoding]::UTF8.GetString($nh['audit/baseline_manifest.json'])
Write-Output ("manifest paths=" + ([regex]::Matches($m, '"path"\s*:')).Count)
Write-Output ("manifest selected? schema=" + ([regex]::Match($m, '"schema_version"\s*:\s*(\d+)')).Groups[1].Value)
Write-Output ("probe path in manifest: " + $m.Contains('hdl_source/ext/hdmi_probe.v'))
Write-Output "=== ext/*.v inventory (new) ==="
$nh.Keys | Where-Object { $_ -match '/hdl_source/ext/[^/]+\.v$' } | Sort-Object | ForEach-Object { Write-Output ("  " + ($_ -replace '.*/ext/','')) }
Write-Output "=== hdl_source root .v ==="
$nh.Keys | Where-Object { $_ -match '/hdl_source/[^/]+\.v$' } | Sort-Object | ForEach-Object { Write-Output ("  " + ($_ -replace '.*/hdl_source/','')) }
