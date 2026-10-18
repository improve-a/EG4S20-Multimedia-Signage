"""Select ext_full_005 local dependencies and apply the small no-Bot top adapter.

Vendor/derived HDL remains local-only. This script records every input/output
hash, so the old proven memory backbone and the authored integration are clear.
It never resets a Git tree or copies historical build outputs.
"""
import argparse,hashlib,json,pathlib,re,datetime
ROOT=pathlib.Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--baseline',default=r'D:\FPGA\hx4s20_extensions_20261013\builds\ext_full_005\work\design');a=p.parse_args()
b=pathlib.Path(a.baseline);src=b/'user_source/hdl_source'
out=ROOT/'output/html_fidelity/no_bot';out.mkdir(parents=True,exist_ok=True)
rows=[]
def sha(x):return hashlib.sha256(x).hexdigest()
EXPECTED_BASELINE={'top_tf_hdmi_audio.v': 'c7eeedb69a52cf9d016a829cc56d4f5a7c810e31c732ae4fd4602918af998808', 'SD/frame_read_write.v': '733257c43b1f2ecac52c659c8d02e6e894d3abe18d35e71baf5a8ca65fd75eb1', 'SD/frame_fifo_read.v': '0f186d8460d613ba010cefaa2e1625b115b1feff96bf28d3bb2a57d02f9eb69d', 'SD/frame_fifo_write.v': '13c687ddc6e0e446c1029986223cab38df48e8a3bdfcbcfa190717e990753cf2'}
for name,digest in EXPECTED_BASELINE.items():
 if sha((src/name).read_bytes())!=digest:raise ValueError("Wrong ext_full_005 input: "+name)
def record(rel,data,source,note):
 dest=ROOT/rel;old=dest.read_bytes() if dest.exists() else b''
 dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data)
 rows.append(dict(path=rel,source=source,before_sha256=sha(old),after_sha256=sha(data),baseline_source_sha256=sha(pathlib.Path(source).read_bytes()) if source.startswith(str(src)) else None,note=note))
# Preserve the physically verified 256-word sequential request and FIFO logic.
for rel in ['SD/frame_read_write.v','SD/frame_fifo_read.v','SD/frame_fifo_write.v']:
 data=(src/rel).read_bytes()
 if rel.endswith('frame_read_write.v'):
  data=data.replace(b'(* async_reg="true" *) reg [1:0] mem_reset_sync',b'(* async_reg="true", preserve="true" *) reg [1:0] mem_reset_sync')
 record('rtl/'+rel,data,str(src/rel),'ext_full_005; only reset-chain preserve attribute retained where applicable')
