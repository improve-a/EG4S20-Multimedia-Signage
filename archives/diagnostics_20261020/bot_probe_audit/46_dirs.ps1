[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
Add-Type -AssemblyName System.IO.Compression.FileSystem
$newZip = 'D:\FPGA\EG4S20-Bot-HDMIProbe\artifacts\bot_hdmi_probe_001_source.zip'
$oldZip = 'D:\FPGA\EG4S20-Multimedia-Signage\artifacts\timing_fix_20261016_02_source.zip'
function Load($path) { $z = [IO.Compression.ZipFile]::OpenRead($path); $h = @{}; foreach ($e in $z.Entries) { $ms = New-Object IO.MemoryStream; $s = $e.Open(); $s.CopyTo($ms); $s.Close(); $h[$e.FullName] = $ms.ToArray() }; $z.Dispose(); return $h }
$nh = Load $newZip
$oh = Load $oldZip
Write-Output "=== distinct directory prefixes (new) ==="
$nh.Keys | ForEach-Object { ($_ -replace '/[^/]+$','') } | Group-Object | Sort-Object Name | ForEach-Object { Write-Output ("  " + $_.Count + "  " + $_.Name) }
Write-Output "=== ext/ module count ==="
Write-Output ("new ext files=" + @($nh.Keys | Where-Object { $_ -match '/hdl_source/ext/' }).Count + "  base ext files=" + @($oh.Keys | Where-Object { $_ -match '/hdl_source/ext/' }).Count)
Write-Output "=== audit artifacts vs Root local copies ==="
$pairs = @(@('audit/probe_only.diff','bot_probe\probe_only.diff'), @('audit/bot_probe_audit.json','bot_probe\verification.txt'))
foreach ($pr in $pairs) { $zn = $pr[0]; $lp = 'D:\FPGA\EG4S20-Bot-HDMIProbe\' + $pr[1]; $zh = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([byte[]]$nh[$zn])).Replace('-','').ToLower(); if (Test-Path -LiteralPath $lp) { $lh = (Get-FileHash -Algorithm SHA256 -LiteralPath $lp).Hash.ToLower() } else { $lh = 'MISSING' }; $zs = $zh.Substring(0, [Math]::Min(16, $zh.Length)); $ls = $lh.Substring(0, [Math]::Min(16, $lh.Length)); Write-Output ("  " + $zn + "  zip=" + $zs + "  local=" + $ls + "  equal=" + ($zh -eq $lh) + "  bytes=" + $nh[$zn].Length) }
Write-Output "=== new probe_only.diff hunk count ==="
$pd = [Text.Encoding]::UTF8.GetString($nh['audit/probe_only.diff'])
Write-Output ("  hunks=" + ([regex]::Matches($pd, '(?m)^@@')).Count + "  bytes=" + $pd.Length)
