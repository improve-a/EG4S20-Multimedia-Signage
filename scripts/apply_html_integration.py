#!/usr/bin/env python3
# Apply authored top-level and linear-write integration to local dependencies.
# Restore docs/local_dependencies.json first. Apply the SD and memory-controller
# scripts separately, then this script. Tracked project configuration and authored
# modules already come from Git. Only integration deltas are embedded here.
import argparse,hashlib,json,pathlib
FILES={'rtl/top_tf_hdmi_audio.v': {'baseline_sha256': 'f892f0c7d1cc9e267a3263bb4163aa12b1c6291f95727c721cb400022aa8cc2b',
                             'baseline_text_sha256': 'f892f0c7d1cc9e267a3263bb4163aa12b1c6291f95727c721cb400022aa8cc2b',
                             'result_text_sha256': '08fb977ed84393224a64e4e07fe70520b03bae9f06489b8afb3940d8a9b3799e',
                             'edits': [{'start': 0,
                                        'end': 0,
                                        'old': [],
                                        'new': ['// HTML_FIDELITY_INTEGRATED\n']},
                                       {'start': 158,
                                        'end': 158,
                                        'old': [],
                                        'new': ['\n',
                                                'reg config_prev_vs;\n',
                                                'wire [4:0] active_view;\n',
                                                'wire [2:0] '
                                                'candidate_page,write_page,zoom_focus,video_focus;\n',
                                                'wire candidate_compare,candidate_reverse;\n',
                                                'wire [5:0] page_ready;\n',
                                                'wire cache_preload_done,cache_loading;\n',
                                                'wire [31:0] '
                                                'resource_sector1,resource_sector2,resource_sector3,resource_sector4;\n',
                                                'wire '
                                                'panel_active,panel_ready,panel_error,panel_req,panel_valid,panel_end,panel_sd_error;\n',
                                                'wire [31:0] panel_addr,panel_write_data;\n',
                                                'wire [7:0] panel_data;\n',
                                                'wire panel_write_req,panel_write_en,write_ack;\n',
                                                'wire [20:0] panel_write_base,panel_write_len;\n',
                                                'wire '
                                                'raw_App_rd_en,frame_fifo_fault,tag_fault,read_accept_mem;\n',
                                                'wire '
                                                'logical_ready,logical_response,view_reader_busy,write_busy_mem;\n',
                                                'wire [20:0] raw_App_rd_addr;\n',
                                                'wire [31:0] mapped_read_data;\n',
                                                "wire [20:0] page_write_base=write_page*21'd307200;\n",
                                                'wire [20:0] '
                                                'current_write_base=panel_active?panel_write_base:page_write_base;\n',
                                                'reg commit_previous;\n',
                                                'wire page_event=commit_ack_toggle^commit_previous;\n',
                                                'always @(posedge '
                                                'video_clk)if(video_rst)commit_previous<=0;else '
                                                'commit_previous<=commit_ack_toggle;\n',
                                                'assign fifo_fault=frame_fifo_fault|tag_fault;\n',
                                                'assign '
                                                'sd_card_write_req_ack=write_ack&&!panel_active;\n',
                                                'frame_config_bridge #(.WIDTH(3),.RESET_VALUE(0)) '
                                                'focus_bridge(\n',
                                                ' '
                                                '.src_clk(sd_card_clk),.src_rst(sd_rst),.src_config(zoom_focus),\n',
                                                ' '
                                                '.dst_clk(video_clk),.dst_rst(video_rst),.dst_frame(vs&&!config_prev_vs),.dst_config(video_focus));\n',
                                                'html_panel_loader '
                                                'panels(.clk(sd_card_clk),.rst(sd_rst),.enable(cache_preload_done),\n',
                                                ' '
                                                '.sector1(resource_sector1),.sector2(resource_sector2),.sector3(resource_sector3),.sector4(resource_sector4),\n',
                                                ' '
                                                '.active(panel_active),.ready(panel_ready),.error(panel_error),.sector_req(panel_req),.sector_addr(panel_addr),\n',
                                                ' '
                                                '.sector_data(panel_data),.sector_valid(panel_valid),.sector_end(panel_end),.sector_error(panel_sd_error),\n',
                                                ' '
                                                '.write_req(panel_write_req),.write_req_ack(write_ack&&panel_active),.write_en(panel_write_en),\n',
                                                ' '
                                                '.write_data(panel_write_data),.write_base(panel_write_base),.write_len(panel_write_len),.write_finish_toggle(frame_write_toggle_mem));\n',
                                                'html_memory_bridge '
                                                'view_reader(.mem_clk(ext_mem_clk),.rst(mem_rst),.video_read_req(video_read_req),.read_accept_mem(read_accept_mem),\n',
                                                ' '
                                                '.active_view(active_view),.zoom(cfg_scale),.transition_mode(cfg_transition),.focus(video_focus),.panels_ready(panel_ready),\n',
                                                ' '
                                                '.write_busy_mem(write_busy_mem),.mem_ready(Sdr_init_done),.refresh_active(Sdr_init_ref_vld),\n',
                                                ' '
                                                '.logical_ready(logical_ready),.logical_response(logical_response),.busy(view_reader_busy),\n',
                                                ' '
                                                '.raw_read_en(raw_App_rd_en),.read_en(App_rd_en),.read_addr(App_rd_addr),\n',
                                                ' '
                                                '.response(Sdr_rd_en),.memory_data(Sdr_rd_dout),.pixel_data(mapped_read_data),.fault(tag_fault));\n',
                                                '\n']},
                                       {'start': 162,
                                        'end': 168,
                                        'old': ['video_transition '
                                                'transition(.clk(video_clk),.rst(video_rst),.i_hs(hs),.i_vs(vs),.i_de(de),.i_rgb(vout_data),\n',
                                                ' '
                                                '.enable(display_valid_sync[1]),.mode(cfg_transition),.frame_start(timing_read_req&&!timing_req_prev),\n',
                                                ' '
                                                '.candidate_toggle_async(commit_toggle),.commit_ack_toggle(commit_ack_toggle),\n',
                                                ' '
                                                '.forwarded_commit_toggle(forwarded_commit_toggle),.o_hs(tr_hs),.o_vs(tr_vs),.o_de(tr_de),.o_rgb(tr_rgb),\n',
                                                ' .transition_busy(transition_busy));\n',
                                                'reg config_prev_vs;\n'],
                                        'new': ['assign forwarded_commit_toggle=commit_toggle;\n',
                                                'assign tr_hs=hs;assign tr_vs=vs;assign tr_de=de;assign '
                                                'tr_rgb=vout_data;\n',
                                                "assign transition_busy=1'b0;\n"]},
                                       {'start': 176,
                                        'end': 178,
                                        'old': ['video_extensions #(.ENABLE_AUDIO_VIS(1)) '
                                                'extensions(.clk(video_clk),.rst(video_rst),.i_hs(tr_hs),.i_vs(tr_vs),.i_de(tr_de),.i_rgb(tr_rgb),\n',
                                                ' '
                                                '.config_data(video_config),.sample_valid(audio_valid),.sample_left(audio_left_data),.sample_right(audio_right_data),\n'],
                                        'new': ['html_video_overlay '
                                                'extensions(.clk(video_clk),.rst(video_rst),.i_hs(tr_hs),.i_vs(tr_vs),.i_de(tr_de),.i_rgb(tr_rgb),\n',
                                                ' '
                                                '.config_data(video_config),.page_event(page_event),.page_index(active_view[2:0]),.dual_enable(active_view[3]),.page_reverse(active_view[4]),.focus(video_focus),\n']},
                                       {'start': 179, 'end': 181, 'old': ['\n', '\n'], 'new': []},
                                       {'start': 236,
                                        'end': 237,
                                        'old': ['display_commit frame_commit(\n'],
                                        'new': ['display_commit #(.BUFFER_BITS(5)) frame_commit(\n']},
                                       {'start': 239,
                                        'end': 241,
                                        'old': [' '
                                                '.commit_toggle_async(forwarded_commit_toggle),.candidate_async(disp_buf_idx),.fault_async(fifo_fault),\n',
                                                ' '
                                                '.active_buf(active_buf_idx),.commit_ack_toggle(commit_ack_toggle));\n'],
                                        'new': [' '
                                                '.commit_toggle_async(forwarded_commit_toggle),.candidate_async({candidate_reverse,candidate_compare,candidate_page}),.fault_async(fifo_fault),\n',
                                                ' '
                                                '.active_buf(active_view),.commit_ack_toggle(commit_ack_toggle));\n']},
                                       {'start': 279,
                                        'end': 280,
                                        'old': ['    .ENABLE_AUDIO(1),.ENABLE_SCALING(1),\n'],
                                        'new': ['    '
                                                '.ENABLE_AUDIO(1),.ENABLE_SCALING(1),.ENABLE_EXHIBIT(1),\n']},
                                       {'start': 282,
                                        'end': 283,
                                        'old': ["    .SCAN_TARGET_COUNT (4'd8),\n"],
                                        'new': ["    .SCAN_TARGET_COUNT (4'd6),\n"]},
                                       {'start': 285,
                                        'end': 285,
                                        'old': [],
                                        'new': ['    '
                                                '.candidate_page(candidate_page),.candidate_compare(candidate_compare),.candidate_reverse(candidate_reverse),.write_page(write_page),.page_ready(page_ready),\n',
                                                '    '
                                                '.zoom_focus(zoom_focus),.compare_panels_ready(panel_ready),.cache_loading(cache_loading),.cache_preload_done(cache_preload_done),\n',
                                                '    '
                                                '.resource_sector1(resource_sector1),.resource_sector2(resource_sector2),.resource_sector3(resource_sector3),.resource_sector4(resource_sector4),\n',
                                                '    '
                                                '.panel_req(panel_req),.panel_addr(panel_addr),.panel_active(panel_active),.panel_data(panel_data),\n',
                                                '    '
                                                '.panel_valid(panel_valid),.panel_end(panel_end),.panel_error(panel_sd_error),\n']},
                                       {'start': 364,
                                        'end': 365,
                                        'old': ['    .WRITE_V_FLIP     (1),\n'],
                                        'new': ['    .WRITE_V_FLIP     '
                                                '(1),.READ_DRAIN_CYCLES(13),.ENABLE_LINEAR_CONFIG(1),.ENABLE_READ_SOURCE(1),\n']},
                                       {'start': 368,
                                        'end': 368,
                                        'old': [],
                                        'new': ['    '
                                                '.read_source_ready(logical_ready),.read_source_busy(view_reader_busy),.write_busy_mem(write_busy_mem),\n',
                                                '    '
                                                '.read_accept_mem(read_accept_mem),.write_linear(panel_active),\n']},
                                       {'start': 369,
                                        'end': 370,
                                        'old': ['    '
                                                '.display_valid_video(display_valid_sync[1]),.fifo_fault(fifo_fault),\n'],
                                        'new': ['    '
                                                '.display_valid_video(display_valid_sync[1]),.fifo_fault(frame_fifo_fault),\n']},
                                       {'start': 375,
                                        'end': 379,
                                        'old': ['    .App_rd_en         (App_rd_en),\n',
                                                '    .App_rd_addr       (App_rd_addr),\n',
                                                '    .Sdr_rd_en         (Sdr_rd_en),\n',
                                                '    .Sdr_rd_dout       (Sdr_rd_dout),\n'],
                                        'new': ['    .App_rd_en         (raw_App_rd_en),\n',
                                                '    .App_rd_addr       (raw_App_rd_addr),\n',
                                                '    .Sdr_rd_en         (logical_response),\n',
                                                '    .Sdr_rd_dout       (mapped_read_data),\n']},
                                       {'start': 384,
                                        'end': 386,
                                        'old': ['    .read_addr_0       (BUF0_ADDR),\n',
                                                '    .read_addr_1       (BUF1_ADDR),\n'],
                                        'new': ["    .read_addr_0       (21'd0),\n",
                                                "    .read_addr_1       (21'd0),\n"]},
                                       {'start': 388,
                                        'end': 389,
                                        'old': ['    .read_addr_index   (active_buf_idx),\n'],
                                        'new': ["    .read_addr_index   (2'd0),\n"]},
                                       {'start': 399,
                                        'end': 401,
                                        'old': ['    .write_req         (sd_card_write_req),\n',
                                                '    .write_req_ack     (sd_card_write_req_ack),\n'],
                                        'new': ['    .write_req         '
                                                '(panel_active?panel_write_req:sd_card_write_req),\n',
                                                '    .write_req_ack     (write_ack),\n']},
                                       {'start': 402,
                                        'end': 410,
                                        'old': ['    .write_addr_0      (BUF0_ADDR),\n',
                                                '    .write_addr_1      (BUF1_ADDR),\n',
                                                "    .write_addr_2      (24'd0),\n",
                                                "    .write_addr_3      (24'd0),\n",
                                                '    .write_addr_index  (write_buf_idx),\n',
                                                '    .write_len         (FRAME_PIXELS),\n',
                                                '    .write_en          (sd_card_write_en),\n',
                                                '    .write_data        (sd_card_write_data)\n'],
                                        'new': ['    .write_addr_0      (current_write_base),\n',
                                                '    .write_addr_1      (current_write_base),\n',
                                                '    .write_addr_2      (current_write_base),\n',
                                                '    .write_addr_3      (current_write_base),\n',
                                                "    .write_addr_index  (2'd0),\n",
                                                '    .write_len         '
                                                '(panel_active?panel_write_len:FRAME_PIXELS),\n',
                                                '    .write_en          '
                                                '(panel_active?panel_write_en:sd_card_write_en),\n',
                                                '    .write_data        '
                                                '(panel_active?panel_write_data:sd_card_write_data)\n']}]},
 'rtl/SD/frame_fifo_write.v': {'baseline_sha256': '13c687ddc6e0e446c1029986223cab38df48e8a3bdfcbcfa190717e990753cf2',
                               'baseline_text_sha256': '13c687ddc6e0e446c1029986223cab38df48e8a3bdfcbcfa190717e990753cf2',
                               'result_text_sha256': '51d6c801f8b617cbd677f30969ddcb727fbf8fde551dcc438e1277c973e3ec79',
                               'edits': [{'start': 0,
                                          'end': 0,
                                          'old': [],
                                          'new': ['// HTML_FIDELITY_INTEGRATED\n']},
                                         {'start': 8,
                                          'end': 8,
                                          'old': [],
                                          'new': ['\tparameter ENABLE_LINEAR_CONFIG=0,\n']},
                                         {'start': 13,
                                          'end': 13,
                                          'old': [],
                                          'new': ['\tinput write_linear,\n']},
                                         {'start': 42,
                                          'end': 42,
                                          'old': [],
                                          'new': ['reg [1:0] linear_sync;\n',
                                                  'reg linear_latched;\n',
                                                  'always @(posedge mem_clk or posedge rst)\n',
                                                  ' if(rst)begin linear_sync<=0;linear_latched<=0;end\n',
                                                  ' else begin '
                                                  'linear_sync<={linear_sync[0],(ENABLE_LINEAR_CONFIG ? '
                                                  "write_linear : 1'b0)};\n",
                                                  ' '
                                                  'if(state==S_ACK)linear_latched<=linear_sync[1];end\n']},
                                         {'start': 138,
                                          'end': 139,
                                          'old': ['\t\t\t\t\tApp_wr_addr_r <= WRITE_V_FLIP ? '
                                                  '(write_addr_0 + VFLIP_FIRST_ADDR_OFFSET) : '
                                                  'write_addr_0;\n'],
                                          'new': ['\t\t\t\t\tApp_wr_addr_r <= (WRITE_V_FLIP && '
                                                  '!linear_sync[1]) ? (write_addr_0 + '
                                                  'VFLIP_FIRST_ADDR_OFFSET) : write_addr_0;\n']},
                                         {'start': 140,
                                          'end': 141,
                                          'old': ['\t\t\t\t\tApp_wr_addr_r <= WRITE_V_FLIP ? '
                                                  '(write_addr_1 + VFLIP_FIRST_ADDR_OFFSET) : '
                                                  'write_addr_1;\n'],
                                          'new': ['\t\t\t\t\tApp_wr_addr_r <= (WRITE_V_FLIP && '
                                                  '!linear_sync[1]) ? (write_addr_1 + '
                                                  'VFLIP_FIRST_ADDR_OFFSET) : write_addr_1;\n']},
                                         {'start': 142,
                                          'end': 143,
                                          'old': ['\t\t\t\t\tApp_wr_addr_r <= WRITE_V_FLIP ? '
                                                  '(write_addr_2 + VFLIP_FIRST_ADDR_OFFSET) : '
                                                  'write_addr_2;\n'],
                                          'new': ['\t\t\t\t\tApp_wr_addr_r <= (WRITE_V_FLIP && '
                                                  '!linear_sync[1]) ? (write_addr_2 + '
                                                  'VFLIP_FIRST_ADDR_OFFSET) : write_addr_2;\n']},
                                         {'start': 144,
                                          'end': 145,
                                          'old': ['\t\t\t\t\tApp_wr_addr_r <= WRITE_V_FLIP ? '
                                                  '(write_addr_3 + VFLIP_FIRST_ADDR_OFFSET) : '
                                                  'write_addr_3;\n'],
                                          'new': ['\t\t\t\t\tApp_wr_addr_r <= (WRITE_V_FLIP && '
                                                  '!linear_sync[1]) ? (write_addr_3 + '
                                                  'VFLIP_FIRST_ADDR_OFFSET) : write_addr_3;\n']},
                                         {'start': 148,
                                          'end': 149,
                                          'old': ['\t\t\t\tif(WRITE_V_FLIP)\n'],
                                          'new': ['\t\t\t\tif(WRITE_V_FLIP && !linear_latched)\n']}]}}

