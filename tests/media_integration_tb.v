`timescale 1ns/1ps
module media_integration_tb #(parameter WRITE_BURST=256);
 reg clk=0,video_clk=0,mem_clk=0;
 always #5 clk=~clk;always #20 video_clk=~video_clk;always #12.5 mem_clk=~mem_clk;
 reg rst=1;wire display_valid;wire[3:0]state_code;wire muted,paused,auto_mode;
 wire[2:0]control_mode,contrast;wire signed[8:0]brightness;wire[7:0]interval_seconds,progress;
 wire osd;wire[1:0]transition,scale_mode;wire[3:0]volume;
 wire audio_req,audio_grant,audio_valid_byte,audio_end,audio_sd_error,audio_urgent,sd_ready;
 wire[31:0]audio_addr;wire[7:0]audio_data;
 wire write_req,write_ack,write_en;wire[31:0]write_data;wire[1:0]write_buf,disp_buf;
 wire commit_toggle,commit_ack;reg finish_toggle=0;
 wire[1:0]front;wire raw_ack,mem_read_req;reg raw_req=0,mem_read_ack=0;
 reg[23:0]fifo[0:511],golden0[0:307199],golden1[0:307199],memory[0:614399];
 wire app_en,write_finish,fifo_clear,writer_busy;wire[20:0]app_addr;
 integer produced=0,consumed=0,max_fifo=0,mcycle=0,source_total=0,stored_total=0;
 integer frame_finishes=0,writer_frame=-1,expected_addr,vcycle=0,read_delay=0;
 integer commit_count=0,cycles=0,audio_ticks=0,audio_frames=0,audio_cycles=0,previous_tick=0;
 integer second_begin_frames=-1,second_finish_frames=-1,second_begin_cycle=-1;
 reg old_commit_ack=0,next_sent=0,rd_busy=0,scan_complete_seen=0;
 wire refresh=(mcycle%3100)<4;wire[9:0]usedw=produced-consumed;
 wire pcm_valid;wire[23:0]pcm_left,pcm_right;wire[3:0]audio_status;
 wire[15:0]peak;wire underflow,overflow,eof,audio_error;wire[11:0]audio_level;
 integer wanted_left,wanted_right;
 sd_card_bmp #(.CLK_FREQ_HZ(100000000),.ENABLE_SCALING(1),.ENABLE_AUDIO(1),
 .SCAN_START_SECTOR(0),.SCAN_MAX_SECTOR(846),.SCAN_TARGET_COUNT(2)) dut(
 .clk(clk),.rst(rst),.key_next(1'b1),.key_auto(1'b1),.key_pause_mute(1'b1),
 .bmp_width(16'd640),.bmp_height(16'd480),.display_valid(display_valid),.state_code(state_code),
 .audio_muted(muted),.auto_mode_out(auto_mode),.paused_out(paused),.control_mode(control_mode),
 .contrast(contrast),.brightness(brightness),.interval_seconds(interval_seconds),.osd_enable(osd),
 .transition_mode(transition),.scale_mode(scale_mode),.volume(volume),.progress(progress),
 .audio_sector_req(audio_req),.audio_sector_addr(audio_addr),.audio_sector_urgent(audio_urgent),
 .audio_sector_grant(audio_grant),.audio_sector_data(audio_data),.audio_sector_valid(audio_valid_byte),
 .audio_sector_end(audio_end),.audio_sector_error(audio_sd_error),.sd_ready_out(sd_ready),
 .write_finish_toggle(finish_toggle),.write_buf_idx(write_buf),.disp_buf_idx(disp_buf),
 .commit_toggle(commit_toggle),.display_commit_ack_toggle(commit_ack),.storage_fault_async(1'b0),
 .write_req(write_req),.write_req_ack(write_ack),.write_en(write_en),.write_data(write_data),
 .SD_nCS(),.SD_DCLK(),.SD_MOSI(),.SD_MISO(1'b1));
 audio_media #(.SYS_CLK_HZ(100000000),.AUDIO_CLK_HZ(25000000),.LOOP_PLAY(0),
 .FIFO_ADDRESS_BITS(11),.PREFILL_FRAMES(512),.SCAN_START_SECTOR(790),.SCAN_MAX_SECTOR(846)) audio(
 .sys_clk(clk),.rst(rst),.audio_clk(video_clk),.audio_rst(rst),.enable(display_valid),
 .paused(paused),.muted(muted),.restart(1'b0),.volume(volume),.sd_ready(sd_ready),
 .sector_grant(audio_grant),.sector_data(audio_data),.sector_valid(audio_valid_byte),
 .sector_end(audio_end),.sector_error(audio_sd_error),.sector_req(audio_req),.sector_addr(audio_addr),
 .sector_urgent(audio_urgent),.audio_valid(pcm_valid),.audio_left(pcm_left),.audio_right(pcm_right),
 .status(audio_status),.wave_peak(peak),.underflow(underflow),.overflow(overflow),.eof(eof),
 .error(audio_error),.fifo_level(audio_level));
 frame_fifo_write #(.BURST_SIZE(WRITE_BURST),.WRITE_V_FLIP(1)) writer(
 .rst(rst),.mem_clk(mem_clk),.Sdr_init_done(!rst),.Sdr_init_ref_vld(refresh),.Sdr_busy(1'b0),
 .App_rd_busy(rd_busy),.O_wr_busy(writer_busy),.App_wr_en(app_en),.App_wr_addr(app_addr),
 .write_req(write_req),.write_req_ack(write_ack),.write_finish(write_finish),
 .write_addr_0(21'd0),.write_addr_1(21'd307200),.write_addr_2(21'd614400),.write_addr_3(21'd921600),
 .write_addr_index(write_buf),.write_len(21'd307200),.fifo_aclr(fifo_clear),.rdusedw(usedw));
 display_commit display(.video_clk(video_clk),.rst(rst),.raw_read_req(raw_req),
 .raw_read_ack(raw_ack),.mem_read_req(mem_read_req),.mem_read_ack(mem_read_ack),
 .commit_toggle_async(commit_toggle),.candidate_async(disp_buf),.fault_async(1'b0),
 .active_buf(front),.commit_ack_toggle(commit_ack));
 initial begin
  $readmemh("tests/scale_golden_1.hex",golden0);$readmemh("tests/scale_golden_0.hex",golden1);
  $display("PROGRESS initialized independent golden canvases");$fflush();
  repeat(10)@(negedge clk);rst=0;
  wait(display_valid);
  $display("PROGRESS first display valid scan_done=%b found=%0d",dut.scan_done,dut.img_found_count);$fflush();
  wait(audio_frames>=10);
  @(negedge clk);
  if(!dut.scan_done||dut.img_found_count!=2||dut.load_busy||control_mode!=0)
   $fatal(1,"manual-next preconditions scan=%b found=%0d busy=%b mode=%0d",dut.scan_done,dut.img_found_count,dut.load_busy,control_mode);
  next_sent=1;force dut.key_next_press=1;
  $display("PROGRESS manual-next injected PCM=%0d cycle=%0d scan_done=%b",audio_frames,cycles,dut.scan_done);$fflush();
  @(negedge clk);release dut.key_next_press;
 end
 // Actual commit state machine at 25MHz with 60Hz frame read requests. Only
 // downstream reader ack is modelled; no encrypted read FIFO or HDMI is used.
 always @(negedge video_clk)if(!rst)begin
  vcycle=vcycle+1;
  if(vcycle%416667==1)raw_req=1;
  else if(raw_ack)raw_req=0;
  if(mem_read_req&&!mem_read_ack)begin
   read_delay=read_delay+1;if(read_delay==12)mem_read_ack=1;
  end else if(!mem_read_req)begin mem_read_ack=0;read_delay=0;end
 end
 always @(posedge clk)begin
  cycles=cycles+1;
  if(!rst && (cycles==100000||cycles==1000000||cycles%2000000==0))begin
   $display("PROGRESS cycle=%0d BMPstate=%0d DMA=%0d stored=%0d source=%0d PCM=%0d audio_status=%0d",cycles,dut.state_code_i,frame_finishes,stored_total,source_total,audio_frames,audio_status);$fflush();
  end
  if(!rst)begin
   if(dut.scan_done&&dut.img_found_count==2)scan_complete_seen=1;
   if(scan_complete_seen&&!dut.scan_done)$fatal(1,"image load cleared scan_done contract");
   if(dut.fault_code||dut.bmp_error_code||audio_error||underflow||overflow)
    $fatal(1,"fault bmp=%0d wrapper=%0d audio=%0d UF=%b OF=%b",dut.bmp_error_code,dut.fault_code,audio_status,underflow,overflow);
   if(write_en&&fifo_clear)$fatal(1,"writer clear lost source pixel");
   if(write_req&&display_valid&&write_buf==front)$fatal(1,"write request targets active front");
   if(write_req&&frame_finishes==1&&second_begin_cycle<0)begin
    second_begin_cycle=cycles;second_begin_frames=audio_frames;
    if(!next_sent||audio_frames<10)$fatal(1,"second load before PCM started");
   end
   if(commit_ack!=old_commit_ack)begin
    old_commit_ack=commit_ack;commit_count=commit_count+1;
    if(frame_finishes!=commit_count||stored_total!=commit_count*307200)
     $fatal(1,"commit before complete DMA frame");
    if(front!=(commit_count-1))$fatal(1,"wrong committed front buffer");
    $display("PROGRESS commit=%0d buffer=%0d stored=%0d PCM=%0d cycle=%0d",commit_count,front,stored_total,audio_frames,cycles);$fflush();
   end
  end
  if(rst||fifo_clear)produced=0;
  else if(write_en)begin
   if(produced-consumed>=512)$fatal(1,"512-word write FIFO overflow");
   if(display_valid&&write_buf==front)$fatal(1,"source writes front");
   fifo[produced%512]=write_data[31:8];produced=produced+1;source_total=source_total+1;
   if(produced-consumed>max_fifo)max_fifo=produced-consumed;
  end
  if(cycles>30000000)$fatal(1,"watchdog images=%0d commits=%0d audioframes=%0d status=%0d",frame_finishes,commit_count,audio_frames,audio_status);
 end
 always @(posedge mem_clk)begin
  if(rst||fifo_clear)begin consumed=0;mcycle=0;rd_busy=0;writer_frame=frame_finishes;end
  else begin
   mcycle=mcycle+1;
   if(!display_valid||mcycle%1600>=1000)rd_busy=0;else if(!writer_busy)rd_busy=1;
   if(app_en)begin
    if(consumed>=produced)$fatal(1,"write FIFO underflow");
    if(writer_frame>1)$fatal(1,"unexpected third frame");
    if(fifo[consumed%512]!==(writer_frame==0?golden0[consumed]:golden1[consumed]))
     $fatal(1,"frame %0d pixel %0d mismatch",writer_frame,consumed);
    expected_addr=writer_frame*307200+(479-consumed/640)*640+consumed%640;
    if(app_addr!==expected_addr)$fatal(1,"V_FLIP address mismatch frame=%0d pixel=%0d got=%0d expected=%0d",writer_frame,consumed,app_addr,expected_addr);
    if(display_valid&&app_addr/307200==front)$fatal(1,"DMA writes active front");
    memory[app_addr]=fifo[consumed%512];consumed=consumed+1;stored_total=stored_total+1;
   end
   if(write_finish)begin
    if(produced!=307200||consumed!=307200||usedw!=0)$fatal(1,"incomplete DMA finish");
    frame_finishes=frame_finishes+1;finish_toggle=~finish_toggle;
    if(frame_finishes==2)second_finish_frames=audio_frames;
    $display("PROGRESS DMA=%0d PCM=%0d maxFIFO=%0d cycle=%0d",frame_finishes,audio_frames,max_fifo,cycles);$fflush();
   end
  end
 end
 always @(negedge video_clk)if(!rst)begin
  audio_cycles=audio_cycles+1;
  if(pcm_valid)begin
   if(previous_tick!=0&&audio_cycles-previous_tick!=520&&audio_cycles-previous_tick!=521)
    $fatal(1,"48k cadence %0d",audio_cycles-previous_tick);
   previous_tick=audio_cycles;audio_ticks=audio_ticks+1;
   if(pcm_left!=0||pcm_right!=0)begin
    wanted_left=(-25000+(audio_frames%997)*41)*256;
    wanted_right=(22000-(audio_frames%991)*43)*256;
    if($signed(pcm_left)!==wanted_left||$signed(pcm_right)!==wanted_right)
     $fatal(1,"PCM frame %0d mismatch got %0d,%0d expected %0d,%0d",audio_frames,$signed(pcm_left),$signed(pcm_right),wanted_left,wanted_right);
    audio_frames=audio_frames+1;
   end
  end
  if(commit_count==2&&display_valid&&!dut.load_busy)begin
   if(audio_frames<=second_finish_frames||audio_frames>=6000||eof||source_total!=614400||stored_total!=614400||frame_finishes!=2||front!=1)
    $fatal(1,"incomplete output frames=%0d pixels=%0d/%0d commits=%0d",audio_frames,source_total,stored_total,commit_count);
   if(second_finish_frames-second_begin_frames<2400||second_finish_frames>=6000)
    $fatal(1,"PCM did not span whole second load begin=%0d finish=%0d",second_begin_frames,second_finish_frames);
   if(dut.sd_card_top_m0.wav_during_second<10||dut.sd_card_top_m0.bmp_during_second<400)
    $fatal(1,"insufficient concurrent sector traffic");
   // Final SRAM model is addressed top-down. Recheck both committed frame
   // images from actual memory addresses, independent of write arrival order.
   for(expected_addr=0;expected_addr<307200;expected_addr=expected_addr+1)begin
    if(memory[expected_addr]!==golden0[(479-expected_addr/640)*640+expected_addr%640]||
       memory[307200+expected_addr]!==golden1[(479-expected_addr/640)*640+expected_addr%640])
     $fatal(1,"final framebuffer mismatch address=%0d",expected_addr);
   end
   $display("TEST_PASS MEDIA_INTEGRATION frames=2 pixels=614400 PCM_prefix=%0d WAV_material_frames=6000 commits=2 maxFIFO=%0d concurrentPCM=%0d audioSectorsDuringLoad=%0d bmpSectorsDuringLoad=%0d sys100M_video25M_mem40M",audio_frames,max_fifo,second_finish_frames-second_begin_frames,dut.sd_card_top_m0.wav_during_second,dut.sd_card_top_m0.bmp_during_second);$finish;
  end
 end
endmodule

// Behavioral SD sector transport only. Real wrapper, BMP/WAV parsers and
// transaction arbiter decide which owner receives each byte. Physical SPI and
// SD initialization are deliberately outside this system-boundary simulation.
module sd_card_top(
 input clk,rst,output SD_nCS,SD_DCLK,SD_MOSI,input SD_MISO,
 output reg sd_init_done,output sd_init_error,output[3:0]sd_error_code,
 input sd_sec_read,input[31:0]sd_sec_read_addr,
 output reg[7:0]sd_sec_read_data,output reg sd_sec_read_data_valid,sd_sec_read_end,
 output sd_sec_read_error,input sd_sec_write,input[31:0]sd_sec_write_addr,
 input[7:0]sd_sec_write_data,output sd_sec_write_data_req,sd_sec_write_end
);
 reg[7:0]card[0:433663];integer busy=0,offset=0,gap=0,init_count=0,requests=0;
 integer wav_during_second=0,bmp_during_second=0;reg[31:0]lba;
 assign SD_nCS=1;assign SD_DCLK=0;assign SD_MOSI=1;
 assign sd_init_error=0;assign sd_error_code=0;assign sd_sec_read_error=0;
 assign sd_sec_write_data_req=0;assign sd_sec_write_end=0;
 initial $readmemh("tests/media_integration_card.hex",card);
 always @(negedge clk)begin
  sd_sec_read_data_valid=0;sd_sec_read_end=0;
  if(rst)begin sd_init_done=0;init_count=0;busy=0;offset=0;gap=0;requests=0;end
  else begin
   if(init_count<20)init_count=init_count+1;else sd_init_done=1;
   if(sd_sec_write)$fatal(1,"unexpected SD write");
   if(busy==0&&sd_sec_read&&sd_init_done)begin
    if(sd_sec_read_addr>846)$fatal(1,"SD request out of card bounds");
    lba=sd_sec_read_addr;offset=0;gap=10+(requests%17);busy=1;requests=requests+1;
    if(media_integration_tb.second_begin_cycle>=0&&media_integration_tb.frame_finishes<2)begin
     if(lba>=800)wav_during_second=wav_during_second+1;else bmp_during_second=bmp_during_second+1;
    end
   end else if(busy==1)begin
    if(sd_sec_read_addr!=lba||!sd_sec_read)$fatal(1,"physical transaction request/address changed");
    if(gap>0)gap=gap-1;
    else if(offset<512)begin
     sd_sec_read_data=card[lba*512+offset];sd_sec_read_data_valid=1;offset=offset+1;
     gap=2+(offset%11==0?4:0);
    end else begin sd_sec_read_end=1;busy=2;gap=4;end
   end else if(busy==2)begin if(!sd_sec_read)busy=0;end
  end
 end
endmodule
