[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
Add-Type -AssemblyName System.IO.Compression.FileSystem
$newZip = 'D:\FPGA\EG4S20-Bot-HDMIProbe\artifacts\bot_hdmi_probe_001_source.zip'
$oldZip = 'D:\FPGA\EG4S20-Multimedia-Signage\artifacts\timing_fix_20261016_02_source.zip'
$newRoot = 'D:/FPGA/EG4S20-Bot-HDMIProbe/output/html_fidelity/builds/bot_hdmi_probe_001/work/design'
$oldRoot = 'D:/FPGA/EG4S20-Multimedia-Signage/output/html_fidelity/builds/timing_fix_20261016_02/work/design'
function Load($path) { $z = [IO.Compression.ZipFile]::OpenRead($path); $h = @{}; foreach ($e in $z.Entries) { $ms = New-Object IO.MemoryStream; $s = $e.Open(); $s.CopyTo($ms); $s.Close(); $h[$e.FullName] = $ms.ToArray() }; $z.Dispose(); return $h }
function Norm($bytes, $root) { $t = [Text.Encoding]::UTF8.GetString($bytes); $t = $t.Replace($root, '<ROOT>'); $t = $t.Replace($root.Replace('/','\'), '<ROOT>'); return $t.Replace("`r`n", "`n") }
function ShowDiff($key) { Write-Output ("===== " + $key + " ====="); $a = (Norm $nh[$key] $newRoot) -split "`n"; $b = (Norm $oh[$key] $oldRoot) -split "`n"; Write-Output ("lines new=" + $a.Count + " baseline=" + $b.Count); $d = Compare-Object $a $b; Write-Output "-- only in NEW:"; $d | Where-Object { $_.SideIndicator -eq '=>' } | ForEach-Object { Write-Output ("  + " + $_.InputObject) }; Write-Output "-- only in BASELINE:"; $d | Where-Object { $_.SideIndicator -eq '<=' } | ForEach-Object { Write-Output ("  - " + $_.InputObject) } }
$nh = Load $newZip
$oh = Load $oldZip
ShowDiff 'work/design/td_project/hx4s20_basic.al'
ShowDiff 'work/design/user_source/hdl_source/top_tf_hdmi_audio.v'
