from pathlib import Path
import re,json,hashlib
r=Path('D:/FPGA/EG4S20-Multimedia-Signage')
def edit(name,fn):
 p=r/name;s=p.read_text(encoding='utf-8')
 if '// HTML_FIDELITY_INTEGRATED' in s:return
 old=s;s=fn(s);assert old!=s,name
 p.write_text('// HTML_FIDELITY_INTEGRATED\n'+s,encoding='utf-8')
def commit(s):
 s=s.replace('module display_commit(', 'module display_commit #(parameter BUFFER_BITS=2)(')
 s=s.replace('input [1:0] candidate_async','input [BUFFER_BITS-1:0] candidate_async').replace('output reg [1:0] active_buf','output reg [BUFFER_BITS-1:0] active_buf')
 return s.replace('reg [1:0] candidate_meta, candidate_sync, previous_buf;', 'reg [BUFFER_BITS-1:0] candidate_meta, candidate_sync, previous_buf;')
edit('rtl/display_commit.v',commit)
def reader(s):
 s=re.sub(r'(parameter BURST_SIZE\s*=\s*128)',r'parameter READ_DRAIN_CYCLES=10,\n\t\1',s)
 s=s.replace("rd_delay == 4'd10",'rd_delay == READ_DRAIN_CYCLES').replace("rd_delay < 4'd10",'rd_delay < READ_DRAIN_CYCLES')
 return s
edit('rtl/SD/frame_fifo_read.v',reader)
def writer(s):
 s=s.replace('parameter WRITE_V_FLIP', 'parameter ENABLE_LINEAR_CONFIG=0,\n\tparameter WRITE_V_FLIP',1)
 s=s.replace('input                            rst,','input write_linear,\n\tinput                            rst,',1)
 s=s.replace('localparam ONE', 'reg [1:0] linear_sync;\nreg linear_latched;\nalways @(posedge mem_clk or posedge rst)\n if(rst)begin linear_sync<=0;linear_latched<=0;end\n else begin linear_sync<={linear_sync[0],(ENABLE_LINEAR_CONFIG ? write_linear : 1\'b0)};\n if(state==S_ACK)linear_latched<=linear_sync[1];end\nlocalparam ONE',1)
 s=s.replace('WRITE_V_FLIP ? (write_addr_', '(WRITE_V_FLIP && !linear_sync[1]) ? (write_addr_')
 s=s.replace('if(WRITE_V_FLIP)', 'if(WRITE_V_FLIP && !linear_latched)')
 return s
edit('rtl/SD/frame_fifo_write.v',writer)
def frame(s):
 s=s.replace('parameter WRITE_V_FLIP', 'parameter READ_DRAIN_CYCLES=10, ENABLE_LINEAR_CONFIG=0,\n\tparameter WRITE_V_FLIP',1)
 s=s.replace('input display_valid_video,','input write_linear,\n\tinput display_valid_video,',1)
 a,b=s.split('frame_fifo_write\n',1)
 b=b.replace('.WRITE_V_FLIP', '.ENABLE_LINEAR_CONFIG(ENABLE_LINEAR_CONFIG),\n\t.WRITE_V_FLIP',1)
 b=b.replace('.rst                        (mem_reset', '.write_linear(write_linear),\n\t.rst                        (mem_reset',1)
 s=a+'frame_fifo_write\n'+b
 a,b=s.split('frame_fifo_read\n',1);b=b.replace('.MEM_DATA_BITS', '.READ_DRAIN_CYCLES(READ_DRAIN_CYCLES),\n\t.MEM_DATA_BITS',1)
 return a+'frame_fifo_read\n'+b
