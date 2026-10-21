`timescale 1ns/1ps
// Real raster + AXIS converter; fixed sync pipeline projection, no media/IP model.
module raster_tb;
 reg clk=0,rst=1;always #20 clk=~clk;
 wire hs,vs,de,req;
 video_timing_data timing(clk,rst,req,1'b1,hs,vs,de);
 reg [27:0] hp=0,vp=0,dp=0;
 always @(posedge clk)
  if(rst)begin hp<=0;vp<=0;dp<=0;end
  else begin hp<={hp[26:0],hs};vp<={vp[26:0],vs};dp<={dp[26:0],de};end
 wire av,au,al;wire [23:0] rgb;wire [27:0] flags;
 video_rgb_to_axis_640x480 axis(clk,rst,vp[27],dp[27],24'd0,au,av,al,rgb);
 hdmi_probe #(.WINDOW_CYCLES(100000)) probe(
  clk,rst,vp[27],hp[27],dp[27],av,au,al,1'b1,1'b1,1'b0,flags);
 integer sofs=0;
 always @(negedge clk)if(!rst&&au)begin
  sofs=sofs+1;
  if(sofs==3)begin
   if(!flags[9]||flags[10]||flags[16]||flags[17]||flags[20]||flags[21])
    $fatal(1,"native raster false alarm flags=%h",flags);
   $display("PROBE_NATIVE_RASTER_PASS 307200 pixel frames, 640 pixel lines; flags=%h",flags);
   $finish;
  end
 end
 initial begin repeat(5)@(negedge clk);rst=0;#40000000;$fatal(1,"timeout");end
endmodule
