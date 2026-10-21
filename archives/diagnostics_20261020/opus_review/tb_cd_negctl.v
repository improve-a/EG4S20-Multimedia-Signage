`timescale 1ns/1ps
// Question: with the netlist-derived receiver control (mapped_receiver_control.v),
// the actual fixed-latency 800x525 source raster, and the core ready equation
// ready_next = !last && (empty || ready), can C = valid&&!ready_seen or
// D = valid&&!prev_valid&&!ready_seen ever occur after video_rst release?
// ready_seen = ready && !pro_full; pro_full modelled as occupancy >= PF (swept).
// Occupancy is tracked from write_go/read_go (same convention as tb_phase_capture4).
module cd_case #(parameter SLIP=0, parameter FIRST=35392, parameter PF=1000, parameter CYCLES=1300000, parameter NAME="c")(input clk,rst);
 integer tick=0,h=0,y=0,rel,fr; reg sof=0,sol=0,rd=0;
 wire valid,user,last,locked,pause,fifo_rst,wgo,rgo; wire [9:0] wa,ra;
 always @* begin rel = tick - FIRST - ((tick>=FIRST+420000) ? SLIP : 0); fr = ((rel%420000)+420000)%420000; end
 assign valid = (!rst) && (tick>=FIRST) && (fr/800<480) && (fr%800<640);
 assign user  = valid && (fr==0);
 assign last  = valid && (fr%800==639);
 mapped_receiver_control dut(clk,rst,user,valid,sof,sol,rd,locked,pause,fifo_rst,wgo,rgo,wa,ra);
 reg ready=0, prev_valid=0; integer occ=0, maxocc=0, c_cnt=0, d_cnt=0, c_first=-1, d_first=-1, drops=0; reg was_locked=0;
 wire empty = (wa==ra);
 wire pro_full = (occ >= PF);
 wire ready_seen = ready && !pro_full;
 always @(posedge clk) begin
  if (rst) begin
   tick<=0; h<=0; y<=0; sof<=0; sol<=0; rd<=0; ready<=0; prev_valid<=0; occ<=0; was_locked<=0;
  end else begin
   tick<=tick+1;
   sof <= (h==150) && (y==45);
   sol <= (h==160) && (y>=45);
   rd  <= (h>=160) && (y>=45);
   if (h==15) y <= (y==524) ? 0 : y+1;
   if (!pause) h <= (h==799) ? 0 : h+1;
   ready <= !last && (empty || ready);
   prev_valid <= valid;
   was_locked <= locked;
   if (was_locked && !locked) drops<=drops+1;
   if (valid && !ready_seen) begin c_cnt<=c_cnt+1; if (c_first<0) c_first<=tick; end
   if (valid && !prev_valid && !ready_seen) begin d_cnt<=d_cnt+1; if (d_first<0) d_first<=tick; end
   if (fifo_rst) occ<=0; else begin occ <= occ + (wgo?1:0) - (rgo?1:0); if (occ>maxocc) maxocc<=occ; end
  end
 end
 reg shown=0;
 always @(negedge clk) if (!rst && tick>=CYCLES && !shown) begin
  shown<=1;
  $display("%s FIRST=%0d PF=%0d locked=%b drops=%0d C=%0d D=%0d c_first=%0d d_first=%0d maxocc=%0d",
           NAME,FIRST,PF,locked,drops,c_cnt,d_cnt,c_first,d_first,maxocc);
 end
endmodule

module tb;
 reg clk=0,rst=1; always #20 clk=~clk;
 // Negative controls (TB sensitivity only): from frame 2 the source raster leads the
 // locked core by |SLIP| cycles. +50 = source later; -100/-200 = source earlier.
 cd_case #(.SLIP(50),  .FIRST(35392),.CYCLES(900000),.NAME("neg_late50"))   a(clk,rst);
 cd_case #(.SLIP(-100),.FIRST(35392),.CYCLES(900000),.NAME("neg_early100")) b(clk,rst);
 cd_case #(.SLIP(-200),.FIRST(35392),.CYCLES(900000),.NAME("neg_early200")) c(clk,rst);
 cd_case #(.SLIP(0),   .FIRST(35392),.CYCLES(900000),.NAME("pos_noslip"))   p(clk,rst);
 initial begin repeat(10) @(negedge clk); rst=0; repeat(900010) @(negedge clk); $finish; end
endmodule
