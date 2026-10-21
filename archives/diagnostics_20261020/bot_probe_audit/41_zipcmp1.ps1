[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
Add-Type -AssemblyName System.IO.Compression.FileSystem
$newZip = 'D:\FPGA\EG4S20-Bot-HDMIProbe\artifacts\bot_hdmi_probe_001_source.zip'
$oldZip = 'D:\FPGA\EG4S20-Multimedia-Signage\artifacts\timing_fix_20261016_02_source.zip'
function Load($path) { $z = [IO.Compression.ZipFile]::OpenRead($path); $h = @{}; foreach ($e in $z.Entries) { $ms = New-Object IO.MemoryStream; $s = $e.Open(); $s.CopyTo($ms); $s.Close(); $h[$e.FullName] = $ms.ToArray() }; $z.Dispose(); return $h }
$nh = Load $newZip
$oh = Load $oldZip
Write-Output ("new entries=" + $nh.Count + "  baseline entries=" + $oh.Count)
$onlyOld = @($oh.Keys | Where-Object { -not $nh.ContainsKey($_) } | Sort-Object)
$onlyNew = @($nh.Keys | Where-Object { -not $oh.ContainsKey($_) } | Sort-Object)
Write-Output ("ONLY_IN_BASELINE (" + $onlyOld.Count + "): " + ($onlyOld -join ', '))
Write-Output ("ONLY_IN_NEW (" + $onlyNew.Count + "): " + ($onlyNew -join ', '))
Write-Output ("first 4 new names:"); $nh.Keys | Select-Object -First 4 | ForEach-Object { Write-Output ("  " + $_) }
$common = @($oh.Keys | Where-Object { $nh.ContainsKey($_) } | Sort-Object)
$rawSame = 0
$dif = @()
foreach ($k in $common) { if ([System.Linq.Enumerable]::SequenceEqual([byte[]]$nh[$k], [byte[]]$oh[$k])) { $rawSame++ } else { $dif += $k } }
Write-Output ("common=" + $common.Count + "  byte-identical=" + $rawSame + "  byte-differing=" + $dif.Count)
$dif | ForEach-Object { Write-Output ("  BYTEDIFF " + $_) }
