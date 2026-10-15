`timescale 1ns/1ps
module osd_tb;
reg clk=0;always #5 clk=~clk;
reg rst=1,hs=0,vs=0,de=0;
reg [23:0] rgb=24'h123456;
reg enable=0;
reg [2:0] mode=0,contrast=2;
reg signed [8:0] brightness=0;
reg [7:0] interval=10,progress=0;
reg [1:0] transition_mode=0,scale_mode=0;reg [3:0] volume=8;
reg paused=0,auto_mode=0,mute=0;
reg [3:0] state=0;
reg [9:0] tx=16,ty=16,sx=16,sy=40,tick_y=450;
reg [23:0] fg=24'heeddcc,accent=24'hff2200;
wire oh,ov,od;wire [23:0] out;
osd_overlay dut(clk,rst,hs,vs,de,rgb,enable,mode,brightness,contrast,interval,transition_mode,scale_mode,volume,paused,auto_mode,mute,state,progress,tx,ty,sx,sy,tick_y,fg,accent,oh,ov,od,out);
integer checked=0,x,y,k;reg [23:0] expected;
reg [191:0] expected_caption="TF CARD HDMI AUDIO VIDEO";
reg [95:0] expected_title="HX4S20 MEDIA";
task cycle;
 input [23:0] exp;
 begin
 @(posedge clk);#1;
 if({oh,ov,od}!=={hs,vs,de})$fatal(1,"sync mismatch");
 if(out!==exp)$fatal(1,"pixel x%0d y%0d got %h expected %h",x,y,out,exp);
 checked=checked+1;@(negedge clk);
 end
endtask
task frame_start;
 begin de=0;vs=1;hs=0;cycle(rgb);vs=0;cycle(rgb);end
endtask
initial begin
 for(k=0;k<12;k=k+1)
  if(dut.title_char(k)!==expected_title[95-k*8 -:8])$fatal(1,"title character %0d",k);
 for(k=0;k<32;k=k+1)begin
  if(k<24)begin
   if(dut.ticker_char(k)!==expected_caption[191-k*8 -:8])$fatal(1,"caption character %0d",k);
  end else if(dut.ticker_char(k)!==" ")$fatal(1,"caption padding %0d",k);
 end
 @(posedge clk);#1;if({oh,ov,od,out}!==0)$fatal(1,"reset");
 @(negedge clk);rst=0;
 // Disabled overlay must preserve even blank RGB and all sync signals.
 frame_start;
 for(y=0;y<480;y=y+1)begin
  for(x=0;x<640;x=x+1)begin de=1;hs=x%2;rgb={x[7:0],y[7:0],8'h6a};cycle(rgb);end
  de=0;hs=1;cycle(rgb);
 end
 // Title wins overlapping status/ticker/progress; its 2x font has a gap.
 enable=1;tx=0;ty=0;sx=0;sy=0;tick_y=0;rgb=24'h123456;
 frame_start;
 for(x=0;x<16;x=x+1)begin
  de=1;expected=(x<2 || (x>=8 && x<10))?fg:24'h101820;cycle(expected);
 end
 de=0;cycle(rgb);
 // Dynamic formatting, signed extrema and all eight modes.
 brightness=-256;interval=255;state=15;paused=1;auto_mode=1;mute=1;
 if(dut.status_char(7)!="-" || dut.status_char(8)!="2" || dut.status_char(9)!="5" || dut.status_char(10)!="6")$fatal(1,"brightness text");
 if(dut.status_char(21)!="2" || dut.status_char(22)!="5" || dut.status_char(23)!="5" || dut.status_char(33)!="F")$fatal(1,"interval/state text");
 if(dut.status_char(25)!="P" || dut.status_char(27)!="A" || dut.status_char(29)!="M")$fatal(1,"status flags");
 for(k=0;k<8;k=k+1)begin
  mode=k;#1;
  case(k)
  0:if(dut.status_char(0)!="P")$fatal;
  1:if(dut.status_char(0)!="B")$fatal;
  2:if(dut.status_char(0)!="C")$fatal;
  3:if(dut.status_char(0)!="T")$fatal;
  4:if(dut.status_char(0)!="O")$fatal;
  5:if(dut.status_char(0)!="T")$fatal;
  6:if(dut.status_char(0)!="Z")$fatal;
  7:if(dut.status_char(0)!="V")$fatal;
  endcase
 end
 transition_mode=3;scale_mode=2;volume=15;
 if(dut.status_char(37)!="3" || dut.status_char(41)!="2" || dut.status_char(45)!="1" || dut.status_char(46)!="5")$fatal(1,"transition/scale/volume text");
 // Reset scrolling to known phase; frame 1 shifts left one pixel.
 rst=1;@(posedge clk);#1;@(negedge clk);rst=0;
 tx=1000;ty=1000;sx=1000;sy=1000;tick_y=0;
 frame_start;
 for(x=0;x<6;x=x+1)begin de=1;cycle(x<4?accent:24'h101820);end
 de=0;cycle(rgb);
 // Frame 2: same T top stroke, now only three pixels remain.
 frame_start;
 for(x=0;x<6;x=x+1)begin de=1;cycle(x<3?accent:24'h101820);end
 de=0;cycle(rgb);
 // Title near the right edge clips instead of wrapping its unsigned extent.
 tx=639;ty=0;tick_y=1000;
 frame_start;
 for(x=0;x<640;x=x+1)begin de=1;cycle(x==639?fg:rgb);end
 de=0;cycle(rgb);tx=1000;ty=1000;
 // Progress endpoints and one partial value, with exact clip boundaries.
 tick_y=1000;
 for(k=0;k<3;k=k+1)begin
  case(k)0:progress=0;1:progress=128;2:progress=255;endcase
  frame_start;
  for(y=0;y<473;y=y+1)begin
   for(x=0;x<640;x=x+1)begin
    de=1;expected=rgb;
    if(y>=468 && y<472 && x>=16 && x<272)
     expected=(progress==255 || x-16<progress)?accent:24'h202020;
    cycle(expected);
   end
   de=0;cycle(rgb);
  end
 end
 rst=1;@(posedge clk);#1;if({oh,ov,od,out}!==0)$fatal(1,"midframe reset");
 $display("TEST_PASS osd_overlay %0d sync/pixel checks",checked);$finish;
end
endmodule