edit('rtl/SD/frame_read_write.v',frame)
def top(s):
 declaration='''
wire [3:0] active_view;
wire [2:0] candidate_page,write_page,zoom_focus,video_focus;
wire candidate_compare;
wire [5:0] page_ready;
wire cache_preload_done,cache_loading;
wire [31:0] resource_sector1,resource_sector2,resource_sector3,resource_sector4;
wire panel_active,panel_ready,panel_error,panel_req,panel_valid,panel_end,panel_sd_error;
wire [31:0] panel_addr,panel_write_data;
wire [7:0] panel_data;
wire panel_write_req,panel_write_en,write_ack;
wire [20:0] panel_write_base,panel_write_len;
wire raw_App_rd_en,frame_fifo_fault,tag_fault;
wire [20:0] raw_App_rd_addr;
wire [31:0] mapped_read_data;
wire [20:0] page_write_base=write_page*21'd307200;
wire [20:0] current_write_base=panel_active?panel_write_base:page_write_base;
reg commit_previous;
wire page_event=commit_ack_toggle^commit_previous;
always @(posedge video_clk)if(video_rst)commit_previous<=0;else commit_previous<=commit_ack_toggle;
assign fifo_fault=frame_fifo_fault|tag_fault;
assign sd_card_write_req_ack=write_ack&&!panel_active;
frame_config_bridge #(.WIDTH(3),.RESET_VALUE(0)) focus_bridge(
 .src_clk(sd_card_clk),.src_rst(sd_rst),.src_config(zoom_focus),
 .dst_clk(video_clk),.dst_rst(video_rst),.dst_frame(vs&&!config_prev_vs),.dst_config(video_focus));
html_panel_loader panels(.clk(sd_card_clk),.rst(sd_rst),.enable(cache_preload_done),
 .sector1(resource_sector1),.sector2(resource_sector2),.sector3(resource_sector3),.sector4(resource_sector4),
 .active(panel_active),.ready(panel_ready),.error(panel_error),.sector_req(panel_req),.sector_addr(panel_addr),
 .sector_data(panel_data),.sector_valid(panel_valid),.sector_end(panel_end),.sector_error(panel_sd_error),
 .write_req(panel_write_req),.write_req_ack(write_ack&&panel_active),.write_en(panel_write_en),
 .write_data(panel_write_data),.write_base(panel_write_base),.write_len(panel_write_len),.write_finish_toggle(frame_write_toggle_mem));
html_memory_bridge view_reader(.mem_clk(ext_mem_clk),.rst(mem_rst),.video_read_req(video_read_req),
 .active_view(active_view),.zoom(cfg_scale),.transition_mode(cfg_transition),.focus(video_focus),.panels_ready(panel_ready),
 .raw_read_en(raw_App_rd_en),.read_en(App_rd_en),.read_addr(App_rd_addr),
 .response(Sdr_rd_en),.memory_data(Sdr_rd_dout),.pixel_data(mapped_read_data),.fault(tag_fault));
'''
 s=s.replace('reg timing_req_prev;',declaration+'\nreg timing_req_prev;',1)
 start=s.index('video_transition transition(');end=s.index('reg config_prev_vs;',start)
 s=s[:start]+'''assign forwarded_commit_toggle=commit_toggle;
assign tr_hs=hs;assign tr_vs=vs;assign tr_de=de;assign tr_rgb=vout_data;
assign transition_busy=1'b0;
'''+s[end:]
 start=s.index('video_extensions #');end=s.index('audio_output_mux audio_output',start)
 s=s[:start]+'''html_video_overlay extensions(.clk(video_clk),.rst(video_rst),.i_hs(tr_hs),.i_vs(tr_vs),.i_de(tr_de),.i_rgb(tr_rgb),
 .config_data(video_config),.page_event(page_event),.page_index(active_view[2:0]),.dual_enable(active_view[3]),
 .audio_peak(visual_peak),.audio_status(wav_status),.o_hs(fx_hs),.o_vs(fx_vs),.o_de(fx_de),.o_rgb(fx_rgb));

'''+s[end:]
 s=s.replace('display_commit frame_commit(', 'display_commit #(.BUFFER_BITS(4)) frame_commit(')
 s=s.replace('.candidate_async(disp_buf_idx)', '.candidate_async({candidate_compare,candidate_page})').replace('.active_buf(active_buf_idx)', '.active_buf(active_view)')
 s=s.replace('.ENABLE_AUDIO(1),.ENABLE_SCALING(1)', '.ENABLE_AUDIO(1),.ENABLE_SCALING(1),.ENABLE_EXHIBIT(1)')
 s=s.replace('.SCAN_TARGET_COUNT (4\'d8)', '.SCAN_TARGET_COUNT (4\'d6)')
 s=s.replace(') sd_card_bmp_m0(',''') sd_card_bmp_m0(
    .candidate_page(candidate_page),.candidate_compare(candidate_compare),.write_page(write_page),.page_ready(page_ready),
    .zoom_focus(zoom_focus),.compare_panels_ready(panel_ready),.cache_loading(cache_loading),.cache_preload_done(cache_preload_done),
    .resource_sector1(resource_sector1),.resource_sector2(resource_sector2),.resource_sector3(resource_sector3),.resource_sector4(resource_sector4),
    .panel_req(panel_req),.panel_addr(panel_addr),.panel_active(panel_active),.panel_data(panel_data),
    .panel_valid(panel_valid),.panel_end(panel_end),.panel_error(panel_sd_error),''')
 start=s.index('frame_read_write #(');end=s.index('\nsdram U3(',start)
 q=s[start:end].replace('.WRITE_V_FLIP     (1)', '.WRITE_V_FLIP     (1),.READ_DRAIN_CYCLES(13),.ENABLE_LINEAR_CONFIG(1)')
 q=q.replace('.mem_clk           (ext_mem_clk)', '.write_linear(panel_active),\n    .mem_clk           (ext_mem_clk)')
 q=q.replace('.fifo_fault(fifo_fault)', '.fifo_fault(frame_fifo_fault)')
 q=q.replace('.App_rd_en         (App_rd_en)', '.App_rd_en         (raw_App_rd_en)').replace('.App_rd_addr       (App_rd_addr)', '.App_rd_addr       (raw_App_rd_addr)')
 q=q.replace('.Sdr_rd_dout       (Sdr_rd_dout)', '.Sdr_rd_dout       (mapped_read_data)')
 q=q.replace('.read_addr_0       (BUF0_ADDR)', ".read_addr_0       (21'd0)").replace('.read_addr_1       (BUF1_ADDR)', ".read_addr_1       (21'd0)").replace('.read_addr_index   (active_buf_idx)', ".read_addr_index   (2'd0)")
 q=q.replace('.write_req         (sd_card_write_req)', '.write_req         (panel_active?panel_write_req:sd_card_write_req)').replace('.write_req_ack     (sd_card_write_req_ack)', '.write_req_ack     (write_ack)')
 for i,old in [(0,'BUF0_ADDR'),(1,'BUF1_ADDR'),(2,"24'd0"),(3,"24'd0")]:q=q.replace(f'.write_addr_{i}      ({old})',f'.write_addr_{i}      (current_write_base)')
 q=q.replace('.write_addr_index  (write_buf_idx)', ".write_addr_index  (2'd0)")
 q=q.replace('.write_len         (FRAME_PIXELS)', '.write_len         (panel_active?panel_write_len:FRAME_PIXELS)')
 q=q.replace('.write_en          (sd_card_write_en)', '.write_en          (panel_active?panel_write_en:sd_card_write_en)').replace('.write_data        (sd_card_write_data)', '.write_data        (panel_active?panel_write_data:sd_card_write_data)')
 return s[:start]+q+s[end:]
edit('rtl/top_tf_hdmi_audio.v',top)
p=r/'project/td_project/hx4s20_basic.al';s=p.read_text()
modules=['html_panel_loader','html_read_tags','html_memory_bridge','html_video_overlay','html_bot_overlay','html_osd_overlay','exhibit_viewport']
for i,n in enumerate(modules):
 path='../user_source/hdl_source/ext/'+n+'.v'
 if path not in s:s=s.replace('        </Verilog>',f'''            <File Path="{path}"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="{70+i}"/></FileInfo></File>
        </Verilog>''')
p.write_text(s)
print('ROOT_INTEGRATION_APPLIED')