def digest(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()

def apply_text(relative,text):
    text=text.replace("\r\n","\n")
    spec=FILES[relative]
    if digest(text)==spec["result_text_sha256"]:
        return text,False
    if digest(text)!=spec["baseline_text_sha256"]:
        raise ValueError(relative+": source differs from both the verified baseline and the integration result; preserve and inspect it. SHA256="+digest(text))
    lines=text.splitlines(keepends=True)
    for edit in reversed(spec["edits"]):
        if lines[edit["start"]:edit["end"]]!=edit["old"]:
            raise ValueError(relative+": baseline context mismatch")
        lines[edit["start"]:edit["end"]]=edit["new"]
    result="".join(lines)
    if digest(result)!=spec["result_text_sha256"]:
        raise ValueError(relative+": internal patch result hash mismatch")
    return result,True

def apply(root,check=False):
    planned=[]
    # Validate every file before writing any of them.
    for relative,spec in FILES.items():
        path=pathlib.Path(root)/relative
        raw=path.read_bytes()
        result,changed=apply_text(relative,raw.decode("utf-8"))
        planned.append((path,raw,result,changed,relative))
    report=[]
    for path,raw,result,changed,relative in planned:
        if changed and not check:
            path.write_bytes(result.encode("utf-8"))
        report.append({"path":str(path),"state":"APPLICABLE" if changed and check else "APPLIED" if changed else "UNCHANGED","before_sha256":hashlib.sha256(raw).hexdigest(),"result_text_sha256":digest(result),"baseline_manifest_sha256":FILES[relative]["baseline_sha256"]})
    return report

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root",type=pathlib.Path,default=pathlib.Path(__file__).resolve().parents[1])
    parser.add_argument("--check",action="store_true")
    args=parser.parse_args()
    print(json.dumps(apply(args.root,args.check)))

if __name__=="__main__":
    main()
