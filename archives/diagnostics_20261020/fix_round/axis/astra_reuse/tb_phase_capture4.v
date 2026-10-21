`timescale 1ns/1ps
// Bounded, function-driven receiver/FIFO re-capture test.
// DUT is the netlist-derived mapped_receiver_control.v (81 FF / 27 LUT outputs).
// Source timing SOF/SOL/read_en is the decoded actual u_hdmi_video_source timing
// (SOF col150 row45; SOL col160 rows>=45; read_en col>=160 rows>=45).
module phase_case #(parameter FIRST=35392, parameter CYCLES=420000, parameter NAME="c")(
 input clk,rst,
 output reg [31:0] user_first, first_lock, lock_drops, blocked_writes,
 output reg [31:0] accepted, writes, reads, addr_jumps, duplicate_writes,
 output reg signed [31:0] max_occ, final_occ,
 output reg [9:0] final_wa, final_ra,
 output reg never_locked, stuck_reset
);
 integer tick=0,h=0,y=0; reg sof=0,sol=0,rd=0,was_locked=0;
 reg [9:0] prev_wa=0, prev_ra=0; reg [31:0] write_streak=0;
 wire valid,user,locked,pause,fifo_rst,wgo,rgo; wire [9:0] wa,ra;
 integer rel;
 always @* rel = tick - FIRST;
 assign valid = (!rst) && (tick>=FIRST) && ((((rel%420000)+420000)%420000)/800<480) && ((((rel%420000)+420000)%420000)%800<640);
 assign user  = (!rst) && (tick>=FIRST) && ((rel%420000)==0);
 mapped_receiver_control dut(clk,rst,user,valid,sof,sol,rd,locked,pause,fifo_rst,wgo,rgo,wa,ra);
 initial begin
  user_first=0; first_lock=0; lock_drops=0; blocked_writes=0; accepted=0; writes=0; reads=0;
  addr_jumps=0; duplicate_writes=0; max_occ=0; final_occ=0; final_wa=0; final_ra=0;
  never_locked=1; stuck_reset=0;
 end
 always @(posedge clk) begin
  if (rst) begin
   tick<=0; h<=0; y<=0; sof<=0; sol<=0; rd<=0; was_locked<=0; prev_wa<=0; prev_ra<=0;
  end else begin
   tick<=tick+1;
   sof <= (h==150) && (y==45);
   sol <= (h==160) && (y>=45);
   rd  <= (h>=160) && (y>=45);
   if (h==15) y <= (y==524) ? 0 : y+1;
   if (!pause) h <= (h==799) ? 0 : h+1;
   was_locked<=locked;
   if (user && user_first==0) user_first<=tick;
   if (locked && first_lock==0) begin first_lock<=tick; never_locked<=0; end
   if (was_locked && !locked) lock_drops<=lock_drops+1;
   if (fifo_rst) begin
    // addresses should be held at reset value; count unexpected changes separately later
   end else begin
    if (valid && !wgo) blocked_writes<=blocked_writes+1;
    if (wgo) begin
     writes<=writes+1; accepted<=accepted+1;
     if ((wa != ((prev_wa+1)%1024)) && (writes>1)) addr_jumps<=addr_jumps+1;
     if (writes>0 && wa==prev_wa) duplicate_writes<=duplicate_writes+1;
     prev_wa<=wa;
    end
    if (rgo) begin reads<=reads+1; prev_ra<=ra; end
    if ((valid && wgo) || rgo) begin
     // occupancy is maintained by TB, not DUT
    end
   end
   // occupancy: reset clears; otherwise accepted write +1, read -1
   if (fifo_rst) begin final_occ<=0; max_occ<=0; end
   else begin
    final_occ <= final_occ + (wgo?1:0) - (rgo?1:0);
    if (final_occ + (wgo?1:0) - (rgo?1:0) > max_occ)
      max_occ <= final_occ + (wgo?1:0) - (rgo?1:0);
   end
   final_wa<=wa; final_ra<=ra;
  end
 end
 always @(negedge clk) begin
  if (!rst && tick>=CYCLES) begin
   if (locked!==1'b1) never_locked<=1;
   if (pause===1'b1 && tick>2*420000) stuck_reset<=1;
   $display("%s FIRST=%0d tick=%0d user_first=%0d first_lock=%0d locked=%b pause=%b drops=%0d blocked=%0d writes=%0d reads=%0d jumps=%0d dup=%0d maxocc=%0d finalwa=%0d finalra=%0d",
     NAME,FIRST,tick,user_first,first_lock,locked,pause,lock_drops,blocked_writes,writes,reads,addr_jumps,duplicate_writes,max_occ,final_wa,final_ra);
   $finish;
  end
 end
endmodule

module tb;
 reg clk=0,rst=1; always #20 clk=~clk;
 wire [31:0] u1,l1,d1,b1,a1,w1,r1,j1,dup1; wire signed[31:0] m1,f1; wire[9:0] wa1,ra1; wire n1,s1;
 wire [31:0] u2,l2,d2,b2,a2,w2,r2,j2,dup2; wire signed[31:0] m2,f2; wire[9:0] wa2,ra2; wire n2,s2;
 wire [31:0] u3,l3,d3,b3,a3,w3,r3,j3,dup3; wire signed[31:0] m3,f3; wire[9:0] wa3,ra3; wire n3,s3;
 wire [31:0] u4,l4,d4,b4,a4,w4,r4,j4,dup4; wire signed[31:0] m4,f4; wire[9:0] wa4,ra4; wire n4,s4;
 phase_case #(.FIRST(35390),.NAME("A35390")) c1(clk,rst,u1,l1,d1,b1,a1,w1,r1,j1,dup1,m1,f1,wa1,ra1,n1,s1);
 phase_case #(.FIRST(35392),.NAME("B35392")) c2(clk,rst,u2,l2,d2,b2,a2,w2,r2,j2,dup2,m2,f2,wa2,ra2,n2,s2);
 phase_case #(.FIRST(35360),.NAME("C35360"))     c3(clk,rst,u3,l3,d3,b3,a3,w3,r3,j3,dup3,m3,f3,wa3,ra3,n3,s3);
 phase_case #(.FIRST(35464),.NAME("D35464"))   c4(clk,rst,u4,l4,d4,b4,a4,w4,r4,j4,dup4,m4,f4,wa4,ra4,n4,s4);
 initial begin
  repeat(10) @(negedge clk); rst=0;
  repeat(430000) @(negedge clk);
  $display("SUMMARY never_locked=%0d/%0d/%0d/%0d drops=%0d/%0d/%0d/%0d blocked=%0d/%0d/%0d/%0d jumps=%0d/%0d/%0d/%0d dup=%0d/%0d/%0d/%0d maxocc=%0d/%0d/%0d/%0d",
    n1,n2,n3,n4,d1,d2,d3,d4,b1,b2,b3,b4,j1,j2,j3,j4,dup1,dup2,dup3,dup4,m1,m2,m3,m4);
  if (n1||n2||n3||n4||d1||d2||d3||d4||b1||b2||b3||b4||j1||j2||j3||j4||dup1||dup2||dup3||dup4)
    $display("PHASE_CAPTURE_FAIL");
  else $display("PHASE_CAPTURE_PASS");
  $finish;
 end
endmodule
