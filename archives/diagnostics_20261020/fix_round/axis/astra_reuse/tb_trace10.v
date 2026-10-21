`timescale 1ns/1ps
module tb;
 reg clk=0,rst=1; always #20 clk=~clk;
 integer tick=0,h=0,y=0,rel; reg sof=0,sol=0,rd=0;
 wire valid,user,locked,pause,fifo_rst,wgo,rgo; wire [9:0] wa,ra;
 always @* rel=tick-10;
 assign valid=(!rst)&&(tick>=10)&&((((rel%420000)+420000)%420000)/800<480)&&((((rel%420000)+420000)%420000)%800<640);
 assign user=(!rst)&&(tick>=10)&&((rel%420000)==0);
 mapped_receiver_control dut(clk,rst,user,valid,sof,sol,rd,locked,pause,fifo_rst,wgo,rgo,wa,ra);
 always @(posedge clk) if(!rst) begin
  tick<=tick+1;
  sof<=h==150&&y==45; sol<=h==160&&y>=45; rd<=h>=160&&y>=45;
  if(h==15)y<=y==524?0:y+1; if(!pause)h<=h==799?0:h+1;
  if((tick>420000&&tick<420060) || (tick>840000&&tick<840060))
    $display("t=%0d h=%0d y=%0d valid=%b user=%b sof=%b sol=%b locked=%b pause=%b fiforst=%b wgo=%b rgo=%b wa=%0d ra=%0d",tick,h,y,valid,user,sof,sol,locked,pause,fifo_rst,wgo,rgo,wa,ra);
  if(tick==840060) $finish;
 end
 initial begin repeat(10)@(negedge clk); rst=0; end
endmodule
