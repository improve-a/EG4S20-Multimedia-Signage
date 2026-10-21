`timescale 1ns/1ps
module html_write_contract_tb;
 reg clk=0;always #12.5 clk=~clk;
 reg src_clk=0;always #5 src_clk=~src_clk;
 reg rst=1,request=0,linear=0;
 reg [20:0] base0=0,base1=0,base2=0,base3=0;
 reg [1:0] index=0;
 wire ack,finish,en,busy,clear;
 wire [20:0] address;
 reg refresh=0,read_busy=0;
 integer count=0,round=0,cycles=0,total=0,expected;
 reg [20:0] selected;
 frame_fifo_write #(.ENABLE_LINEAR_CONFIG(1),.BURST_SIZE(256),.FRAME_WIDTH(640),.FRAME_HEIGHT(480)) dut(
 .write_linear(linear),.rst(rst),.mem_clk(clk),.Sdr_init_done(1'b1),.Sdr_init_ref_vld(refresh),
 .Sdr_busy(1'b0),.App_rd_busy(read_busy),.O_wr_busy(busy),.App_wr_en(en),.App_wr_addr(address),
 .write_req(request),.write_req_ack(ack),.write_finish(finish),
 .write_addr_0(base0),.write_addr_1(base1),.write_addr_2(base2),.write_addr_3(base3),
 .write_addr_index(index),.write_len(21'd307200),.fifo_aclr(clear),.rdusedw(10'd511));
 always @(negedge clk)begin
  cycles=cycles+1;
  // A physical burst owns the bus; refresh/read conflicts only before it starts.
  refresh=!busy&&(cycles%97<11);read_busy=!busy&&(cycles%83<9);
 end
 always @(posedge clk)if(!rst&&en)begin
  expected=selected+(linear ? count : (479-count/640)*640+count%640);
  if(address!==expected[20:0])$fatal(1,"round %0d word %0d address %h expected %h",round,count,address,expected);
  if(address[1:0]!==count[1:0])$fatal(1,"illegal four-word alignment");
  count=count+1;total=total+1;
 end
 initial begin
  repeat(5)@(negedge src_clk);rst=0;
  for(round=0;round<8;round=round+1)begin
   @(negedge src_clk);
   linear=(round>=4);index=round%4;
   base0=1024+round*512;base1=base0+4096;base2=base0+8192;base3=base0+12288;
   case(index)0:selected=base0;1:selected=base1;2:selected=base2;3:selected=base3;endcase
   count=0;
   // Metadata precedes the held request; phase varies between the two clocks.
   repeat(3+round)@(negedge src_clk);request=1;
   wait(ack);repeat(4)@(negedge src_clk);request=0;
   wait(finish);@(negedge clk);
   if(count!=307200)$fatal(1,"incomplete write %0d",count);
   repeat(7)@(negedge src_clk);
  end
  $display("TEST_PASS write metadata CDC and linear/BMP row addresses %0d words",total);$finish;
 end
 initial begin #100000000;$fatal(1,"timeout");end
endmodule
