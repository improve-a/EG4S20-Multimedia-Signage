`timescale 1ns/1ps
module tb;
 reg clk=0,rst=1; always #20 clk=~clk;
 integer tick=0,h=0,y=0,rel; reg sof=0,sol=0,rd=0;
 wire valid,user,locked,pause,fifo_rst,wgo,rgo; wire [9:0] wa,ra;
 always @* rel=tick-35390;
 assign valid=(tick>=35390)&&((((rel%420000)+420000)%420000)/800<480)&&((((rel%420000)+420000)%420000)%800<640);
 assign user=(tick>=35390)&&((rel%420000)==0);
 mapped_receiver_control dut(clk,rst,user,valid,sof,sol,rd,locked,pause,fifo_rst,wgo,rgo,wa,ra);
 integer n=0;
 always @(posedge clk) if(!rst) begin
  tick<=tick+1;
  sof<=h==150&&y==45; sol<=h==160&&y>=45; rd<=h>=160&&y>=45;
  if(h==15)y<=y==524?0:y+1; if(!pause)h<=h==799?0:h+1;
  if(wgo && n<30) begin $display("WR t=%0d wa=%0d ra=%0d valid=%b wgo=%b rgo=%b locked=%b pause=%b",tick,wa,ra,valid,wgo,rgo,locked,pause); n<=n+1; end
  if(tick==40000) $finish;
 end
 initial begin repeat(10)@(negedge clk); rst=0; end
endmodule