s=(src/'top_tf_hdmi_audio.v').read_text(encoding='utf-8')
s=s.replace('wire [7:0] interval_seconds,progress;','wire [7:0] interval_seconds,progress;\nwire [3:0] interval_fraction,cfg_interval_fraction;')
s=s.replace('wire [46:0] video_config;','wire [50:0] video_config;')
s=s.replace('assign {cfg_state,cfg_mute', 'assign {cfg_interval_fraction,cfg_state,cfg_mute')
s=s.replace('wire [1:0] active_buf_idx;','wire [11:0] active_view,candidate_view;\nwire [1:0] active_buf_idx=active_view[1:0];\nwire cover_request_toggle,cover_ack_toggle;')
s=s.replace('wire [1:0]  disp_buf_idx;','')
s=s.replace('video_transition transition(','''video_transition #(.COVER_BEFORE_LOAD(1),.CLOSE_STEP(54),.OPEN_STEP(36),.MASK_COLOR(24'h151615)) transition(''')
s=s.replace(' .candidate_toggle_async(commit_toggle),.commit_ack_toggle(commit_ack_toggle),',' .candidate_toggle_async(commit_toggle),.commit_ack_toggle(commit_ack_toggle),\n .cover_request_toggle_async(cover_request_toggle),.cover_ack_toggle(cover_ack_toggle),')
s=s.replace("frame_config_bridge #(.WIDTH(47),.RESET_VALUE({4'd0,3'b000,8'd0,4'd8,2'd0,2'd0,1'b1,8'd3,3'd2,9'd0,3'd0}))", "frame_config_bridge #(.WIDTH(51),.RESET_VALUE({4'd4,4'd0,3'b000,8'd0,4'd8,2'd0,2'd0,1'b1,8'd5,3'd2,9'd0,3'd0}))")
s=s.replace('.src_config({state_code,audio_muted', '.src_config({interval_fraction,state_code,audio_muted')
s=s.replace('.dst_frame(vs && !config_prev_vs)', '.dst_frame(timing_read_req&&!timing_req_prev)')
a0=s.index('video_extensions #');a1=s.index('\n\n\n',a0)
s=s[:a0]+'''// View metadata is committed with its buffer address. UI never announces a
// requested zoom/page while scanout still holds the previous completed image.
reg commit_previous;
always @(posedge video_clk)begin
 if(video_rst)commit_previous<=0;else commit_previous<=commit_ack_toggle;
end
wire page_event=commit_ack_toggle^commit_previous;
wire [50:0] display_config={video_config[50:28],active_view[7:6],video_config[25:0]};
html_video_overlay extensions(.clk(video_clk),.rst(video_rst),.i_hs(tr_hs),.i_vs(tr_vs),.i_de(tr_de),.i_rgb(tr_rgb),
 .config_data(display_config),.page_event(page_event),.page_index(active_view[4:2]),.dual_enable(active_view[5]),
 .page_reverse(active_view[11]),.focus(active_view[10:8]),
 .audio_peak(visual_peak),.audio_status(wav_status),.o_hs(fx_hs),.o_vs(fx_vs),.o_de(fx_de),.o_rgb(fx_rgb));
// WAV EOF originates in the audio clock domain. Restart only after its rising
// edge reaches SD100; page changes and mask phases never reset audio playback.
(* async_reg="true" *) reg [2:0] wav_eof_sync;
always @(posedge sd_card_clk)begin
 if(sd_rst)wav_eof_sync<=0;else wav_eof_sync<={wav_eof_sync[1:0],wav_eof};
end
wire wav_restart=wav_eof_sync[1]&&!wav_eof_sync[2];'''+s[a1:]
s=s.replace('.restart(1\'b0)', '.restart(wav_restart)')
s=s.replace('display_commit frame_commit(', 'display_commit #(.BUFFER_BITS(12),.REQUIRE_INITIAL_COMMIT(1)) frame_commit(')
s=s.replace('.candidate_async(disp_buf_idx)', '.candidate_async(candidate_view)')
s=s.replace('.active_buf(active_buf_idx)', '.active_buf(active_view)')
a0=s.index('sd_card_bmp #(');a1=s.index(') sd_card_bmp_m0(',a0)
s=s[:a0]+'''legacy_exhibit_media #(
    .CLK_FREQ_HZ(100_000_000),.SCAN_START_SECTOR(32'd0),.SCAN_MAX_SECTOR(32'd131071)
'''+s[a1:]
s=s.replace('.control_mode(control_mode),.brightness(brightness),.contrast(contrast),.interval_seconds(interval_seconds),', '.control_mode(control_mode),.brightness(brightness),.contrast(contrast),.interval_seconds(interval_seconds),.interval_fraction(interval_fraction),')
s=s.replace('    .bmp_width         (16\'d640),\n    .bmp_height        (16\'d480),\n','')
s=s.replace('    .disp_buf_idx      (disp_buf_idx),','''    .candidate_view(candidate_view),.cover_request_toggle(cover_request_toggle),
    .cover_ack_toggle_async(cover_ack_toggle),.transition_busy_async(transition_busy),''')
s='// NO_BOT_LEGACY_INTEGRATED: generated by scripts/no_bot_apply_legacy.py\n'+s
record('rtl/top_tf_hdmi_audio.v',s.encode(),str(src/'top_tf_hdmi_audio.v'),'old sequential two-frame top; explicit six-page loader/metadata/OSD/mask/WAV-loop adapter')
# Keep only the old memory, IO, audio, and small current OSD support modules.
project=ROOT/'project/td_project/hx4s20_basic.al';s=project.read_text(encoding='utf-8')
remove={'sd_card_bmp.v','bmp_read.v','video_extensions.v','osd_overlay.v',
'html_panel_loader.v','html_read_tags.v','html_memory_bridge.v','exhibit_viewport.v',
'html_resource_locator.v','html_scene_loader.v','html_scene_motion.v'}
def filt(m):
 path=m[1];name=path.rsplit('/',1)[-1]
 return '' if name in remove or name.startswith('html_layer_') or name in ('legacy_exhibit_media.v','legacy_exhibit_loader.v') else m[0]
s=re.sub(r'            <File Path="([^"]+)">\s*<FileInfo>.*?</FileInfo>\s*</File>\n',filt,s,flags=re.S)
for order,name in enumerate(['legacy_exhibit_media.v','legacy_exhibit_loader.v'],95):
 entry=f'''            <File Path="../user_source/hdl_source/ext/{name}">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true"/>
                    <Attr Name="UsedInP&amp;R" Val="true"/>
                    <Attr Name="BelongTo" Val="design_1"/>
                    <Attr Name="CompileOrder" Val="{order}"/>
                </FileInfo>
            </File>
'''.replace('P&amp;R','P&R')
 s=s.replace('        </Verilog>',entry+'        </Verilog>')
record('project/td_project/hx4s20_basic.al',s.replace('\n','\r\n').encode(),'current project whitelist','removed all new cache/panel/scene entries; preserved IO/IP/constraints')
(out/'legacy_integration_sources.json').write_text(json.dumps(dict(created_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),baseline=str(b),changes=rows),indent=2),encoding='utf-8')
print(json.dumps({'status':'APPLIED','files':len(rows),'manifest':str(out/'legacy_integration_sources.json')}))
