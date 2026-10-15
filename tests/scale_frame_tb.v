`timescale 1ns/1ps
// Uses the actual inherited frame writer with a behavioural 512-word async
// FIFO. 40MHz port models 25MHz scanout occupancy plus refresh stalls. This
// scopes verification to writer address/queue contract, not encrypted SDRAM IP.
module scale_frame_tb;
 reg clk=0,mem_clk=0;always #5 clk=~clk;always #12.5 mem_clk=~mem_clk;
 reg rst=1,start=0,write_req=0,source_valid=0;reg[23:0]source_pixel=0;
 wire source_ready,pixel_valid,done,ack,finish,clear,app_en,busy;
 wire[23:0]pixel;wire[20:0]address;
 reg[23:0]fifo[0:511],golden[0:307199];
 integer produced=0,consumed=0,maximum=0,sx=0,sy=0,pace=0,mcycle=0;
 integer expected_address,cycles=0;
 reg rd_busy=0;
 wire refresh=(mcycle%3100)<4;
 wire[9:0]usedw=produced-consumed;
 function [23:0] pattern(input integer x,input integer y);
  reg[7:0]r,g,b;begin r=x*7+y*13+1;g=x*11+y*3+29;b=x*5+y*17+71;pattern={r,g,b};end
 endfunction
 bmp_scale scaler(.clk(clk),.rst(rst),.start(start),.source_width(10'd320),
 .source_height(10'd240),.scale_mode(2'd0),.source_valid(source_valid),
 .source_pixel(source_pixel),.source_ready(source_ready),.pixel_valid(pixel_valid),.pixel(pixel),.done(done));
 frame_fifo_write #(.BURST_SIZE(128),.WRITE_V_FLIP(1)) writer(
 .rst(rst),.mem_clk(mem_clk),.Sdr_init_done(!rst),.Sdr_init_ref_vld(refresh),
 .Sdr_busy(1'b0),.App_rd_busy(rd_busy),.O_wr_busy(busy),.App_wr_en(app_en),.App_wr_addr(address),
 .write_req(write_req),.write_req_ack(ack),.write_finish(finish),
 .write_addr_0(21'd0),.write_addr_1(21'd307200),.write_addr_2(21'd614400),.write_addr_3(21'd921600),
 .write_addr_index(2'd1),.write_len(21'd307200),.fifo_aclr(clear),.rdusedw(usedw));
 initial begin
  $readmemh("tests/scale_golden_0.hex",golden);
  repeat(5)@(negedge clk);rst=0;write_req=1;
  wait(ack);@(negedge clk);write_req=0;
  wait(!clear);repeat(3)@(negedge clk);start=1;@(negedge clk);start=0;
 end
 always @(negedge clk) begin
  source_valid=0;
  if(!rst && source_ready && sy<240) begin
   if(pace==0)begin
    source_valid=1;source_pixel=pattern(sx,239-sy);pace=3;
    if(sx==319)begin sx=0;sy=sy+1;end else sx=sx+1;
   end else pace=pace-1;
  end
 end
 always @(posedge clk) begin
  cycles=cycles+1;
  if(rst||clear)produced=0;
  else if(pixel_valid)begin
   if(produced-consumed>=512)$fatal(1,"write FIFO overflow used=%0d",produced-consumed);
   fifo[produced%512]=pixel;produced=produced+1;
   if(produced-consumed>maximum)maximum=produced-consumed;
  end
  if(done && produced!=307200)$fatal(1,"early scaler done %0d",produced);
  if(cycles>10000000)$fatal(1,"watchdog produced=%0d consumed=%0d",produced,consumed);
 end
 always @(posedge mem_clk) begin
  if(rst||clear)begin consumed=0;mcycle=0;rd_busy=0;end
  else begin
   mcycle=mcycle+1;
   // A read burst already in progress blocks launching a write burst. Reads
   // cannot begin while O_wr_busy reserves the port for an accepted write.
   if(mcycle%1600>=1000)rd_busy=0;
   else if(!busy)rd_busy=1;
   if(app_en)begin
    if(consumed>=produced)$fatal(1,"write FIFO underflow");
    if(fifo[consumed%512]!==golden[consumed])$fatal(1,"stored pixel mismatch %0d",consumed);
    expected_address=307200+(479-consumed/640)*640+consumed%640;
    if(address!==expected_address)$fatal(1,"V_FLIP address %0d got=%0d expected=%0d",consumed,address,expected_address);
    if(address<307200||address>=614400)$fatal(1,"out-of-frame write");
    consumed=consumed+1;
   end
   if(finish)begin
    if(produced!=307200||consumed!=307200||usedw!=0)$fatal(1,"incomplete memory frame");
    $display("TEST_PASS SCALE_FRAME pixels=%0d max_fifo=%0d capacity=512 memclk=40MHz sourceclk=100MHz",consumed,maximum);$finish;
   end
  end
 end
endmodule
