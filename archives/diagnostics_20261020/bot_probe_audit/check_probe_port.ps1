# Read-only portability check for the NoBot HDMI probe (frozen success 42de1db / build 72e5c80).
# Targets come from PROBE_TOP, PROBE_AL, PROBE_PROBE. Never writes anything.
# Exit code = number of failed checks.
# Every statement (including the helpers) is single-line on purpose so the file
# also runs when piped to powershell -NoProfile -Command - over ssh.
$Top = $env:PROBE_TOP
$Al = $env:PROBE_AL
$Probe = $env:PROBE_PROBE
$bad = 0
function Chk($ok, $name) { if ($ok) { Write-Output ("PASS  " + $name) } else { Write-Output ("FAIL  " + $name); $script:bad++ } }
function Pat($text, $pat, $exp, $name) { $n = ([regex]::Matches($text, [regex]::Escape($pat))).Count; Chk ($n -eq $exp) ($name + " [count=" + $n + " expected=" + $exp + "]") }
Chk (Test-Path -LiteralPath $Top) "top file exists"
Chk (Test-Path -LiteralPath $Al) ".al exists"
Chk (Test-Path -LiteralPath $Probe) "probe file exists"
if ($bad -ne 0) { Write-Output ("RESULT: " + $bad + " CHECK(S) FAILED (missing input)"); exit $bad }
$t = [IO.File]::ReadAllText($Top)
$p = [IO.File]::ReadAllText($Probe)
$a = [IO.File]::ReadAllText($Al)
$frozen = 'f9e820e62d2abb204e2467e4c4f6791817d0adfb042e40b0399a660be9bbcf25'
Chk ((Get-FileHash -Algorithm SHA256 -LiteralPath $Probe).Hash.ToLower() -eq $frozen) "probe file byte-identical to frozen source"
$attr = '(* async_reg="true", preserve="true" *)'
Chk ($p.Contains($attr + ' reg [30:0] status_meta,status_sync;')) "synchronizer carries async_reg+preserve"
Pat $p $attr 1 "attribute site in probe file"
Chk ($p.Contains('module hdmi_probe #(') -and $p.Contains('module hdmi_probe_display #(parameter PAGE_CYCLES=150000000)(')) "both modules present"
Chk ($p.Contains('parameter WINDOW_CYCLES=25000000, FRAME_PIXELS=307200, LINE_PIXELS=640')) "1 s window / 640x480 constants present"
Pat $t 'wire        probe_video_locked;' 1 "top: probe_video_locked declared"
Pat $t '.O_video_locked     (probe_video_locked),' 1 "top: O_video_locked connected to probe"
Pat $t '.O_video_locked     (),' 0 "top: no dangling O_video_locked"
Pat $t 'hdmi_probe probe(' 1 "top: hdmi_probe instance"
Pat $t 'hdmi_probe_display probe_display(' 1 "top: hdmi_probe_display instance"
Pat $t '.clk(video_clk),.rst(video_rst),.vs(fx_vs),.hs(fx_hs),.de(fx_de),' 1 "top: video clock/domain and raster taps"
Pat $t '.av(axis_s_valid),.au(axis_s_user),.al(axis_s_last),.ready(axis_s_ready),' 1 "top: AXIS taps"
Pat $t '.locked(probe_video_locked),.audio_valid(audio_valid),.flags(probe_flags));' 1 "top: locked + audio_valid taps"
Pat $t '.clk(clk),.rst(button_reset50),.flags_async(probe_flags),' 1 "top: 50MHz display instance"
Pat $t '.video_rst_async(video_rst),.sys_lock_async(sys_pll_lock),.video_lock_async(video_pll_lock),' 1 "top: async status levels"
Pat $t '.digits(probe_digits),.page_number());' 1 "top: display outputs, page_number unconnected"
Pat $t 'seg_decoder digit_decoder(.bin_data(probe_digits[probe_digit*4+:4]),' 1 "top: per-digit decoder generate"
Pat $t ".seg_data_0({1'b1,probe_segments[6:0]})," 1 "top: seg digit 0"
Pat $t ".seg_data_5({1'b0,probe_segments[41:35]})" 1 "top: seg digit 5 (page, dot lit)"
Pat $t 'seg_decoder seg_decoder_m0(' 0 "top: legacy status decoder removed"
$nDs = ([regex]::Matches($t, 'display_state')).Count
Chk ($nDs -eq 2) ("display_state has no reader [count=" + $nDs + " expected 2 = decl + assign]")
Pat $a 'ext/hdmi_probe.v' 1 ".al lists hdmi_probe.v once"
$m = [regex]::Match($a, 'hdmi_probe\.v[\s\S]{0,400}?CompileOrder" Val="(\d+)"')
Chk $m.Success "probe entry carries CompileOrder"
if ($m.Success) { $co = [int]$m.Groups[1].Value; $others = @([regex]::Matches($a, 'Name="CompileOrder" Val="(\d+)"') | ForEach-Object { [int]$_.Groups[1].Value }); $maxOther = ($others | Where-Object { $_ -ne $co } | Measure-Object -Maximum).Maximum; Chk ($co -eq $maxOther + 1) ("probe CompileOrder " + $co + " == max+1 (" + $maxOther + "+1)") }
Write-Output ("RESULT: " + $(if ($bad -eq 0) { "ALL CHECKS PASSED" } else { $bad.ToString() + " CHECK(S) FAILED" }))
exit $bad
