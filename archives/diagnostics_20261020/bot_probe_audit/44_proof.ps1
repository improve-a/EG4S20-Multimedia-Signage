[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
Add-Type -AssemblyName System.IO.Compression.FileSystem
$newZip = 'D:\FPGA\EG4S20-Bot-HDMIProbe\artifacts\bot_hdmi_probe_001_source.zip'
$oldZip = 'D:\FPGA\EG4S20-Multimedia-Signage\artifacts\timing_fix_20261016_02_source.zip'
$newRoot = 'D:/FPGA/EG4S20-Bot-HDMIProbe/output/html_fidelity/builds/bot_hdmi_probe_001/work/design'
$oldRoot = 'D:/FPGA/EG4S20-Multimedia-Signage/output/html_fidelity/builds/timing_fix_20261016_02/work/design'
$donorTop = 'D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design\user_source\hdl_source\top_tf_hdmi_audio.v'
$donorProbe = 'D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design\user_source\hdl_source\ext\hdmi_probe.v'
function Load($path) { $z = [IO.Compression.ZipFile]::OpenRead($path); $h = @{}; foreach ($e in $z.Entries) { $ms = New-Object IO.MemoryStream; $s = $e.Open(); $s.CopyTo($ms); $s.Close(); $h[$e.FullName] = $ms.ToArray() }; $z.Dispose(); return $h }
function Norm($bytes, $root) { $t = [Text.Encoding]::UTF8.GetString($bytes); $t = $t.Replace($root, '<ROOT>'); $t = $t.Replace($root.Replace('/','\'), '<ROOT>'); return $t.Replace("`r`n", "`n") }
function Sha([string]$s) { $b = (New-Object Text.UTF8Encoding($false)).GetBytes($s); return [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($b)).Replace('-','').ToLower() }
$nh = Load $newZip
$oh = Load $oldZip
$nt = Norm $nh['work/design/user_source/hdl_source/top_tf_hdmi_audio.v'] $newRoot
$bt = Norm $oh['work/design/user_source/hdl_source/top_tf_hdmi_audio.v'] $oldRoot
Write-Output "--- 1. inverse transform: new top minus the 3 probe edits must equal the baseline top"
$r = $nt.Replace('.O_video_locked     (probe_video_locked),', '.O_video_locked     (),')
$s = $r.IndexOf('// Read-only video-clock probes')
$e = $r.IndexOf('// ====', $s)
$bs = $bt.IndexOf('seg_decoder seg_decoder_m0(')
$be = $bt.IndexOf('// ====', $bs)
$r = $r.Substring(0, $s) + $bt.Substring($bs, $be - $bs) + $r.Substring($e)
$r = $r.Replace("wire        probe_video_locked;`n", '')
Write-Output ("anchor offsets new=" + $s + "/" + $e + " baseline=" + $bs + "/" + $be)
Write-Output ("rebuilt-equals-baseline: " + ($r -ceq $bt) + "  rebuiltLen=" + $r.Length + " baselineLen=" + $bt.Length)
Write-Output "--- 2. inverse transform on .al"
$na = Norm $nh['work/design/td_project/hx4s20_basic.al'] $newRoot
$ba = Norm $oh['work/design/td_project/hx4s20_basic.al'] $oldRoot
$entry = "            <File Path=`"../user_source/hdl_source/ext/hdmi_probe.v`">`n                <FileInfo>`n                    <Attr Name=`"UsedInSyn`" Val=`"true`"/>`n                    <Attr Name=`"UsedInP&R`" Val=`"true`"/>`n                    <Attr Name=`"BelongTo`" Val=`"design_1`"/>`n                    <Attr Name=`"CompileOrder`" Val=`"96`"/>`n                </FileInfo>`n            </File>`n"
Write-Output ("entry present exactly once: " + (([regex]::Matches($na, [regex]::Escape($entry))).Count -eq 1))
$na2 = $na.Replace($entry, '')
Write-Output ("al rebuilt-equals-baseline: " + ($na2 -ceq $ba) + "  len=" + $na2.Length + " vs " + $ba.Length)
Write-Output "--- 3. probe file identity"
Write-Output ("new probe sha256:   " + [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([byte[]]$nh['work/design/user_source/hdl_source/ext/hdmi_probe.v'])).Replace('-','').ToLower())
Write-Output ("donor probe sha256: " + (Get-FileHash -Algorithm SHA256 -LiteralPath $donorProbe).Hash.ToLower())
Write-Output "--- 4. probe instantiation block vs donor"
$ds = $nt.IndexOf('// Read-only video-clock probes'); $de = $nt.IndexOf('// ====', $ds)
$nb = $nt.Substring($ds, $de - $ds)
$dt = [IO.File]::ReadAllText($donorTop)
$dds = $dt.IndexOf('// Read-only video-clock probes'); $dde = $dt.IndexOf('// ====', $dds)
$db = $dt.Substring($dds, $dde - $dds).Replace("`r`n", "`n")
Write-Output ("new block sha:   " + (Sha $nb))
Write-Output ("donor block sha: " + (Sha $db))
Write-Output ("block identical: " + ($nb -ceq $db) + "  len=" + $nb.Length + "/" + $db.Length)
Write-Output ("locked connection identical: " + ($nt.Contains('.O_video_locked     (probe_video_locked),') -and $dt.Contains('.O_video_locked     (probe_video_locked),')))
Write-Output "--- 5. compile order"
$all = [regex]::Matches($ba, 'Name="CompileOrder" Val="(\d+)"') | ForEach-Object { [int]$_.Groups[1].Value }
Write-Output ("baseline max CompileOrder=" + (($all | Measure-Object -Maximum).Maximum) + "  entries=" + $all.Count)
$allN = [regex]::Matches($na, 'Name="CompileOrder" Val="(\d+)"') | ForEach-Object { [int]$_.Groups[1].Value }
Write-Output ("new max=" + (($allN | Measure-Object -Maximum).Maximum) + "  new entries=" + $allN.Count)
Write-Output "--- 6. attribute line in new probe"
$npr = [Text.Encoding]::UTF8.GetString($nh['work/design/user_source/hdl_source/ext/hdmi_probe.v']).Replace("`r`n", "`n")
Write-Output ("async_reg+preserve present: " + $npr.Contains('(* async_reg="true", preserve="true" *) reg [30:0] status_meta,status_sync;'))
Write-Output ("donor attribute line present: " + ([IO.File]::ReadAllText($donorProbe)).Contains('(* async_reg="true", preserve="true" *) reg [30:0] status_meta,status_sync;'))
