`timescale 1ns/1ps
// Pure legacy datapath pressure. Synthetic refresh request cadence; no PHY/IP claim.
module legacy_sequential_pressure_tb #(parameter REFRESH_PERIOD=601,FIXTURE_ROOT=".");
 reg mc=0,vc=0,sc=0;always#12.5 mc=~mc;always#20 vc=~vc;always#5 sc=~sc;
 reg rst=1,request=1,write_req=0,we=0;reg[11:0]candidate=0;wire[11:0]front;wire ack,raw_req,raw_ack,mem_req,mem_ack,hs,vs,de,re,app_rd,app_wr,write_ack,write_finish,fault;wire[20:0]ra,wa;wire[31:0]rd,wd;wire[3:0]dm;
 reg[31:0]memory[0:614399];reg[23:0]payload[0:307199];reg[31:0]wp=0;
 reg[9:0]valid_pipe=0;reg[319:0]data_pipe=0;
 reg refresh_pending=0,refresh_active=0;wire refresh_vld=refresh_pending||refresh_active;
 integer mc_count=0,request_count=0,refresh_count=0,refresh_left=0,request_at=0,last_request_at=0,max_refresh_wait=0,min_refresh_wait=9999;
 integer reads=0,responses=0,writes=0,consumed=0,min_fifo=511,max_fifo=0,max_wfifo=0,covered_reads=0,contended_bursts=0;
 reg valid_display=0;wire dh,dv,dd;wire[23:0]rgb;
 video_timing_data timing(.video_clk(vc),.rst(rst),.read_req(raw_req),.read_req_ack(raw_ack),.hs(hs),.vs(vs),.de(de));
 display_commit #(.BUFFER_BITS(12),.REQUIRE_INITIAL_COMMIT(1))commit_dut(.video_clk(vc),.rst(rst),.raw_read_req(raw_req),.raw_read_ack(raw_ack),.mem_read_req(mem_req),.mem_read_ack(mem_ack),.commit_toggle_async(request),.candidate_async(candidate),.fault_async(fault),.active_buf(front),.commit_ack_toggle(ack));
 frame_read_write dut(.rst(rst),.mem_clk(mc),.Sdr_init_done(1'b1),.Sdr_init_ref_vld(refresh_vld),.Sdr_busy(refresh_active),.App_rd_en(app_rd),.App_rd_addr(ra),.Sdr_rd_en(valid_pipe[9]),.Sdr_rd_dout(data_pipe[319:288]),.read_clk(vc),.read_req(mem_req),.read_req_ack(mem_ack),.read_finish(),.read_addr_0(21'd0),.read_addr_1(21'd307200),.read_addr_2(21'd0),.read_addr_3(21'd0),.read_addr_index(front[1:0]),.read_len(21'd307200),.read_en(re),.read_data(rd),.App_wr_en(app_wr),.App_wr_addr(wa),.App_wr_din(wd),.App_wr_dm(dm),.write_clk(sc),.write_req(write_req),.write_req_ack(write_ack),.write_finish(write_finish),.write_addr_0(21'd0),.write_addr_1(21'd307200),.write_addr_2(21'd0),.write_addr_3(21'd0),.write_addr_index(2'd1),.write_len(21'd307200),.write_en(we),.write_data(wp),.display_valid_video(valid_display),.fifo_fault(fault));
 video_delay delay(.video_clk(vc),.rst(rst),.read_en(re),.read_data(rd[31:8]),.hs(hs),.vs(vs),.de(de),.hs_r(dh),.vs_r(dv),.de_r(dd),.vout_data(rgb));
 always@(posedge mc)begin
  if(rst)begin valid_pipe<=0;data_pipe<=0;end else begin
   mc_count=mc_count+1;valid_pipe<={valid_pipe[8:0],app_rd};data_pipe<={data_pipe[287:0],app_rd?memory[ra]:32'd0};
   // Requests are exactly600/601 clocks apart even during an accepted burst.
   if(mc_count%REFRESH_PERIOD==0)begin
    if(request_count&&mc_count-last_request_at!=REFRESH_PERIOD)$fatal(1,"refreshrequestcadence");
    if(refresh_pending||refresh_active)$fatal(1,"priorrefreshnotservicedwithinnativeperiod");
    refresh_pending<=1;request_at=mc_count;last_request_at=mc_count;request_count=request_count+1;
    if(app_rd||app_wr)contended_bursts=contended_bursts+1;
   end
   if(refresh_active)begin
    if(app_rd||app_wr||valid_pipe!=0)$fatal(1,"acceptedmemoryopduringactive20clkrefresh");
    if(refresh_left==1)begin refresh_active<=0;refresh_left=0;end else refresh_left=refresh_left-1;
   end else if(refresh_pending&&!app_rd&&!app_wr&&valid_pipe==0)begin
    refresh_pending<=0;refresh_active<=1;refresh_left=20;refresh_count=refresh_count+1;
    if(mc_count-request_at>max_refresh_wait)max_refresh_wait=mc_count-request_at;
    if(mc_count-request_at<min_refresh_wait)min_refresh_wait=mc_count-request_at;
   end
   if(app_rd)begin
    if(ra!==front[1:0]*307200+reads%307200)$fatal(1,"orderedread address%0d got%0d front%0d",reads,ra,front[1:0]);reads=reads+1;
    if(writes>0&&writes<307200)covered_reads=covered_reads+1;
   end
   if(valid_pipe[9])responses=responses+1;
   if(app_wr)begin
    if(front[1:0]!=0||app_rd)$fatal(1,"frontwrite/readwriteoverlap");
    if(wa!==307200+(479-writes/640)*640+writes%640||wd!=={payload[writes],8'd0})$fatal(1,"writeword mismatch%0d addr%0d data%h expected%h",writes,wa,wd,payload[writes]);
    memory[wa]<=wd;writes=writes+1;
   end
   if(dut.wrusedw>max_fifo)max_fifo=dut.wrusedw;
   if(dut.rdusedw>max_wfifo)max_wfifo=dut.rdusedw;
   if(fault)$fatal(1,"actualFIFOfault atmc%0d read%0d write%0d",mc_count,reads,writes);
  end
 end
 integer x=0,y=0,pixels=0,frames=0,sourcechecks=0,syncchecks=0,newfrontframes=0;reg oldvs=0,oldde=0;reg[62:0]syncq=0;time first,last,previous_first=0;
 always@(posedge vc)begin
  if(rst)begin syncq=0;valid_display<=0;end else begin
   if(ack)valid_display<=1;
   syncq={syncq[59:0],hs,vs,de};
   if(valid_display&&re)begin
    if(dut.rd_empty)$fatal(1,"actual511FIFOunderflow");consumed=consumed+1;
    if(consumed%307200>512&&consumed%307200<306688&&dut.wrusedw<min_fifo)min_fifo=dut.wrusedw;
   end
   #1;
   if({dh,dv,dd}!==syncq[62:60])$fatal(1,"actualvideo_delay21sync");syncchecks=syncchecks+1;
   if(dv&&!oldvs)begin x=0;y=0;pixels=0;end oldvs=dv;
   if(dd&&valid_display)begin
    if(rgb!==memory[front[1:0]*307200+y*640+x][31:8])$fatal(1,"sourcepixel frame%0d x%0d y%0d got%h expected%h",frames,x,y,rgb,memory[front[1:0]*307200+y*640+x][31:8]);
    if(pixels==0)begin first=$time;if(frames>0&&first-previous_first!=16_800_000)$fatal(1,"native16_8mscadence");previous_first=first;end
    sourcechecks=sourcechecks+1;pixels=pixels+1;last=$time;if(x==639)x=0;else x=x+1;
    if(pixels==307200)begin
     frames=frames+1;if(front[1:0]==1)newfrontframes=newfrontframes+1;
     $display("PRESSURE_FRAME_PASS %0d first%0t last%0t front%0d reads%0d writes%0d refresh_requests%0d refresh_serviced%0d",frames,first,last,front[1:0],reads,writes,request_count,refresh_count);$fflush();
     if(frames==8)begin
      if(writes!=307200||newfrontframes<2||covered_reads==0||contended_bursts==0||max_wfifo==0||refresh_count==0)$fatal(1,"missingcontention/writecommitcoverage");
      $display("TEST_PASS LEGACY_PRESSURE8frames pixels%0d sync%0d exactrefresh_request_period%0d refresh20cycles requests%0d serviced%0d requestwaitMin%0d Max%0d readFIFOmin%0d max%0d writeFIFOmax%0d overlapping_reads%0d requestDuringBurst%0d writes%0d newfrontframes%0d; ordered10cyclememory+syntheticrefresh notencryptedSDRAM/HW",sourcechecks,syncchecks,REFRESH_PERIOD,request_count,refresh_count,min_refresh_wait,max_refresh_wait,min_fifo,max_fifo,max_wfifo,covered_reads,contended_bursts,writes,newfrontframes);$finish;
     end
    end
   end
   if(oldde&&!dd)y=y+1;oldde=dd;
  end
 end
 initial begin
  $readmemh({FIXTURE_ROOT,"/memory.hex"},memory);$readmemh({FIXTURE_ROOT,"/payload.hex"},payload);
  repeat(10)@(negedge vc);rst=0;wait(frames>=1);
  @(negedge sc);write_req=1;wait(write_ack);@(negedge sc);write_req=0;wait(!write_ack);repeat(16)@(negedge sc);
  for(integer n=0;n<307200;n=n+1)begin @(negedge sc);we=1;wp={payload[n],8'd0};@(negedge sc);we=0;repeat(14)@(negedge sc);end
  wait(write_finish);if(writes!=307200)$fatal(1,"writefinishbeforefullpayload");@(negedge sc);candidate=12'd5;request=0;
 end
 initial begin #200000000;$fatal(1,"pressure200mswatchdog");end
endmodule
