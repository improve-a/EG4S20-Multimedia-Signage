`timescale 1ns/1ps
module tb;
 parameter FIRST=35390;
 parameter CYCLES=456390;
 reg clk=0,rst=1; always #20 clk=~clk;
 integer tick=0,h=0,y=0,rel; reg sof=0,sol=0,rd=0;
 wire valid,user,locked,pause,fifo_rst,wgo,rgo; wire [9:0] wa,ra;
 always @* rel=tick-FIRST;
 assign valid=(!rst)&&(tick>=FIRST)&&((((rel%420000)+420000)%420000)/800<480)&&((((rel%420000)+420000)%420000)%800<640);
 assign user=(!rst)&&(tick>=FIRST)&&((rel%420000)==0);
 mapped_receiver_control dut(clk,rst,user,valid,sof,sol,rd,locked,pause,fifo_rst,wgo,rgo,wa,ra);
 integer valid_beats=0,accepted=0,reset_blocked=0,blocked=0,reads=0,drops=0,first_lock=0; reg was_locked=0;
 reg [1023:0] addr_valid; integer read_invalid=0;
 always @(posedge clk) if(!rst) begin
  tick<=tick+1;
  sof<=h==150&&y==45; sol<=h==160&&y>=45; rd<=h>=160&&y>=45;
  if(h==15)y<=y==524?0:y+1; if(!pause)h<=h==799?0:h+1;
  was_locked<=locked;
  if(locked && first_lock==0) first_lock<=tick;
  if(was_locked&&!locked)drops<=drops+1;
  if(fifo_rst) addr_valid<=0;
  if(valid)valid_beats<=valid_beats+1;
  if(valid && fifo_rst)reset_blocked<=reset_blocked+1;
  if(valid && !fifo_rst && !wgo)blocked<=blocked+1;
  if(wgo && !fifo_rst) begin accepted<=accepted+1; addr_valid[wa]<=1'b1; end
  if(rgo && !fifo_rst) begin
   reads<=reads+1;
   if(!addr_valid[ra]) read_invalid<=read_invalid+1; else addr_valid[ra]<=1'b0;
  end
  if(tick==CYCLES) begin
   $display("ONE_FRAME FIRST=%0d tick=%0d valid=%0d accepted=%0d reset_blocked=%0d blocked_after_reset=%0d reads=%0d read_invalid=%0d drops=%0d first_lock=%0d locked=%b",FIRST,tick,valid_beats,accepted,reset_blocked,blocked,reads,read_invalid,drops,first_lock,locked);
   $finish;
  end
 end
 initial begin repeat(10)@(negedge clk); rst=0; end
endmodule
