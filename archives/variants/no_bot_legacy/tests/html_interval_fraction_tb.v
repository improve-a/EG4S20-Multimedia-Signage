`timescale 1ns/1ps
module html_interval_fraction_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,vs=0,de=0;reg[3:0] fraction=4;wire h,v,d;wire[23:0] rgb;
 html_osd_overlay dut(.clk(clk),.rst(rst),.i_hs(1'b0),.i_vs(vs),.i_de(de),.i_rgb(24'h123456),
  .osd_enable(1'b1),.page_event(1'b0),.page_index(3'd0),.dual_enable(1'b0),.zoom_enable(1'b0),
  .scale_mode(2'd0),.focus(3'd0),.progress(8'd0),.brightness(9'd0),.contrast(3'd2),.mode(3'd1),
  .volume(4'd8),.mute(1'b0),.paused(1'b0),.auto_mode(1'b1),.interval(8'd5),.interval_fraction(fraction),
  .audio_peak(16'd0),.audio_status(4'd0),.speaking(),.syllable(),.o_hs(h),.o_vs(v),.o_de(d),.o_rgb(rgb));
 integer xx=0,yy=0,j,pixels=0;integer xq[0:4],yq[0:4];reg capture=0;
 always @(posedge clk)begin
  for(j=4;j>0;j=j-1)begin xq[j]=xq[j-1];yq[j]=yq[j-1];end
  xq[0]=xx;yq[0]=yy;
  #1;if(capture&&d)begin
   pixels=pixels+1;
   if(xq[4]==178&&yq[4]==469)begin
    if(fraction==5&&rgb!==24'hede9e2)$fatal(1,"5.5s decimal pixel missing got%h",rgb);
    if(fraction==4&&rgb===24'hede9e2)$fatal(1,"5.4s decimal pixel confused with5.5s");
   end
  end
 end
 task step;begin @(posedge clk);#2;@(negedge clk);end endtask
 task frame;begin vs=1;step;vs=0;repeat(8)step;end endtask
 task region;begin
  dut.y=467;capture=1;
  for(yy=467;yy<480;yy=yy+1)begin
   for(xx=0;xx<640;xx=xx+1)begin de=1;step;end
   de=0;step;
  end
  repeat(8)step;capture=0;
 end endtask
 initial begin
  repeat(4)step;rst=0;frame;
  if(dut.live_char(23)!="5"||dut.live_char(24)!="."||dut.live_char(25)!="4"||dut.live_char(26)!="s")$fatal(1,"5.4s format");
  region;fraction=5;repeat(3)step;
  if(dut.live_char(25)!="4")$fatal(1,"fraction changed midframe");
  frame;if(dut.live_char(25)!="5")$fatal(1,"5.5s format");region;
  fraction=0;frame;if(dut.live_char(25)!="Z"||dut.live_char(27)!="1")$fatal(1,"legacy zero-fraction field layout changed");
  if(pixels!=16640)$fatal(1,"fraction pixel count%0d",pixels);
  $display("TEST_PASS interval_fraction5.4s/5.5s frameatomic,16640DUTpixels,zero-fractioncompatible");$finish;
 end
endmodule
