// Actual overlay RTL samples on a known synthetic test backdrop.
// Controller ages advance through accelerated blank VS events; not whole-chain video.
`timescale 1ns/1ps
module html_bot_action_samples_tb;
 reg clk=0;always #20 clk=~clk;
 reg rst=1,hs=0,vs=0,de=0;
 reg [23:0] rgb=24'h141311;
 reg enable=0,osd_enable=0,page_event=0;
 reg [2:0] page=0,mode=0;
 reg signed [1:0] direction=1;
 reg dual=0,zoom=0;
 reg signed [8:0] brightness=0;
 wire h1,v1,d1,h2,v2,d2,speaking,syllable;
 wire [23:0] rgb1,rgb2;
 html_osd_overlay osd(.clk(clk),.rst(rst),.i_hs(hs),.i_vs(vs),.i_de(de),.i_rgb(rgb),
  .osd_enable(osd_enable),.page_event(page_event),.page_index(page),.dual_enable(dual),.zoom_enable(zoom),.scale_mode(2'd0),.focus(3'd0),
  .progress(8'd128),.brightness(brightness),.contrast(3'd2),.mode(mode),.volume(4'd8),
  .mute(1'b0),.paused(1'b0),.auto_mode(1'b1),.interval(8'd5),.interval_fraction(4'd0),
  .audio_peak(16'd24576),.audio_status(4'd2),.speaking(speaking),.syllable(syllable),.o_hs(h1),.o_vs(v1),.o_de(d1),.o_rgb(rgb1));
 html_bot_overlay bot(.clk(clk),.rst(rst),.i_hs(h1),.i_vs(v1),.i_de(d1),.i_rgb(rgb1),
  .enable(enable),.page_event(page_event),.page_direction(direction),
  .speaking(speaking),.syllable(syllable),.audio_level(8'd0),
  .o_hs(h2),.o_vs(v2),.o_de(d2),.o_rgb(rgb2));
 reg [2:0] sync_expect[0:9];reg [23:0] rgb_expect[0:9];
 integer x_expect[0:9],y_expect[0:9];
 integer j,checks=0,pixels=0,changed_bot=0,white_eye=0;
 integer capture=0,fd=0,ix=0,iy=0;
 reg bypass_check=1,quick_check=0;
 reg [15:0] motion_before;
 always @(posedge clk)begin
  if(rst)begin
   for(j=0;j<10;j=j+1)begin sync_expect[j]=0;rgb_expect[j]=0;x_expect[j]=0;y_expect[j]=0;end
  end else begin
   for(j=9;j>0;j=j-1)begin
    sync_expect[j]=sync_expect[j-1];rgb_expect[j]=rgb_expect[j-1];
    x_expect[j]=x_expect[j-1];y_expect[j]=y_expect[j-1];
   end
   sync_expect[0]={hs,vs,de};rgb_expect[0]=rgb;x_expect[0]=ix;y_expect[0]=iy;
   #1;
   if({h2,v2,d2}!==sync_expect[9])$fatal(1,"stream alignment expected%h got%h",sync_expect[9],{h2,v2,d2});
   if(bypass_check&&rgb2!==rgb_expect[9])$fatal(1,"disabled bypass RGB mismatch %h %h",rgb2,rgb_expect[9]);
   if(^rgb2===1'bx)$fatal(1,"unknown pixel at%0d,%0d",x_expect[9],y_expect[9]);
   checks=checks+1;
   if(quick_check&&capture&&d2&&x_expect[9]==456&&y_expect[9]==414&&rgb2!==24'h1a1916)
    $fatal(1,"actual PCM bar center color/geometry %h",rgb2);
   if(quick_check&&capture&&d2&&x_expect[9]==456&&y_expect[9]==400&&rgb2!==24'hede9e2)
    $fatal(1,"PCM bar must be vertically centered");
   if(capture&&d2&&x_expect[9]==520&&y_expect[9]==368&&rgb2!==rgb_expect[9])
    $fatal(1,"sprite has an opaque rectangle/incorrect background alpha");
   if(capture&&d2&&osd_enable&&x_expect[9]==100&&y_expect[9]==390&&rgb2!==24'hede9e2)
    $fatal(1,"paperplate color got%h",rgb2);
   if(capture&&d2&&!osd_enable&&x_expect[9]==100&&y_expect[9]==390&&rgb2!==rgb_expect[9])
    $fatal(1,"OSDoff left plate/text behind");
   if(capture&&d2)begin
    $fwrite(fd,"%c%c%c",rgb2[23:16],rgb2[15:8],rgb2[7:0]);pixels=pixels+1;
    if(x_expect[9]>=520&&y_expect[9]>=368&&rgb2!=rgb_expect[9])changed_bot=changed_bot+1;
    if(x_expect[9]>=520&&y_expect[9]>=368&&rgb2[23:16]>210&&rgb2[15:8]>210)white_eye=white_eye+1;
   end
  end
 end
 task step;begin @(posedge clk);#2;@(negedge clk);end endtask
 task frame_pulse;
 begin
  de=0;vs=1;repeat(15)step;vs=0;repeat(15)step;
 end endtask
 task advance_frames;
 input integer n;
 integer f;
 begin for(f=0;f<n;f=f+1)frame_pulse;end
 endtask
 task render;
 input [511:0] filename;
 integer xx,yy;
 begin
  frame_pulse;
  fd=$fopen(filename,"wb");if(!fd)$fatal(1,"cannot create frame");
  $fwrite(fd,"P6\n640 480\n255\n");capture=1;pixels=0;changed_bot=0;white_eye=0;
  for(yy=0;yy<480;yy=yy+1)begin
   for(xx=0;xx<800;xx=xx+1)begin
    ix=xx;iy=yy;de=xx<640;hs=xx>=656&&xx<752;
    rgb[23:16]=8'd20+(yy>>6);rgb[15:8]=8'd19+(xx>>7);rgb[7:0]=8'd17;step;
   end
  end
  de=0;repeat(16)step;capture=0;$fclose(fd);
  if(pixels!=307200)$fatal(1,"frame pixel count %0d",pixels);
  $display("FRAME %0s pixels%0d bot_changed%0d bright_eye%0d typed%0d reaction%0d",filename,pixels,changed_bot,white_eye,osd.typed_count,bot.reaction_age);
 end
 endtask
 initial begin
  repeat(3)step;rst=0;repeat(12)step;
  bypass_check=0;enable=1;osd_enable=1;page=2;direction=1;
  page_event=1;step;page_event=0;
  render("output/html_fidelity/bot_osd/action_age000.ppm");
  if(bot.reaction_age!=0)$fatal(1,"sample age expected0 got%0d",bot.reaction_age);
  $display("ACTION_SAMPLE_PASS age0 nominal_time_us0 gaze%0d tilt%0d shape%0d hop%0d typed%0d",bot.gaze_x,bot.tilt,bot.shape,bot.hop,osd.typed_count);$fflush();
  advance_frames(4);
  render("output/html_fidelity/bot_osd/action_age005.ppm");
  if(bot.reaction_age!=5)$fatal(1,"sample age expected5 got%0d",bot.reaction_age);
  $display("ACTION_SAMPLE_PASS age5 nominal_time_us84000 gaze%0d tilt%0d shape%0d hop%0d typed%0d",bot.gaze_x,bot.tilt,bot.shape,bot.hop,osd.typed_count);$fflush();
  advance_frames(19);
  render("output/html_fidelity/bot_osd/action_age025.ppm");
  if(bot.reaction_age!=25)$fatal(1,"sample age expected25 got%0d",bot.reaction_age);
  $display("ACTION_SAMPLE_PASS age25 nominal_time_us420000 gaze%0d tilt%0d shape%0d hop%0d typed%0d",bot.gaze_x,bot.tilt,bot.shape,bot.hop,osd.typed_count);$fflush();
  advance_frames(39);
  render("output/html_fidelity/bot_osd/action_age065.ppm");
  if(bot.reaction_age!=65)$fatal(1,"sample age expected65 got%0d",bot.reaction_age);
  $display("ACTION_SAMPLE_PASS age65 nominal_time_us1092000 gaze%0d tilt%0d shape%0d hop%0d typed%0d",bot.gaze_x,bot.tilt,bot.shape,bot.hop,osd.typed_count);$fflush();
  advance_frames(26);
  render("output/html_fidelity/bot_osd/action_age092.ppm");
  if(bot.reaction_age!=92)$fatal(1,"sample age expected92 got%0d",bot.reaction_age);
  $display("ACTION_SAMPLE_PASS age92 nominal_time_us1545600 gaze%0d tilt%0d shape%0d hop%0d typed%0d",bot.gaze_x,bot.tilt,bot.shape,bot.hop,osd.typed_count);$fflush();
  advance_frames(7);
  render("output/html_fidelity/bot_osd/action_age100.ppm");
  if(bot.reaction_age!=100)$fatal(1,"sample age expected100 got%0d",bot.reaction_age);
  $display("ACTION_SAMPLE_PASS age100 nominal_time_us1680000 gaze%0d tilt%0d shape%0d hop%0d typed%0d",bot.gaze_x,bot.tilt,bot.shape,bot.hop,osd.typed_count);$fflush();
  $display("ACTION_SAMPLES_SIM_PASS6 actualRTL full640x480 frames; acceleratedblankcontroller updates; samplednotcontinuous");$finish;
 end
 initial begin #200000000;$fatal(1,"timeout");end
endmodule
