`timescale 1ns/1ps
// Actual RTL pixel dump for review; deterministic synthetic PCM ramp input.
module audio_visual_render_tb;
reg clk=0;always #20 clk=~clk;
reg rst=1,hs=0,vs=0,de=0,sample_valid=0,render=0;
reg[23:0]sample_left=0,sample_right=0;wire oh,ov,od;wire[23:0]out;
integer k,n,x,y,handle,pixels=0,exported=0;
audio_visualizer dut(clk,rst,hs,vs,de,24'h123456,sample_valid,sample_left,sample_right,
 16'd16384,4'd3,1'b1,oh,ov,od,out);
always @(posedge clk)begin
 #2;
 if(render&&od)begin
  if(pixels>=640*300)begin
   $fwrite(handle,"%0d %0d %0d\n",out[23:16],out[15:8],out[7:0]);exported=exported+1;
  end
  pixels=pixels+1;
 end
end
task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
initial begin
 tick;rst=0;
 for(k=0;k<300;k=k+1)begin
  for(n=0;n<64;n=n+1)begin sample_valid=1;sample_left=((k%64)-32)*262144;sample_right=(31-k%64)*262144;tick;end
 end
 sample_valid=0;
 handle=$fopen("audio_visual_preview.ppm.out","w");
 $fwrite(handle,"P3\n640 180\n255\n");render=1;
 vs=1;tick;vs=0;tick;
 for(y=0;y<480;y=y+1)begin
  for(x=0;x<640;x=x+1)begin de=1;hs=x%2;tick;end
  de=0;tick;
 end
 tick;render=0;$fclose(handle);
 if(pixels!=307200||exported!=115200)$fatal(1,"render count %0d %0d",pixels,exported);
 $display("TEST_PASS audio visual actual RTL raster export 640x180, source synthetic signed stereo PCM ramp");$finish;
end
endmodule
