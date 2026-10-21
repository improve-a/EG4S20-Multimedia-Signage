`timescale 1ns/1ps
module phase_case #(parameter FIRST=0, parameter CYCLES=840000, parameter NAME="c")(
 input clk,rst,
 output reg [31:0] first_lock, lock_drops, blocked_writes, writes, reads,
 output reg signed [31:0] max_occ, final_occ, output reg never_locked);
 integer tick=0,h=0,y=0,rel; reg sof=0,sol=0,rd=0,was_locked=0;
 wire valid,user,locked,pause,fifo_rst,wgo,rgo; wire [9:0] wa,ra;
 always @* rel=tick-FIRST;
 assign valid=(!rst)&&(tick>=FIRST)&&((((rel%420000)+420000)%420000)/800<480)&&((((rel%420000)+420000)%420000)%800<640);
 assign user=(!rst)&&(tick>=FIRST)&&((rel%420000)==0);
 mapped_receiver_control dut(clk,rst,user,valid,sof,sol,rd,locked,pause,fifo_rst,wgo,rgo,wa,ra);
 initial begin first_lock=0;lock_drops=0;blocked_writes=0;writes=0;reads=0;max_occ=0;final_occ=0;never_locked=1; end
 always @(posedge clk) begin
  if(rst) begin tick<=0;h<=0;y<=0;sof<=0;sol<=0;rd<=0;was_locked<=0; end
  else begin
   tick<=tick+1;
   sof<=h==150&&y==45; sol<=h==160&&y>=45; rd<=h>=160&&y>=45;
   if(h==15)y<=y==524?0:y+1; if(!pause)h<=h==799?0:h+1;
   was_locked<=locked;
   if(locked&&first_lock==0) begin first_lock<=tick;never_locked<=0; end
   if(was_locked&&!locked)lock_drops<=lock_drops+1;
   if(fifo_rst) begin final_occ<=0;max_occ<=0; end
   else begin
    if(valid&&!wgo)blocked_writes<=blocked_writes+1;
    if(wgo)writes<=writes+1; if(rgo)reads<=reads+1;
    final_occ<=final_occ+(wgo?1:0)-(rgo?1:0);
    if(final_occ+(wgo?1:0)-(rgo?1:0)>max_occ)max_occ<=final_occ+(wgo?1:0)-(rgo?1:0);
   end
  end
 end
 always @(negedge clk) if(!rst&&tick>=CYCLES) begin
  $display("%s FIRST=%0d tick=%0d first_lock=%0d locked=%b pause=%b drops=%0d blocked=%0d writes=%0d reads=%0d maxocc=%0d",NAME,FIRST,tick,first_lock,locked,pause,lock_drops,blocked_writes,writes,reads,max_occ);
  $finish;
 end
endmodule
module tb;
 reg clk=0,rst=1; always #20 clk=~clk;
 wire [31:0] l1,d1,b1,w1,r1,l2,d2,b2,w2,r2; wire signed[31:0] m1,f1,m2,f2; wire n1,n2;
 phase_case #(.FIRST(0),.NAME("C0"))   c3(clk,rst,l1,d1,b1,w1,r1,m1,f1,n1);
 phase_case #(.FIRST(160),.NAME("D160")) c4(clk,rst,l2,d2,b2,w2,r2,m2,f2,n2);
 initial begin repeat(10)@(negedge clk); rst=0; repeat(850000)@(negedge clk); $finish; end
endmodule
