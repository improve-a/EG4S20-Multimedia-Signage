`timescale 1ns/1ps
`define HTML_SIM
module html_layer_physical_fifo_tb #(parameter PAGE=2,MOTION_AGE=25,OLD_PAGE=1,REVERSE=0,APERTURE_WIDTH=129,APERTURE_ENABLE=1,WRITE_RESERVE=256,FIXTURE_ROOT="output/html_fidelity/page_control/layer_late25_physical511_phoenix_v1",CASE_NAME="phoenix");
reg clk=0,video_clk=0,write_clk=0;always#12.5 clk=~clk;always#20 video_clk=~video_clk;always#5 write_clk=~write_clk;
reg rst=1,refresh=0,write_req=0,read_req=0,source_en=0,video_start=0;reg[31:0]source_data=0;
wire we,raw,re,logical_ready,logical_response,full_busy,physical_busy,writing,writer_pending,read_busy,ack,video_ack,write_ack,fifo_fault,bridge_fault;
wire[20:0]physical_addr,write_addr,ignored_addr;wire[31:0]pixel,video_data,write_data;wire[3:0]dm;
wire pause_new_groups=writer_pending&&!read_busy;
reg[31:0]memory[0:2097151],gold[0:307199];reg[9:0]rv=0;reg[31:0]pipe[0:9];
integer low_x=-1,low_y=-1,low_state=-1,low_since_write=-1,last_write_end=-1,low_remaining=-1;
integer cycles=0,i,phase=0,group_base=0,groups=0,produced=0,consumed=0,source_words=0,written=0;
integer x=0,y=0,video_cycles=0,min_read=511,max_read=0,max_write=0,grants=0,write_wait=0,max_write_wait=0,drain=0,max_drain=0,min_admission=511,min_release=511;
reg previous_writing=0;
wire video_read=video_start&&x<640&&y<480;
frame_read_write #(.BURST_SIZE(256),.READ_BURST_SIZE(128),.READ_DRAIN_CYCLES(13),.ENABLE_LINEAR_CONFIG(1),.ENABLE_READ_SOURCE(1),.ENABLE_PHYSICAL_FAIRNESS(1),.WRITE_RESERVE_WORDS(WRITE_RESERVE)) f(
 .rst(rst),.mem_clk(clk),.Sdr_init_done(1'b1),.Sdr_init_ref_vld(refresh),.Sdr_busy(1'b0),
 .read_source_ready(logical_ready),.read_source_busy(full_busy),.read_source_physical_busy(physical_busy),.read_burst_busy_mem(read_busy),.write_pending_mem(writer_pending),
 .write_busy_mem(writing),.read_accept_mem(ack),.display_valid_video(video_start),.fifo_fault(fifo_fault),
 .App_rd_en(raw),.App_rd_addr(ignored_addr),.Sdr_rd_en(logical_response),.Sdr_rd_dout(pixel),
 .App_wr_en(we),.App_wr_addr(write_addr),.App_wr_din(write_data),.App_wr_dm(dm),
 .read_clk(video_clk),.read_req(read_req),.read_req_ack(video_ack),.read_finish(),.read_addr_0(21'd0),.read_addr_1(21'd0),.read_addr_2(21'd0),.read_addr_3(21'd0),.read_addr_index(2'd0),.read_len(21'd307200),.read_en(video_read),.read_data(video_data),
 .write_clk(write_clk),.write_linear(1'b1),.write_req(write_req),.write_req_ack(write_ack),.write_finish(),.write_addr_0(21'd1900000),.write_addr_1(21'd1900000),.write_addr_2(21'd1900000),.write_addr_3(21'd1900000),.write_addr_index(2'd0),.write_len(21'd8192),.write_en(source_en),.write_data(source_data));
html_layer_memory_bridge #(.ENABLE_PHYSICAL_FAIRNESS(1)) dut(.mem_clk(clk),.rst(rst),.video_read_req(read_req),.read_accept_mem(ack),.active_view({REVERSE!=0,1'b0,PAGE[2:0]}),.zoom(2'd0),.transition_mode(2'd1),.focus(3'd1),.panels_ready(1'b1),.layer_resources_enabled(1'b1),
 .write_busy_mem(writing),.mem_ready(1'b1),.refresh_active(refresh),.raw_read_en(raw),.read_en(re),.read_addr(physical_addr),.response(rv[9]),.memory_data(pipe[9]),.pixel_data(pixel),.logical_ready(logical_ready),.logical_response(logical_response),.busy(full_busy),.fault(bridge_fault),.pause_new_groups(pause_new_groups),.physical_busy(physical_busy));
function[31:0]source_word;input integer n;begin source_word=32'hd1200000^n;end endfunction
always@(posedge write_clk)if(!rst&&source_en)begin if(f.wr_full)$fatal(1,"actualWriteFIFOoverflow");source_words=source_words+1;end
always@(posedge clk)begin
 if(rst)begin rv<=0;refresh<=0;end else begin
  cycles=cycles+1;refresh<=cycles%312<20;
  for(i=9;i>0;i=i-1)pipe[i]<=pipe[i-1];rv<={rv[8:0],re};
  if(re)begin
   if(we||writing)$fatal(1,"physicalreadwriteoverlap");
   if(phase==0)begin if(physical_addr[1:0]!=0||refresh)$fatal(1,"badfirstgroup");group_base=physical_addr;groups=groups+1;end
   pipe[0]<=memory[group_base+phase];phase=(phase+1)%4;
  end else if(phase!=0)$fatal(1,"broken4group");
  if(we)begin
   if(write_addr!==1900000+written||write_data!==source_word(written))$fatal(1,"actualWriteFIFOword%0d gotaddr%0d data%h expected%h",written,write_addr,write_data,source_word(written));
   written=written+1;
  end
  if(logical_response)begin if(pixel!==gold[produced])$fatal(1,"logicalRGB%0d got%h expected%h",produced,pixel,gold[produced]);produced=produced+1;end
  if(produced-consumed>max_read)max_read=produced-consumed;
  if(source_words-written>max_write)max_write=source_words-written;
  if(source_words-written>511||produced-consumed>511)$fatal(1,"usableFIFO511limit");
  if(f.writer_pending&&!writing)write_wait=write_wait+1;
  if(writer_pending&&!read_busy&&!writing)drain=drain+1;
  if(writing&&!previous_writing)begin
   if(write_wait>max_write_wait)max_write_wait=write_wait;write_wait=0;
   if(drain>max_drain)max_drain=drain;drain=0;
   if(video_start)begin grants=grants+1;if(produced-consumed<min_admission)min_admission=produced-consumed;end
  end
  if(read_busy||(!writer_pending&&!writing))drain=0;
  if(previous_writing&&!writing)last_write_end=cycles;
  if(previous_writing&&!writing&&video_start&&produced-consumed<min_release)min_release=produced-consumed;
  if(drain>40)$fatal(1,"drainBound%0d",drain);
  previous_writing=writing;
  #1;if(fifo_fault||bridge_fault)$fatal(1,"actualFIFO_or_bridge_fault %b %b",fifo_fault,bridge_fault);
 end
end
always@(posedge video_clk)if(video_start)begin
 video_cycles=video_cycles+1;
 if(video_read)begin
  if(f.rd_empty)$fatal(1,"actualVideoFIFOunderflow y%0d x%0d",y,x);
  #1;if(video_data!==gold[consumed])$fatal(1,"actualVideoRGB%0d got%h expected%h",consumed,video_data,gold[consumed]);
  if(consumed>512&&consumed<306688&&produced-consumed<min_read)begin min_read=produced-consumed;low_x=x;low_y=y;low_state=f.frame_fifo_write_m0.state;low_since_write=cycles-last_write_end;low_remaining=307200-consumed;end
  consumed=consumed+1;
 end
 if(x==799)begin x=0;y=y+1;end else x=x+1;
 if(consumed==307200)begin
  video_start=0;#1000;
  if(produced!=307200||phase!=0||fifo_fault||bridge_fault||written==0||grants==0)$fatal(1,"finalcounts");
  $display("LOWPOINT x%0d y%0d state%0d sincewrite_memclks%0d remainingpixels%0d minRead%0d",low_x,low_y,low_state,low_since_write,low_remaining,min_read);
  $display("TEST_PASS actual_vendorFIFO_GrayCDC RAM511 mem40_video25_source100 logicalRGB307200 videoRGB307200 orderedWriteWords%0d sourceWords%0d minRead%0d maxRead%0d maxWrite%0d writerWaitMax%0d physicalDrainMax%0d admissionFIFOmin%0d releaseFIFOmin%0d videoWriterGrants%0d groups%0d forcedLateAge%0d",written,source_words,min_read,max_read,max_write,max_write_wait,max_drain,min_admission,min_release,grants,groups,MOTION_AGE);$finish;
 end
end
initial begin
 $readmemh({FIXTURE_ROOT,"/memory.hex"},memory);$readmemh({FIXTURE_ROOT,"/",CASE_NAME,"_gold.hex"},gold);
 force dut.geometry.motion.frame_age=MOTION_AGE;force dut.mapper.old_page=OLD_PAGE;force dut.mapper.old_dual=1'b0;force dut.mapper.aperture_active=(MOTION_AGE<63&&APERTURE_ENABLE);force dut.mapper.aperture_age=MOTION_AGE;force dut.mapper.aperture_width=APERTURE_WIDTH;force dut.mapper.reverse_l=(REVERSE!=0);
 repeat(8)@(negedge clk);rst=0;repeat(8)@(negedge write_clk);
 write_req=1;wait(write_ack);@(negedge write_clk);write_req=0;wait(!write_ack);repeat(8)@(negedge write_clk);
 // Only the initial backlog construction uses a declared forced busy hook.
 // During the measured frame all Gray synchronizers and flags run normally.
 force f.O_rd_busy=1'b1;
 for(integer preload=0;preload<511;preload=preload+1)begin @(negedge write_clk);source_en=1;source_data=source_word(preload);end
 @(negedge write_clk);source_en=0;release f.O_rd_busy;
 fork
  begin for(integer n=511;n<8192;n=n+1)begin repeat(255)@(negedge write_clk);source_en=1;source_data=source_word(n);@(negedge write_clk);source_en=0;end end
  begin @(negedge video_clk);read_req=1;wait(video_ack);@(negedge video_clk);read_req=0;end
  begin wait(cycles>=5000);@(negedge video_clk);video_start=1;end
 join
end
initial begin #30000000;$fatal(1,"timeout");end
endmodule
