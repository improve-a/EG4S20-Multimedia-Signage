"""Apply only read-only taps and replace the six-digit status presentation.

The original vendor-derived top remains a local dependency; this authored,
hash-guarded recipe and the new probe RTL are committed. Do not run the legacy
generator after applying this recipe. The build ZIP contains the exact top.
"""
from pathlib import Path
import hashlib
import re
import difflib
import json

ROOT = Path(__file__).resolve().parents[1]
top = ROOT / "rtl/top_tf_hdmi_audio.v"
original = top.read_bytes()
assert hashlib.sha256(original).hexdigest() == "d90a057f2242ebf387caa8057c85613cf43504be791644353dc35f3b63f8209d"
t = original.decode()
t = t.replace("wire        axis_s_ready;", "wire        axis_s_ready;\nwire        probe_video_locked;")
assert t.count(".O_video_locked     (),") == 1
t = t.replace(".O_video_locked     (),", ".O_video_locked     (probe_video_locked),")
start = t.index("seg_decoder seg_decoder_m0(")
end = t.index("// ===================== 原图像时序与帧缓存", start)
replacement = """// Read-only video-clock probes; display statistics in the existing 50MHz scanner.
wire [27:0] probe_flags;
wire [23:0] probe_digits;
wire [41:0] probe_segments;
hdmi_probe probe(
 .clk(video_clk),.rst(video_rst),.vs(fx_vs),.hs(fx_hs),.de(fx_de),
 .av(axis_s_valid),.au(axis_s_user),.al(axis_s_last),.ready(axis_s_ready),
 .locked(probe_video_locked),.audio_valid(audio_valid),.flags(probe_flags));
hdmi_probe_display probe_display(
 .clk(clk),.rst(button_reset50),.flags_async(probe_flags),
 .video_rst_async(video_rst),.sys_lock_async(sys_pll_lock),.video_lock_async(video_pll_lock),
 .digits(probe_digits),.page_number());
genvar probe_digit;
generate for(probe_digit=0;probe_digit<6;probe_digit=probe_digit+1)begin:probe_decode
 seg_decoder digit_decoder(.bin_data(probe_digits[probe_digit*4+:4]),
  .seg_data(probe_segments[probe_digit*7+:7]));
end endgenerate
seg_scan seg_scan_m0(
 .clk(clk),.rst_n(rst_n),.seg_sel(seg_sel),.seg_data(seg_data),
 .seg_data_0({1'b1,probe_segments[6:0]}),
 .seg_data_1({1'b1,probe_segments[13:7]}),
 .seg_data_2({1'b1,probe_segments[20:14]}),
 .seg_data_3({1'b1,probe_segments[27:21]}),
 .seg_data_4({1'b1,probe_segments[34:28]}),
 .seg_data_5({1'b0,probe_segments[41:35]})
);

"""
t = t[:start] + replacement + t[end:]
top.write_text(t, encoding="utf-8", newline="\n")
project = ROOT / "project/td_project/hx4s20_basic.al"
old_project = project.read_bytes().decode("utf-8")
assert "ext/hdmi_probe.v" not in old_project
order = 1 + max(map(int, re.findall(r'Name="CompileOrder" Val="(\d+)"', old_project)))
entry = f"""            <File Path="../user_source/hdl_source/ext/hdmi_probe.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true"/>
                    <Attr Name="UsedInP&amp;R" Val="true"/>
                    <Attr Name="BelongTo" Val="design_1"/>
                    <Attr Name="CompileOrder" Val="{order}"/>
                </FileInfo>
            </File>
"""
# Match the native project's serialization, which uses P&R literally.
entry = entry.replace("P&amp;R", "P&R")
if "\r\n" in old_project:
    entry = entry.replace("\n", "\r\n")
project.write_bytes(old_project.replace("        </Verilog>", entry + "        </Verilog>", 1).encode("utf-8"))
out = ROOT / "evidence/hdmi_probe"
out.mkdir(parents=True, exist_ok=True)
(out / "top.diff").write_text("".join(difflib.unified_diff(
    original.decode().splitlines(True), t.splitlines(True), fromfile="original/top", tofile="probe/top")),
    encoding="utf-8")
(out / "integration_receipt.json").write_text(json.dumps({
    "original_top_sha256": hashlib.sha256(original).hexdigest(),
    "probe_top_sha256": hashlib.sha256(top.read_bytes()).hexdigest(),
    "scope": "read-only signal taps and existing six-digit display; no datapath/reset/clock/IP/IO changes"
}, indent=2))
print("Applied read-only taps and existing display replacement.")
