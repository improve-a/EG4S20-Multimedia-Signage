`timescale 1ns/1ps
// Controller-only proof. Real media_controls/arbiter; scanner, loader and SD are
// explicit protocol stubs. Does not establish actual pixels/SD/SDRAM behavior.
module legacy_exhibit_media_tb #(parameter MODE=0);
 reg clk=0;always #5 clk=~clk;reg rst=1,cover_ack=0,transition_busy=0,ack=0,wrfin=0,fault=0;
 wire valid,cover_toggle,commit;wire[11:0]candidate;wire[1:0]writebuf;wire[3:0]state;
 legacy_exhibit_media #(.CLK_FREQ_HZ(100000),.DEBOUNCE_MS(1),.LONG_PRESS_MS(20),.LOAD_TIMEOUT_SECONDS(1))dut(.clk(clk),.rst(rst),.key_next(1'b1),.key_auto(1'b1),.key_pause_mute(1'b1),.display_valid(valid),.state_code(state),.cover_request_toggle(cover_toggle),.cover_ack_toggle_async(cover_ack),.transition_busy_async(transition_busy),.candidate_view(candidate),.commit_toggle(commit),.display_commit_ack_toggle(ack),.write_finish_toggle(wrfin),.storage_fault_async(fault),.write_buf_idx(writebuf),.write_req_ack(1'b1),.audio_sector_req(1'b0),.audio_sector_addr(32'd0),.audio_sector_urgent(1'b0),.SD_MISO(1'b1));
 integer load_starts=0,commits=0,checks=0;reg oldcommit=0,seen_source=0,seen_write=0,tracking=0;reg[11:0]held;
 always@(posedge clk)begin
  if(rst)begin oldcommit=0;load_starts=0;commits=0;tracking=0;end
  else begin
   if(dut.load_start)begin
    if(cover_ack!==cover_toggle)$fatal(1,"load before fullcover ACK");
    if(valid&&writebuf==dut.committed_view[1:0])$fatal(1,"writefront ownership");
    load_starts=load_starts+1;held=candidate;tracking=1;seen_source=0;seen_write=0;
   end
   if(tracking)begin
    if(candidate!==held)$fatal(1,"candidate metadata changed duringload/commit");
    if(dut.loader_done)seen_source=1;
    if(dut.wrfin_event)seen_write=1;
   end
   if(commit!=oldcommit)begin
    if(!seen_source||!seen_write)$fatal(1,"commit before source AND realwriterfinish");
    commits=commits+1;
   end
   oldcommit=commit;checks=checks+1;
  end
 end
 task step;begin @(posedge clk);#2;@(negedge clk);end endtask
 task nextpage;begin force dut.next_pulse=1'b1;step;release dut.next_pulse;step;end endtask
 task prevpage;begin force dut.prev_pulse=1'b1;step;release dut.prev_pulse;step;end endtask
 initial begin
  repeat(5)step;rst=0;
  if(MODE==1)begin wait(state==4'hb);if(load_starts||commit||valid)$fatal(1,"partial catalogue accepted");$display("TEST_PASS legacy controller rejects9of10catalogue beforeload");$finish;end
  wait(dut.state==2);repeat(20)step;if(load_starts||valid)$fatal(1,"coverwait bypass");
  if(MODE==4)begin wait(state==4'hf);if(load_starts||commit||valid)$fatal(1,"missingcoverACK escaped");$display("TEST_PASS legacycontroller missingcoverACK boundedtimeout beforeload");$finish;end
  if(MODE==11)prevpage;
  cover_ack=cover_toggle;transition_busy=1;wait(load_starts==1);step;
  if(candidate[4:2]!=0||candidate[1:0]!=0||candidate[7:6]!=0||dut.left_sector!=100)$fatal(1,"firstcandidate metadata/default1x/catalogue gotview%h left%0d right%0d",candidate,dut.left_sector,dut.right_sector);
  if(MODE==2)begin dut.loader.inject_error=1;wait(state==4'hc);repeat(5)step;if(commit||valid)$fatal(1,"loaderfault committed");$display("TEST_PASS legacy controller loadererror failsclosed");$finish;end
  if(MODE==3)begin fault=1;wait(state==4'ha);repeat(5)step;if(commit||valid)$fatal(1,"storagefault committed");$display("TEST_PASS legacy controller storagefault aborts withoutcommit");$finish;end
  // Two new navigation events during load become one latest desired page;
  // already captured candidate and buffer remain unchanged until real ACK.
  if(MODE==7)begin wait(dut.source_done);wait(state==4'hf);if(commit||valid)$fatal(1,"missingwriterfinish committed");$display("TEST_PASS legacycontroller missingwriterfinish boundedLOADtimeout");$finish;end
  nextpage;if(MODE!=11)nextpage;
  if(MODE==10)begin wait(dut.loader_done);force dut.wrfin_event=1'b1;step;release dut.wrfin_event;end
  else begin wrfin=~wrfin;repeat(10)step;if(commit)$fatal(1,"writerfinish alone committed");end
  if(MODE==9)begin wait(dut.source_done&&dut.write_done);force dut.fault_sync[1]=1'b1;step;release dut.fault_sync[1];if(commit||valid||state!=4'ha)$fatal(1,"error didnotwin eligiblecommitcycle");$display("TEST_PASS legacycontroller synchronizederror priorityovereligiblecommit");$finish;end
  wait(commit==1);if(valid)$fatal(1,"displayvalid before realcommitACK");
  if(MODE==8)begin wait(state==4'hf);if(valid||load_starts!=1)$fatal(1,"missingcommitACK escaped");$display("TEST_PASS legacycontroller missingdisplayACK boundedCOMMITtimeout candidateheld");$finish;end
  if(MODE==11)nextpage;
  repeat(20)step;if(load_starts!=1)$fatal(1,"overlappingload beforecommit");
  ack=commit;wait(valid);repeat(20)step;if(load_starts!=1)$fatal(1,"newload duringreveal");
  if(MODE==5)begin wait(state==4'hf);if(load_starts!=1||commits!=1)$fatal(1,"stuckreveal issuedload/commit");$display("TEST_PASS legacycontroller stuckrevealbusy boundedtimeout nosecondload");$finish;end
  if(MODE==11)prevpage;
  tracking=0;force dut.dual=1'b1;force dut.scale_mode=2'd2;force dut.focus=3'd5;
  transition_busy=0;wait(dut.state==2);step;
  if(candidate[4:2]!=(MODE==11?0:2)||candidate[11]!=(MODE==11)||candidate[5]!=1||candidate[7:6]!=2||candidate[10:8]!=5||candidate[1:0]!=1||dut.left_sector!=(MODE==11?12100:14100)||dut.right_sector!=(MODE==11?14100:12100))$fatal(1,"dualreversepair/config/backbuffer snapshot");
  repeat(10)step;if(load_starts!=1)$fatal(1,"secondcoverwait bypass");
  cover_ack=cover_toggle;transition_busy=1;wait(load_starts==2);wait(dut.source_done);repeat(10)step;
  if(commit!=1)$fatal(1,"sourcedone alone committed");
  wrfin=~wrfin;wait(commit==0);ack=commit;wait(dut.state==5);repeat(20)step;if(load_starts!=2)$fatal(1,"thirdload duringreveal");
  tracking=0;transition_busy=0;release dut.dual;release dut.scale_mode;release dut.focus;
  // End on an explicit storage fault: no new candidate can publish afterward.
  fault=1;wait(state==4'ha);repeat(20)step;
  if(commits!=2)$fatal(1,"expected exactlytwo actualcommit requests");
  $display("TEST_PASS legacycontroller catalogue10,coverACKgate,sourceANDwriterfinish bothorders,delayedcommitACK,metadataatomic12bits,backbufferownership,rapidnextlatestintent,dualpair2reverse,1xdefault/3x/focus5,revealbusyexclusion,faultabort checks%0d",checks);$finish;
 end
 initial begin #2000000;$fatal(1,"controller watchdog state%0d loads%0d commits%0d",dut.state,load_starts,commits);end
endmodule

module bmp_scale_read #(parameter ENABLE_HFXL=0)(input clk,rst,scan_start,input[31:0]scan_start_sector,scan_max_sector,input[3:0]scan_target_count,output ready,output reg scan_done,scan_found_valid,output reg[31:0]scan_found_sector,output reg[3:0]scan_found_total,input load_start,load_abort,input[31:0]load_sector,input[1:0]scale_mode,input sd_init_done,output[3:0]state_code,output write_req,input write_req_ack,output sd_sec_read,output[31:0]sd_sec_read_addr,input[7:0]sd_sec_read_data,input sd_sec_read_data_valid,sd_sec_read_end,sd_sec_read_error,output load_done,output[3:0]error_code,output bmp_data_wr_en,output[23:0]bmp_data);
 reg running=0;integer count=0,phase=0;assign ready=!running;assign state_code=0;assign write_req=0;assign sd_sec_read=0;assign sd_sec_read_addr=0;assign load_done=0;assign error_code=0;assign bmp_data_wr_en=0;assign bmp_data=0;
 always@(posedge clk)begin
  if(rst)begin running<=0;count<=0;phase<=0;scan_done<=0;scan_found_valid<=0;scan_found_total<=0;scan_found_sector<=0;end
  else begin scan_found_valid<=0;
   if(scan_start)begin if(scan_target_count!=10)$fatal(1,"controller must request10BMPcatalogue");running<=1;count<=0;phase<=0;scan_done<=0;end
   else if(running)begin
    if(phase==0)begin scan_found_sector<=100+count*2000;scan_found_valid<=1;scan_found_total<=count+1;count<=count+1;phase<=1;if(legacy_exhibit_media_tb.MODE==6&&count==9)begin scan_done<=1;running<=0;end end
    else if(count==(legacy_exhibit_media_tb.MODE==1?9:10))begin running<=0;scan_done<=1;end
    else phase<=0;
   end
  end
 end
endmodule
module legacy_exhibit_loader(input clk,rst,start,abort,input[31:0]sector_left,sector_right,input[2:0]page,input dual,input[1:0]zoom,input[2:0]focus,input sd_init_done,output ready,output reg busy,done,output reg[3:0]error,output write_req,input write_req_ack,output pixel_valid,output[23:0]pixel,output sector_req,output[31:0]sector_addr,input[7:0]sector_data,input sector_valid,sector_end,sector_error);
 integer ticks=0;reg inject_error=0;assign ready=!busy;assign write_req=busy&&ticks<3;assign pixel_valid=busy&&ticks>=3&&ticks<11;assign pixel={page,dual,zoom,focus,15'd0};assign sector_req=0;assign sector_addr=sector_left;
 always@(posedge clk)begin
  if(rst)begin busy<=0;done<=0;error<=0;ticks<=0;inject_error<=0;end
  else begin done<=0;
   if(abort)busy<=0;
   else if(start)begin busy<=1;ticks<=0;error<=0;end
   else if(busy)begin
    ticks<=ticks+1;if(inject_error)begin error<=3;busy<=0;end
    else if(ticks==40)begin done<=1;busy<=0;end
   end
  end
 end
endmodule
module sd_card_top(input clk,rst,output SD_nCS,SD_DCLK,SD_MOSI,input SD_MISO,output sd_init_done,sd_init_error,output[3:0]sd_error_code,input sd_sec_read,input[31:0]sd_sec_read_addr,output[7:0]sd_sec_read_data,output sd_sec_read_data_valid,sd_sec_read_end,sd_sec_read_error,input sd_sec_write,input[31:0]sd_sec_write_addr,input[7:0]sd_sec_write_data,output sd_sec_write_data_req,sd_sec_write_end);
 assign SD_nCS=1;assign SD_DCLK=0;assign SD_MOSI=1;assign sd_init_done=!rst;assign sd_init_error=0;assign sd_error_code=0;assign sd_sec_read_data=0;assign sd_sec_read_data_valid=0;assign sd_sec_read_end=0;assign sd_sec_read_error=0;assign sd_sec_write_data_req=0;assign sd_sec_write_end=0;
endmodule
