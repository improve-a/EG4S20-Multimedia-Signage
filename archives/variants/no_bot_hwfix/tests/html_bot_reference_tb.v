`timescale 1ns/1ps
module html_bot_reference_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,vs=0,de=0;reg[23:0] rgb=0;wire oh,ov,od;wire[23:0] out;
 html_bot_overlay dut(.clk(clk),.rst(rst),.i_hs(1'b0),.i_vs(vs),.i_de(de),.i_rgb(rgb),
  .enable(1'b1),.page_event(1'b0),.page_direction(2'sd1),.speaking(1'b0),.syllable(1'b0),.audio_level(8'd0),
  .o_hs(oh),.o_vs(ov),.o_de(od),.o_rgb(out));
 reg[23:0] background[0:307199];initial $readmemh("page0_rgb.hex",background);
 integer xx=0,yy=0,j,fd,pixels=0,checks=0;reg capture=0;
 reg[2:0] syncq[0:4];integer xq[0:4],yq[0:4];
 always @(posedge clk)begin
  if(rst)for(j=0;j<5;j=j+1)begin syncq[j]=0;xq[j]=0;yq[j]=0;end
  else begin
   for(j=4;j>0;j=j-1)begin syncq[j]=syncq[j-1];xq[j]=xq[j-1];yq[j]=yq[j-1];end
   syncq[0]={1'b0,vs,de};xq[0]=xx;yq[0]=yy;
   #1;
   if({oh,ov,od}!==syncq[4])$fatal(1,"Bot referencefive-stage sync");checks=checks+1;
   if(capture&&od&&xq[4]>=520&&xq[4]<624)begin
    $fwrite(fd,"%c%c%c",out[23:16],out[15:8],out[7:0]);pixels=pixels+1;
   end
  end
 end
 task step;begin @(posedge clk);#2;@(negedge clk);end endtask
 initial begin
  repeat(5)step;rst=0;vs=1;step;vs=0;repeat(8)step;
  // Exact same known static motion fixture as the real full-chain suite.
  dut.frame_count=128;dut.breath_phase=0;dut.reaction_age=255;dut.blink_wait=500;dut.blink_phase=0;dut.event_pending=0;
  dut.gaze_x=0;dut.gaze_y=0;dut.gaze_vx=0;dut.gaze_vy=0;dut.tilt=0;dut.tilt_v=0;dut.shape=0;dut.shape_v=0;dut.hop=0;dut.hop_v=0;
  dut.y=368;
  fd=$fopen("bot_actual.ppm","wb");$fwrite(fd,"P6\n104 100\n255\n");capture=1;
  for(yy=368;yy<468;yy=yy+1)begin
   for(xx=0;xx<640;xx=xx+1)begin de=1;rgb=background[yy*640+xx];step;end
   de=0;step;
  end
  repeat(8)step;capture=0;$fclose(fd);
  if(pixels!=10400)$fatal(1,"Bot referencecount%0d",pixels);
  $display("TEST_PASS Bot104x100actualDUTpixels,source t0-equivalent seededpose,five-stage sync checks%0d",checks);$finish;
 end
endmodule
