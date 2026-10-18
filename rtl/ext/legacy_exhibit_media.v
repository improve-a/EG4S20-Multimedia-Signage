// Six-page catalogue and load/commit sequencing for the ext_full_005 two-buffer
// sequential scanout. No page cache, random SDRAM request, or second scanout.
module legacy_exhibit_media #(
 parameter CLK_FREQ_HZ=100_000_000, DEBOUNCE_MS=20, LONG_PRESS_MS=1000,
 parameter LOAD_TIMEOUT_SECONDS=10,
 parameter [31:0] SCAN_START_SECTOR=0,SCAN_MAX_SECTOR=131071
)(
 input clk,rst,key_next,key_auto,key_pause_mute,
 output reg display_valid, output [3:0] state_code,
 output audio_muted,auto_mode_out,paused_out,
 output [2:0] control_mode,contrast,
 output signed [8:0] brightness,
 output [7:0] interval_seconds, output [3:0] interval_fraction,
 output osd_enable, output [1:0] transition_mode,scale_mode,
 output [3:0] volume, output reg [7:0] progress,
 output reg cover_request_toggle, input cover_ack_toggle_async,
 input transition_busy_async,
 output reg [11:0] candidate_view,
 output reg commit_toggle,input display_commit_ack_toggle,
 input write_finish_toggle,storage_fault_async,
 output reg [1:0] write_buf_idx,
 output write_req,input write_req_ack,output write_en,output [31:0] write_data,
 input audio_sector_req,input [31:0] audio_sector_addr,input audio_sector_urgent,
 output audio_sector_grant,output [7:0] audio_sector_data,
 output audio_sector_valid,audio_sector_end,audio_sector_error,output sd_ready_out,
 output SD_nCS,SD_DCLK,SD_MOSI,input SD_MISO
);
 wire sd_init_done,sd_init_error;
 wire physical_req,physical_valid,physical_end,physical_error;
 wire [31:0] physical_addr;
 wire [7:0] physical_data;
 wire bmp_req,bmp_valid,bmp_end,bmp_error;
 wire [31:0] bmp_addr;wire [7:0] bmp_data;
 wire scan_req,scan_ready,scan_done,scan_found_valid;
 wire [31:0] scan_addr,scan_found_sector;
 wire [3:0] scan_found_total,scan_error,scan_state;
 wire loader_req,loader_ready,loader_busy,loader_done;
 wire [31:0] loader_addr;wire [3:0] loader_error;
 wire [23:0] loader_pixel;
 reg scan_start,scan_kicked,catalog_ready,load_start,load_abort;
 reg [31:0] catalog[0:9];
 reg [3:0] found_count;
 reg [31:0] left_sector,right_sector;
 reg [3:0] fault_code;
 wire next_pulse,prev_pulse,mode_changed,param_changed,dual_changed;
 wire dual;wire [2:0] focus;wire [15:0] interval_ms;
 reg [2:0] desired_page;
 reg desired_reverse;
 reg [11:0] committed_view;
 reg [31:0] ms_count,load_watchdog;
 reg [15:0] elapsed_ms,progress_phase;
 wire [16:0] progress_sum={1'b0,progress_phase}+17'd255;
 wire ms_tick=ms_count>=(CLK_FREQ_HZ/1000)-1;
 wire auto_tick=ms_tick && elapsed_ms>=interval_ms-1'b1;
 (* async_reg="true" *) reg [2:0] wrfin_sync;
 (* async_reg="true" *) reg [1:0] ack_sync,cover_sync,busy_sync,fault_sync;
 wire wrfin_event=wrfin_sync[2]^wrfin_sync[1];
 reg source_done,write_done;
 localparam SCAN=0,IDLE=1,COVER=2,LOAD=3,COMMIT=4,REVEAL=5,FAILED=6;
 reg [2:0] state;
 integer i;
 wire config_dirty=!display_valid || desired_page!=committed_view[4:2] ||
                   dual!=committed_view[5] || scale_mode!=committed_view[7:6] ||
                   focus!=committed_view[10:8];
 assign sd_ready_out=sd_init_done;
 assign state_code=sd_init_error?4'he:fault_code!=0?fault_code:
                   !catalog_ready?scan_state:paused_out?4'h9:
                   (state==IDLE && auto_mode_out)?4'h8:{1'b0,state};
 assign bmp_req=catalog_ready?loader_req:scan_req;
 assign bmp_addr=catalog_ready?loader_addr:scan_addr;
 assign write_data={loader_pixel,8'd0};
 // Complete response bundle is pipelined together, retaining the measured
 // timing repair between the existing SD arbiter and the byte consumers.
 reg [7:0] response_data;
 reg response_valid,response_end,response_error;
 always @(posedge clk)begin
  if(rst)begin response_data<=0;response_valid<=0;response_end<=0;response_error<=0;end
  else begin response_data<=bmp_data;response_valid<=bmp_valid;
   response_end<=bmp_end;response_error<=bmp_error;end
 end
 media_controls #(.CLK_FREQ_HZ(CLK_FREQ_HZ),.DEBOUNCE_MS(DEBOUNCE_MS),
  .LONG_PRESS_MS(LONG_PRESS_MS),.ENABLE_EXHIBIT(1),.AUTO_PERIOD_MILLISECONDS(5400)) controls(
  .clk(clk),.rst(rst),.key_next(key_next),.key_auto(key_auto),.key_pause_mute(key_pause_mute),
  .next_pulse(next_pulse),.prev_pulse(prev_pulse),.content_mode(dual),.content_mode_changed(dual_changed),
  .auto_mode(auto_mode_out),.paused(paused_out),.muted(audio_muted),.mode_changed(mode_changed),
  .mode(control_mode),.brightness(brightness),.contrast(contrast),.interval_seconds(interval_seconds),
  .interval_fraction(interval_fraction),.osd_enable(osd_enable),.transition_mode(transition_mode),
  .scale_mode(scale_mode),.volume(volume),.interval_milliseconds(interval_ms),.zoom_focus(focus),
  .param_changed(param_changed));
 // Use the bounded ordinary-BMP scanner; only its catalogue path is enabled.
 // Ten sector-aligned contiguous BMPs: UI01..06, then PN01..04.
 bmp_scale_read #(.ENABLE_HFXL(0)) scanner(
  .clk(clk),.rst(rst),.ready(scan_ready),.scan_start(scan_start),
  .scan_start_sector(SCAN_START_SECTOR),.scan_max_sector(SCAN_MAX_SECTOR),.scan_target_count(4'd10),
  .scan_done(scan_done),.scan_found_valid(scan_found_valid),.scan_found_sector(scan_found_sector),
  .scan_found_total(scan_found_total),.load_start(1'b0),.load_abort(1'b0),.load_sector(32'd0),.scale_mode(2'd0),
  .sd_init_done(sd_init_done),.state_code(scan_state),.write_req(),.write_req_ack(1'b0),
  .sd_sec_read(scan_req),.sd_sec_read_addr(scan_addr),.sd_sec_read_data(response_data),
  .sd_sec_read_data_valid(response_valid&&!catalog_ready),.sd_sec_read_end(response_end&&!catalog_ready),
  .sd_sec_read_error(response_error&&!catalog_ready),.load_done(),.error_code(scan_error),
  .bmp_data_wr_en(),.bmp_data());
 legacy_exhibit_loader loader(
  .clk(clk),.rst(rst),.start(load_start),.abort(load_abort),
  .sector_left(left_sector),.sector_right(right_sector),
  .page(candidate_view[4:2]),.dual(candidate_view[5]),.zoom(candidate_view[7:6]),.focus(candidate_view[10:8]),
  .sd_init_done(sd_init_done),.ready(loader_ready),.busy(loader_busy),.done(loader_done),.error(loader_error),
  .write_req(write_req),.write_req_ack(write_req_ack),.pixel_valid(write_en),.pixel(loader_pixel),
  .sector_req(loader_req),.sector_addr(loader_addr),.sector_data(response_data),
  .sector_valid(response_valid&&catalog_ready),.sector_end(response_end&&catalog_ready),
  .sector_error(response_error&&catalog_ready));
 media_sector_arbiter arbiter(.clk(clk),.rst(rst),.sd_ready(sd_init_done),
  .bmp_req(bmp_req),.bmp_addr(bmp_addr),.bmp_data(bmp_data),.bmp_valid(bmp_valid),.bmp_end(bmp_end),.bmp_error(bmp_error),
  .audio_req(audio_sector_req),.audio_addr(audio_sector_addr),.audio_urgent(audio_sector_urgent),
  .audio_grant(audio_sector_grant),.audio_data(audio_sector_data),.audio_valid(audio_sector_valid),
  .audio_end(audio_sector_end),.audio_error(audio_sector_error),
  .sd_req(physical_req),.sd_addr(physical_addr),.sd_data(physical_data),
  .sd_valid(physical_valid),.sd_end(physical_end),.sd_error(physical_error));
 sd_card_top sd_card_top_m0(.clk(clk),.rst(rst),.SD_nCS(SD_nCS),.SD_DCLK(SD_DCLK),.SD_MOSI(SD_MOSI),.SD_MISO(SD_MISO),
  .sd_init_done(sd_init_done),.sd_init_error(sd_init_error),.sd_error_code(),
  .sd_sec_read(physical_req),.sd_sec_read_addr(physical_addr),.sd_sec_read_data(physical_data),
  .sd_sec_read_data_valid(physical_valid),.sd_sec_read_end(physical_end),.sd_sec_read_error(physical_error),
  .sd_sec_write(1'b0),.sd_sec_write_addr(32'd0),.sd_sec_write_data(8'd0),.sd_sec_write_data_req(),.sd_sec_write_end());
 always @(posedge clk)begin
  if(rst)begin
   display_valid<=0;candidate_view<=0;committed_view<=0;commit_toggle<=0;write_buf_idx<=0;
   cover_request_toggle<=0;wrfin_sync<=0;ack_sync<=0;cover_sync<=0;busy_sync<=0;fault_sync<=0;
   scan_start<=0;scan_kicked<=0;catalog_ready<=0;found_count<=0;load_start<=0;load_abort<=0;
   desired_page<=0;desired_reverse<=0;left_sector<=0;right_sector<=0;fault_code<=0;
   ms_count<=0;elapsed_ms<=0;progress_phase<=0;progress<=0;load_watchdog<=0;
   source_done<=0;write_done<=0;state<=SCAN;
   for(i=0;i<10;i=i+1)catalog[i]<=0;
  end else begin
   wrfin_sync<={wrfin_sync[1:0],write_finish_toggle};ack_sync<={ack_sync[0],display_commit_ack_toggle};
   cover_sync<={cover_sync[0],cover_ack_toggle_async};busy_sync<={busy_sync[0],transition_busy_async};
   fault_sync<={fault_sync[0],storage_fault_async};
   scan_start<=0;load_start<=0;load_abort<=0;
   if(next_pulse)begin desired_page<=desired_page==5?0:desired_page+1'b1;desired_reverse<=0;end
   else if(prev_pulse)begin desired_page<=desired_page==0?5:desired_page-1'b1;desired_reverse<=1;end
   // A complete visible dwell follows reveal; load time is explicitly excluded.
   // The fractional accumulator gives 255 progress steps without a divider.
   if(state!=IDLE || !display_valid || !auto_mode_out || paused_out ||
      next_pulse || prev_pulse || mode_changed || param_changed || config_dirty)begin
    ms_count<=0;elapsed_ms<=0;progress_phase<=0;progress<=0;
   end else if(ms_tick)begin
    ms_count<=0;
    if(auto_tick)begin
     elapsed_ms<=0;progress_phase<=0;progress<=0;
     desired_page<=desired_page==5?0:desired_page+1'b1;desired_reverse<=0;
    end else begin
     elapsed_ms<=elapsed_ms+1'b1;
     if(progress_sum>={1'b0,interval_ms})begin
      progress_phase<=progress_sum-{1'b0,interval_ms};
      if(progress!=255)progress<=progress+1'b1;
     end else progress_phase<=progress_sum[15:0];
    end
   end else ms_count<=ms_count+1'b1;
   if(fault_sync[1] || sd_init_error || response_error || loader_error!=0 ||
      (scan_kicked && scan_error>=2))begin
    fault_code<=fault_sync[1]?4'ha:sd_init_error?4'he:response_error?4'hd:4'hc;
    load_abort<=1;state<=FAILED;
   end else if(state!=FAILED)case(state)
    SCAN:begin
     if(sd_init_done && scan_ready && !scan_kicked)begin scan_start<=1;scan_kicked<=1;end
     if(scan_found_valid && found_count<10)begin catalog[found_count]<=scan_found_sector;found_count<=found_count+1'b1;end
     if(scan_done && scan_ready && !scan_found_valid)begin
      if(found_count==10)begin catalog_ready<=1;state<=IDLE;end
      else begin fault_code<=4'hb;state<=FAILED;end
     end
    end
    IDLE:if(config_dirty && loader_ready && !busy_sync[1] && !next_pulse && !prev_pulse)begin
     candidate_view<={desired_reverse,focus,scale_mode,dual,desired_page,display_valid?{1'b0,~committed_view[0]}:2'd0};
     write_buf_idx<=display_valid?{1'b0,~committed_view[0]}:2'd0;
     if(!dual)begin left_sector<=catalog[desired_page];right_sector<=catalog[desired_page];end
     else case(desired_page)
      2:begin left_sector<=catalog[7];right_sector<=catalog[6];end
      3:begin left_sector<=catalog[8];right_sector<=catalog[9];end
      4:begin left_sector<=catalog[9];right_sector<=catalog[8];end
      default:begin left_sector<=catalog[6];right_sector<=catalog[7];end
     endcase
     cover_request_toggle<=~cover_request_toggle;
     load_watchdog<=0;source_done<=0;write_done<=0;state<=COVER;
    end
    COVER:if(cover_sync[1]==cover_request_toggle)begin load_start<=1;state<=LOAD;load_watchdog<=0;end
    else if(load_watchdog>=CLK_FREQ_HZ*LOAD_TIMEOUT_SECONDS-1)begin fault_code<=4'hf;state<=FAILED;end
    else load_watchdog<=load_watchdog+1'b1;
    LOAD:begin
     if(loader_done)source_done<=1;
     if(wrfin_event)write_done<=1;
     if(source_done && write_done)begin commit_toggle<=~commit_toggle;state<=COMMIT;load_watchdog<=0;end
     else if(load_watchdog>=CLK_FREQ_HZ*LOAD_TIMEOUT_SECONDS-1)begin fault_code<=4'hf;load_abort<=1;state<=FAILED;end
     else load_watchdog<=load_watchdog+1'b1;
    end
    COMMIT:if(ack_sync[1]==commit_toggle)begin
     committed_view<=candidate_view;display_valid<=1;state<=REVEAL;load_watchdog<=0;
    end else if(load_watchdog>=CLK_FREQ_HZ*LOAD_TIMEOUT_SECONDS-1)begin fault_code<=4'hf;state<=FAILED;end
    else load_watchdog<=load_watchdog+1'b1;
    REVEAL:if(!busy_sync[1])begin state<=IDLE;load_watchdog<=0;end
    else if(load_watchdog>=CLK_FREQ_HZ*LOAD_TIMEOUT_SECONDS-1)begin fault_code<=4'hf;state<=FAILED;end
    else load_watchdog<=load_watchdog+1'b1;
    default:begin fault_code<=4'hf;state<=FAILED;end
   endcase
  end
 end
endmodule
