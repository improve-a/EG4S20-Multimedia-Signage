[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
Add-Type -AssemblyName System.IO.Compression.FileSystem
$newZip = 'D:\FPGA\EG4S20-Bot-HDMIProbe\artifacts\bot_hdmi_probe_001_source.zip'
$oldZip = 'D:\FPGA\EG4S20-Multimedia-Signage\artifacts\timing_fix_20261016_02_source.zip'
$newRoot = 'D:/FPGA/EG4S20-Bot-HDMIProbe/output/html_fidelity/builds/bot_hdmi_probe_001/work/design'
$oldRoot = 'D:/FPGA/EG4S20-Multimedia-Signage/output/html_fidelity/builds/timing_fix_20261016_02/work/design'
function Load($path) { $z = [IO.Compression.ZipFile]::OpenRead($path); $h = @{}; foreach ($e in $z.Entries) { $ms = New-Object IO.MemoryStream; $s = $e.Open(); $s.CopyTo($ms); $s.Close(); $h[$e.FullName] = $ms.ToArray() }; $z.Dispose(); return $h }
function Norm($bytes, $root) { $t = [Text.Encoding]::UTF8.GetString($bytes); $t = $t.Replace($root, '<ROOT>'); $t = $t.Replace($root.Replace('/','\'), '<ROOT>'); return $t.Replace("`r`n", "`n") }
$nh = Load $newZip
$oh = Load $oldZip
Write-Output "=== baseline_manifest.json: unique lines after normalization ==="
$a = (Norm $nh['audit/baseline_manifest.json'] $newRoot) -split "`n"
$b = (Norm $oh['audit/baseline_manifest.json'] $oldRoot) -split "`n"
$d = Compare-Object $a $b
Write-Output ("new-only (this is DIFFERENCE side): " + (@($d | Where-Object { $_.SideIndicator -eq '=>' }).Count))
$d | Where-Object { $_.SideIndicator -eq '=>' } | Select-Object -First 25 | ForEach-Object { Write-Output ("  N " + $_.InputObject) }
Write-Output ("baseline-only (REFERENCE side): " + (@($d | Where-Object { $_.SideIndicator -eq '<=' }).Count))
$d | Where-Object { $_.SideIndicator -eq '<=' } | Select-Object -First 25 | ForEach-Object { Write-Output ("  O " + $_.InputObject) }
Write-Output "=== key design inputs retained and raw-identical ==="
$keys = @('user_source/constraints_source/pin.adc','user_source/constraints_source/timing.sdc','user_source/hdl_source/ext/html_bot_overlay.v','user_source/hdl_source/ext/html_layer_cache.v','user_source/hdl_source/ext/audio_media.v','user_source/hdl_source/ext/audio_output_mux.v','user_source/hdl_source/ext/audio_pcm_player.v','user_source/hdl_source/ext/audio_async_fifo.v','user_source/hdl_source/ext/wav_stream_parser.v','user_source/hdl_source/ext/html_layer_descriptor_rom.v','user_source/hdl_source/ext/html_scene_motion.v','user_source/hdl_source/ext/legacy_exhibit_loader.v')
foreach ($k in $keys) { $full = 'work/design/' + $k; $inN = $nh.ContainsKey($full); $inO = $oh.ContainsKey($full); $same = if ($inN -and $inO) { [System.Linq.Enumerable]::SequenceEqual([byte[]]$nh[$full], [byte[]]$oh[$full]) } else { $false }; Write-Output ("  " + $k + "  inNew=" + $inN + " inBase=" + $inO + " rawEqual=" + $same) }
Write-Output "=== IP + SD + vendor dirs entry counts ==="
foreach ($p in @('work/design/user_source/IP/','work/design/user_source/hdl_source/SD/','work/design/user_source/hdl_source/')) { $cn = @($nh.Keys | Where-Object { $_.StartsWith($p) }).Count; $co = @($oh.Keys | Where-Object { $_.StartsWith($p) }).Count; Write-Output ("  " + $p + " new=" + $cn + " base=" + $co) }
Write-Output "=== Root local artifacts vs ZIP copies ==="
foreach ($pair in @(@('audit/probe_only.diff','bot_probe/probe_only.diff'), @('audit/bot_probe_audit.json','bot_probe/verification.txt'))) { $zn = $pair[0]; $lp = 'D:\FPGA\EG4S20-Bot-HDMIProbe\' + $pair[1]; $zh = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([byte[]]$nh[$zn])).Replace('-','').ToLower(); $lh = if (Test-Path -LiteralPath $lp) { (Get-FileHash -Algorithm SHA256 -LiteralPath $lp).Hash.ToLower() } else { 'MISSING' }; Write-Output ("  " + $zn + " zip=" + $zh.Substring(0,16) + " local=" + $lh.Substring(0,16) + " equal=" + ($zh -eq $lh)) }
