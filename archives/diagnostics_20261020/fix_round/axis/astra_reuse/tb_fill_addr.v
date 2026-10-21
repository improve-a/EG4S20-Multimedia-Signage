`timescale 1ns/1ps
module tb;
 reg clk=0,rst=1; always #20 clk=~clk;
 integer tick=0; reg [1023:0] seen; integer i, writes, dup, after_full;
 wire locked,pause,fifo_rst,wgo,rgo; wire [9:0] wa,ra;
 mapped_receiver_control dut(clk,rst,tick==12,tick>=12,tick==10,1'b0,1'b0,locked,pause,fifo_rst,wgo,rgo,wa,ra);
 initial begin seen=0; writes=0; dup=0; after_full=0; end
 always @(posedge clk) if(!rst) begin
  tick<=tick+1;
  if(fifo_rst) begin seen=0; writes=0; dup=0; after_full=0; end
  else begin
   if(wgo) begin
    if(seen[wa]) dup<=dup+1; else seen[wa]<=1'b1;
    writes<=writes+1;
   end
   if(writes>=1024 && !wgo) after_full<=after_full+1;
  end
  if(tick==3000) begin
   $display("FILL writes=%0d dup=%0d after_full=%0d wa=%0d locked=%b pause=%b fiforst=%b",writes,dup,after_full,wa,locked,pause,fifo_rst);
   $finish;
  end
 end
 initial begin repeat(10)@(negedge clk); rst=0; end
endmodule
