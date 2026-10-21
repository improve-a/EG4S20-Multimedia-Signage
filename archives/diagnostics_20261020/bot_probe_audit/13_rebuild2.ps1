[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Stop'
$repo = 'D:\FPGA\EG4S20-NoBot-HDMIProbe'
$C = '42de1dbe4a20ca78f28be54c4bf41bd0dd814481'
$failTop = 'D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\user_source\hdl_source\top_tf_hdmi_audio.v'
$passTop = 'D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design\user_source\hdl_source\top_tf_hdmi_audio.v'
$py = (git -C $repo --no-pager show ($C + ':scripts/apply_hdmi_probe.py')) -join "`n"
$m = [regex]::Match($py, '(?s)replacement = """(.*?)"""')
Write-Output ("replacement captured: " + $m.Success + " len=" + $m.Groups[1].Value.Length)
$REPL = $m.Groups[1].Value
$t = [IO.File]::ReadAllText($failTop)
$p = [IO.File]::ReadAllText($passTop)
Write-Output ("fail CRLF=" + ([regex]::Matches($t, "`r`n")).Count + "/LF=" + ([regex]::Matches($t, "`n")).Count)
Write-Output ("pass CRLF=" + ([regex]::Matches($p, "`r`n")).Count + "/LF=" + ([regex]::Matches($p, "`n")).Count)
Write-Output ("fail guard match: " + ((Get-FileHash -Algorithm SHA256 -LiteralPath $failTop).Hash.ToLower() -eq 'd90a057f2242ebf387caa8057c85613cf43504be791644353dc35f3b63f8209d'))
$t2 = $t.Replace("wire        axis_s_ready;", "wire        axis_s_ready;`nwire        probe_video_locked;")
$t2 = $t2.Replace(".O_video_locked     (),", ".O_video_locked     (probe_video_locked),")
$start = $t2.IndexOf("seg_decoder seg_decoder_m0(")
$end = $t2.IndexOf("// ====", $start)
$rebuilt = $t2.Substring(0, $start) + $REPL + $t2.Substring($end)
Write-Output ("rebuilt len=" + $rebuilt.Length + " pass len=" + $p.Length + " equal=" + ($rebuilt -ceq $p))
$n = [Math]::Min($rebuilt.Length, $p.Length); $i = 0
while ($i -lt $n -and $rebuilt[$i] -eq $p[$i]) { $i++ }
if ($i -lt $n) {
  Write-Output ("first diff at " + $i)
  $s = [Math]::Max(0, $i - 50)
  Write-Output ("R>" + $rebuilt.Substring($s, [Math]::Min(110, $rebuilt.Length - $s)).Replace("`r", "<CR>").Replace("`n", "<LF>"))
  Write-Output ("P>" + $p.Substring($s, [Math]::Min(110, $p.Length - $s)).Replace("`r", "<CR>").Replace("`n", "<LF>"))
}
Write-Output "=== DONE ==="
