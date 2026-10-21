[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
Add-Type -AssemblyName System.IO.Compression.FileSystem
$newZip = 'D:\FPGA\EG4S20-Bot-HDMIProbe\artifacts\bot_hdmi_probe_001_source.zip'
$oldZip = 'D:\FPGA\EG4S20-Multimedia-Signage\artifacts\timing_fix_20261016_02_source.zip'
$newRoot = 'D:/FPGA/EG4S20-Bot-HDMIProbe/output/html_fidelity/builds/bot_hdmi_probe_001/work/design'
$oldRoot = 'D:/FPGA/EG4S20-Multimedia-Signage/output/html_fidelity/builds/timing_fix_20261016_02/work/design'
function Load($path) { $z = [IO.Compression.ZipFile]::OpenRead($path); $h = @{}; foreach ($e in $z.Entries) { $ms = New-Object IO.MemoryStream; $s = $e.Open(); $s.CopyTo($ms); $s.Close(); $h[$e.FullName] = $ms.ToArray() }; $z.Dispose(); return $h }
function Norm($bytes, $root) { $t = [Text.Encoding]::UTF8.GetString($bytes); $t = $t.Replace($root, '<ROOT>'); $t = $t.Replace($root.Replace('/','\'), '<ROOT>'); $t = $t.Replace($root.Replace('\','/'), '<ROOT>'); return $t.Replace("`r`n", "`n") }
$nh = Load $newZip
$oh = Load $oldZip
$common = @($oh.Keys | Where-Object { $nh.ContainsKey($_) } | Sort-Object)
$content = @()
$eolOnly = @()
$same = 0
foreach ($k in $common) { $a = Norm $nh[$k] $newRoot; $b = Norm $oh[$k] $oldRoot; if ($a -ceq $b) { if ($a.Length -eq 0 -and $b.Length -eq 0) { $same++ } else { $same++ } } elseif ($a.Replace("`n","") -ceq $b.Replace("`n","")) { $eolOnly += $k } else { $content += $k } }
Write-Output ("normalized: equal=" + $same + " eol-only=" + $eolOnly.Count + " content-diff=" + $content.Count)
Write-Output ("EOL_ONLY: " + ($eolOnly -join ', '))
Write-Output "CONTENT-DIFF FILES:"
$content | ForEach-Object { Write-Output ("  " + $_) }
Write-Output "=== line-level summary for content diffs ==="
foreach ($k in $content) { $a = (Norm $nh[$k] $newRoot) -split "`n"; $b = (Norm $oh[$k] $oldRoot) -split "`n"; $d = Compare-Object $a $b; Write-Output ("  " + $k + "  newLines=" + $a.Count + " oldLines=" + $b.Count + " changedLines=" + $d.Count) }
