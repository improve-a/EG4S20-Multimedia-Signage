`timescale 1ns/1ps
// Additional fast stress test; full 640x480 three-image regression remains mandatory.
module video_memory40_tb;
// Cover the public reference controller's ~20-cycle refresh-valid interval.
// The 400-cycle refresh trigger and producer/consumer rates are unchanged.
localparam integer REFRESH_STALL_CYCLES=20;
reg mclk=0,wclk=0,vclk=0;always #12.5 mclk=~mclk;always #5 wclk=~wclk;always #20 vclk=~vclk;
reg rst=1,refresh=0,wreq=0,rreq=0,we=0,re=0;reg[31:0]wdin=0;
wire wak,rak,wf,rf,wcmd,rcmd,fault;wire[20:0]wa,ra;wire[31:0]wdata,rdata;wire[3:0]dm;
reg[31:0]mem[0:8191];reg[31:0]pipe[0:9];reg[9:0]rv=0;
integer wc=0,rc=0,checked=0,refcnt=0,i,j;
integer refresh_high_count=0,refresh_starts=0,refresh_ends=0,refresh_min=1000000;
reg prev_refresh=0,prev_w=0,prev_r=0,finish_seen=0;
frame_read_write #(.FRAME_WIDTH(64),.FRAME_HEIGHT(64)) dut(
.rst(rst),.mem_clk(mclk),.Sdr_init_done(1'b1),.Sdr_init_ref_vld(refresh),.Sdr_busy(refresh),.App_rd_en(rcmd),.App_rd_addr(ra),.Sdr_rd_en(rv[9]),.Sdr_rd_dout(pipe[9]),
.read_clk(vclk),.read_req(rreq),.read_req_ack(rak),.read_finish(rf),.read_addr_0(21'd0),.read_addr_1(21'd4096),.read_addr_2(21'd0),.read_addr_3(21'd0),.read_addr_index(2'd1),.read_len(21'd4096),.read_en(re),.read_data(rdata),
.App_wr_en(wcmd),.App_wr_addr(wa),.App_wr_din(wdata),.App_wr_dm(dm),.write_clk(wclk),.write_req(wreq),.write_req_ack(wak),.write_finish(wf),.write_addr_0(21'd0),.write_addr_1(21'd4096),.write_addr_2(21'd0),.write_addr_3(21'd0),.write_addr_index(2'd0),.write_len(21'd4096),.write_en(we),.write_data(wdin),.display_valid_video(1'b1),.fifo_fault(fault));
always @(posedge mclk)begin
 if(rst)begin rv<=0;refresh<=0;refcnt<=0;wc=0;rc=0;finish_seen<=0;prev_w<=0;prev_r<=0;prev_refresh<=0;refresh_high_count=0;refresh_starts=0;refresh_ends=0;refresh_min=1000000;end
 else begin
  if(wf)finish_seen<=1;
  refcnt<=refcnt+1;
  if(!dut.App_rd_busy&&!dut.App_wr_busy&&refcnt>400)begin refresh<=1;refcnt<=0;end
  else if(refresh&&refcnt>=REFRESH_STALL_CYCLES-1)refresh<=0;
  // Sample the interface before NBA updates, exactly as the memory IP does:
  // both the first and final refresh-high sampling edges forbid a new beat.
  if(refresh&&!prev_refresh)refresh_starts=refresh_starts+1;
  if(refresh)refresh_high_count=refresh_high_count+1;
  if(!refresh&&prev_refresh)begin
   if(refresh_high_count<REFRESH_STALL_CYCLES)$fatal(1,"refresh stall too short: %0d sampled cycles",refresh_high_count);
   if(refresh_high_count<refresh_min)refresh_min=refresh_high_count;
   refresh_ends=refresh_ends+1;refresh_high_count=0;
  end
  prev_refresh<=refresh;
  if(wcmd&&rcmd)$fatal(1,"40MHz SDRAM overlap");
  if(refresh&&((wcmd&&!prev_w)||(rcmd&&!prev_r)))$fatal(1,"40MHz first beat refresh collision at sampled high cycle %0d",refresh_high_count);
  prev_w<=wcmd;prev_r<=rcmd;
  if(wcmd)begin mem[wa]<=wdata;wc=wc+1;end
  rv<={rv[8:0],rcmd};if(rcmd)begin pipe[0]<=mem[ra];rc=rc+1;end
  for(j=1;j<10;j=j+1)pipe[j]<=pipe[j-1];
 end
end
always @(posedge vclk)if(re)begin
 #1;if(rdata!==(32'h55000000|checked))$fatal(1,"40MHz read mismatch pixel=%0d actual=%h",checked,rdata);checked=checked+1;
end
initial begin
 for(i=0;i<4096;i=i+1)mem[4096+i]=32'h55000000|i;
 repeat(10)@(negedge wclk);rst=0;repeat(10)@(negedge wclk);
 wreq=1;rreq=1;wait(wak&&rak);@(negedge wclk);wreq=0;@(negedge vclk);rreq=0;
 repeat(100)@(negedge vclk);
 fork
 begin
  for(i=0;i<4096;i=i+1)begin wdin=32'haa000000|i;we=1;@(negedge wclk);we=0;repeat(9)@(negedge wclk);end
 end
 begin
  re=1;repeat(4096)@(negedge vclk);re=0;
 end
 join
 wait(finish_seen);repeat(20)@(negedge mclk);
 if(wc!=4096||rc!=4096||checked!=4096||fault)$fatal(1,"40MHz result wc=%0d rc=%0d checked=%0d fault=%b",wc,rc,checked,fault);
 for(i=0;i<4096;i=i+1)if(mem[i]!==(32'haa000000|((63-i/64)*64+i%64)))$fatal(1,"40MHz vertical mapping %0d",i);
 if(refresh_starts==0||refresh_ends==0||refresh_min<20)$fatal(1,"refresh start/end phase coverage missing");
 $display("PASS refresh boundaries starts=%0d completed=%0d minimum_high_cycles=%0d",refresh_starts,refresh_ends,refresh_min);
 $display("TEST_PASS video_memory40 real FIFO/control 4096 concurrent reads + 4096 writes, 25MHz reader 10Mpixel/s producer");$finish;
end
initial begin #5000000;$fatal(1,"40MHz test watchdog wc=%0d rc=%0d",wc,rc);end
endmodule
