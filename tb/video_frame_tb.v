`timescale 1ns/1ps
module video_frame_tb #(
 parameter real MEM_HALF_NS=4.0,
 parameter integer WRITE_GAP_CYCLES=2
);
reg mclk=0,wclk=0,vclk=0;always #(MEM_HALF_NS) mclk=~mclk;always #5 wclk=~wclk;always #20 vclk=~vclk;
reg rst=1,init=0,refbusy=0,wreq=0,rreq=0,we=0,dispvalid=0,de=0,vs=0;reg[31:0] wdata=0;
reg[1:0]bufidx=0,rbufidx=0;wire wack,rack,wfinish,rfinish,wcmd,rcmd,fault,ren;
wire[20:0] wa,ra;wire[31:0] wd,rd;wire[3:0]dm;
reg[31:0]mem[0:614399];reg[31:0]rpipe[0:9];reg[9:0]rvalid=0;
reg[23:0]bottom[0:307199],gold[0:307199],frontgold[0:307199];
reg frontcheck=0;
reg last_wcmd=0,last_rcmd=0,write_done_seen=0;
wire hso,vso,deo;wire[23:0]rgb;wire av,au,al;wire[23:0]ad;
integer idle_cycles=0,old_writes=0,old_reads=0;
integer writes=0,reads=0,checked=0,img,x,y,i,j,refresh_count=0;reg verify=0;
frame_read_write dut(.rst(rst),.mem_clk(mclk),.Sdr_init_done(init),.Sdr_init_ref_vld(refbusy),.Sdr_busy(refbusy),
.App_rd_en(rcmd),.App_rd_addr(ra),.Sdr_rd_en(rvalid[9]),.Sdr_rd_dout(rpipe[9]),
.read_clk(vclk),.read_req(rreq),.read_req_ack(rack),.read_finish(rfinish),.read_addr_0(21'd0),.read_addr_1(21'd307200),.read_addr_2(21'd0),.read_addr_3(21'd0),.read_addr_index(rbufidx),.read_len(21'd307200),.read_en(ren),.read_data(rd),
.App_wr_en(wcmd),.App_wr_addr(wa),.App_wr_din(wd),.App_wr_dm(dm),
.write_clk(wclk),.write_req(wreq),.write_req_ack(wack),.write_finish(wfinish),.write_addr_0(21'd0),.write_addr_1(21'd307200),.write_addr_2(21'd0),.write_addr_3(21'd0),.write_addr_index(bufidx),.write_len(21'd307200),.write_en(we),.write_data(wdata),.display_valid_video(dispvalid),.fifo_fault(fault));
video_delay delay_dut(.video_clk(vclk),.rst(rst),.read_en(ren),.read_data(rd[31:8]),.hs(1'b0),.vs(vs),.de(de),.hs_r(hso),.vs_r(vso),.de_r(deo),.vout_data(rgb));
video_rgb_to_axis_640x480 axis_dut(.I_clk(vclk),.I_rst(rst),.I_vs(vso),.I_de(deo),.I_rgb(rgb),.O_video_user(au),.O_video_valid(av),.O_video_last(al),.O_video_data(ad));
// SDRAM USER-INTERFACE model, not simulation of encrypted physical SDRAM core.
// APUG011: accepts a burst after init/ref idle, then 10-cycle read latency.
always @(posedge mclk)begin
 if(rst)begin rvalid<=0;writes=0;reads=0;refresh_count<=0;refbusy<=0;last_wcmd<=0;last_rcmd<=0;write_done_seen<=0;end
 else begin
  if(wfinish)write_done_seen<=1;
  refresh_count<=refresh_count+1;
  // Request refresh periodically only between transactions, as the documented IP does.
  if(!dut.App_rd_busy&&!dut.App_wr_busy && refresh_count>400)begin refbusy<=1;refresh_count<=0;end
  else if(refbusy && refresh_count>=10)refbusy<=0;
  if(((wcmd && !last_wcmd)||(rcmd && !last_rcmd)) && refbusy)
   $fatal(1,"new SDRAM burst starts during refresh: wr=%b rd=%b",wcmd,rcmd);
  last_wcmd<=wcmd;last_rcmd<=rcmd;
  if(wcmd && rcmd)$fatal(1,"simultaneous SDRAM read/write");
  if(wcmd)begin
   if(wa>=614400)$fatal(1,"write address outside double buffer");
   mem[wa]<=wd;writes=writes+1;
  end
  rvalid<={rvalid[8:0],rcmd};
  if(rcmd)begin rpipe[0]<=mem[ra];reads=reads+1;end
  for(j=1;j<10;j=j+1)rpipe[j]<=rpipe[j-1];
 end
end
always @(posedge mclk)begin
 if(rst||!init)begin idle_cycles=0;old_writes=writes;old_reads=reads;end
 else begin
  if(writes!=old_writes||reads!=old_reads)idle_cycles=0;else idle_cycles=idle_cycles+1;
  old_writes=writes;old_reads=reads;
  if(idle_cycles>200000)$fatal(1,"no memory progress 200000 mem clocks: wstate=%0d rstate=%0d writes=%0d reads=%0d usedw=%0d",dut.frame_fifo_write_m0.state,dut.frame_fifo_read_m0.state,writes,reads,dut.rdusedw);
 end
end
always @(posedge vclk) begin
 #1;
 if(verify&&av)begin
  if(checked>=307200||ad!==(frontcheck?frontgold[checked]:gold[checked]))$fatal(1,"video pixel mismatch img=%0d index=%0d actual=%06x expected=%06x",img,checked,ad,(frontcheck?frontgold[checked]:gold[checked]));
  if(au!==(checked==0)||al!==((checked%640)==639))$fatal(1,"video axis framing error pixel=%0d",checked);
  checked=checked+1;
 end
end
task concurrent_front_frame;
 begin
  rbufidx=1;frontcheck=1;checked=0;
  @(negedge vclk);rreq=1;wait(rack);@(negedge vclk);rreq=0;repeat(100)@(negedge vclk);
  verify=1;dispvalid=1;vs=1;repeat(2)@(negedge vclk);vs=0;repeat(2)@(negedge vclk);
  repeat(480)begin de=1;repeat(640)@(negedge vclk);de=0;repeat(160)@(negedge vclk);end
  repeat(50)@(negedge vclk);
  if(checked!=307200||fault)$fatal(1,"concurrent front/back failure pixels=%0d fault=%b",checked,fault);
  verify=0;dispvalid=0;frontcheck=0;
  $display("PASS concurrent read front2/write back3 + refresh, 307200 pixels");
 end
endtask
initial begin
 $display("CONFIG MEM_HALF_NS=%0.3f WRITE_GAP_CYCLES=%0d",MEM_HALF_NS,WRITE_GAP_CYCLES);$fflush();
 $readmemh("tb/storage_data/frame2.hex",frontgold);
 for(img=1;img<=3;img=img+1)begin
  case(img)
  1:begin $readmemh("tb/storage_data/pixels1.hex",bottom);$readmemh("tb/storage_data/frame1.hex",gold);end
  2:begin $readmemh("tb/storage_data/pixels2.hex",bottom);$readmemh("tb/storage_data/frame2.hex",gold);end
  3:begin $readmemh("tb/storage_data/pixels3.hex",bottom);$readmemh("tb/storage_data/frame3.hex",gold);end
  endcase
  $display("PROGRESS frame%0d loaded vectors time=%0t",img,$time);$fflush();
  rst=1;init=0;verify=0;de=0;dispvalid=0;bufidx=(img==2);repeat(5)@(negedge wclk);rst=0;
  // Exercise a write request held before memory initialization.
  wreq=1;repeat(10)@(negedge wclk);if(wack)$fatal(1,"write acknowledged before SDRAM init");init=1;
  wait(wack);$display("PROGRESS frame%0d write ACK time=%0t",img,$time);$fflush();@(negedge wclk);wreq=0;repeat(20)@(negedge wclk);
  fork
  begin
  for(i=0;i<307200;i=i+1) begin
   wdata={bottom[i],8'd0};we=1;@(negedge wclk);we=0;repeat(WRITE_GAP_CYCLES-1)@(negedge wclk);
   if((i%65536)==65535)begin $display("PROGRESS frame%0d sent=%0d writes=%0d time=%0t",img,i+1,writes,$time);$fflush();end
  end
  end
  begin if(img==3)concurrent_front_frame;end
  join
  $display("PROGRESS frame%0d stream done writes=%0d time=%0t",img,writes,$time);$fflush();
  wait(write_done_seen);repeat(3)@(negedge mclk);
  if(writes!=307200)$fatal(1,"frame write count %0d",writes);
  for(i=0;i<307200;i=i+1)if(mem[bufidx*307200+i]!=={gold[i],8'd0})$fatal(1,"vertical flip/address/data mismatch at %0d",i);
  $display("PROGRESS frame%0d memory verified time=%0t",img,$time);$fflush();
  rbufidx=bufidx;
  @(negedge vclk);rreq=1;wait(rack);@(negedge vclk);rreq=0;repeat(100)@(negedge vclk);
  checked=0;verify=1;dispvalid=1;vs=1;repeat(2)@(negedge vclk);vs=0;repeat(2)@(negedge vclk);
  for(y=0;y<480;y=y+1)begin
   de=1;repeat(640)@(negedge vclk);de=0;repeat(160)@(negedge vclk);
  end
  repeat(50)@(negedge vclk);
  if(checked!=307200||reads!=((img==3)?614400:307200)||fault)$fatal(1,"frame result pixels=%0d reads=%0d fifo_fault=%b",checked,reads,fault);
  $display("PASS frame%0d real async FIFO/control/address + video 307200 pixels",img);
 end
 // Real empty FIFO: one extra visible pixel must latch underflow.
 verify=0;de=1;@(negedge vclk);de=0;repeat(30)@(negedge vclk);
 if(!dut.rd_underflow||!fault)$fatal(1,"read underflow was not diagnosed");
 // Hold writer idle and overrun its FIFO; sticky overflow must be diagnosed.
 rst=1;dispvalid=0;repeat(5)@(negedge wclk);rst=0;repeat(5)@(negedge wclk);
 we=1;repeat(600)@(negedge wclk);we=0;
 if(!dut.wr_overflow||!fault)$fatal(1,"write overflow was not diagnosed");
 $display("PASS real FIFO underflow/overflow injection diagnostics");
 $display("TEST_PASS video_frame 1228800 pixel comparisons; physical SDRAM/HDMI core not modeled");$finish;
end
initial begin #200000000;$fatal(1,"video_frame timeout writes=%0d reads=%0d",writes,reads);end
endmodule
