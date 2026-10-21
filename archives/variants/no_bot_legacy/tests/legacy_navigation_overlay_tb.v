`timescale 1ns/1ps
// FINAL html_video_overlay output crop, not fullscanout or nativeframe cadence.
// Synthetic short VS frames advance real OSD swap/typewriter state; no RGB force.
module legacy_navigation_overlay_tb;
 reg clk=0;always#20 clk=~clk;reg rst=1,vs=0,de=0,event_page=0,reverse=0;
 reg[2:0]page=0;reg[23:0]src=0;wire oh,ov,od;wire[23:0]rgb;
 reg[23:0]backgrounds[0:318719];reg[15:0]peaks[0:255];integer age=0;
 wire[50:0]cfg={4'd4,4'd0,1'b0,1'b0,1'b1,8'd0,4'd8,2'd0,2'd1,1'b1,8'd5,3'd2,9'd0,3'd0};
 html_video_overlay dut(.clk(clk),.rst(rst),.i_hs(1'b0),.i_vs(vs),.i_de(de),.i_rgb(src),.config_data(cfg),.page_event(event_page),.page_index(page),.dual_enable(1'b0),.page_reverse(reverse),.focus(3'd0),.audio_peak(peaks[age%256]),.audio_status(4'd2),.o_hs(oh),.o_vs(ov),.o_de(od),.o_rgb(rgb));
 integer xx,yy,fd,pixels=0,totalpixels=0,caseid,k;reg capture=0;reg[255:0]filename;reg[127:0]label;
 always@(posedge clk)begin #1;if(capture&&od)begin if(^rgb===1'bx)$fatal(1,"unknown finaloverlaypixel");$fwrite(fd,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);pixels=pixels+1;totalpixels=totalpixels+1;end end
 task step;begin @(posedge clk);#2;@(negedge clk);end endtask
 task frame;begin vs=1;step;vs=0;event_page=0;repeat(100)step;end endtask
 task crop;begin
  $sformat(filename,"%0s_%03d.ppm",label,age);fd=$fopen(filename,"wb");if(!fd)$fatal(1,"cannotcreateactualoverlaycrop");$fwrite(fd,"P6\n640 83\n255\n");
  dut.osd.y=386;pixels=0;capture=1;
  for(yy=0;yy<83;yy=yy+1)begin
   for(xx=0;xx<640;xx=xx+1)begin de=1;src=backgrounds[page*53120+yy*640+xx];step;end
   de=0;step;
  end
  repeat(12)step;capture=0;$fclose(fd);if(pixels!=53120)$fatal(1,"actualoverlaycropcount%0d",pixels);
  $display("NAV_CROP %0s oldnewcase%0d page%0d reverse%0d age%0d typed%0d delay%0d swap%0d pixels%0d",filename,caseid,page,reverse,age,dut.osd.typed_count,dut.osd.typing_delay,dut.osd.swap_age,pixels);$fflush();
 end endtask
 initial begin
  $readmemh("navigation_background.hex",backgrounds);$readmemh("real_wav_peaks.hex",peaks);
  for(caseid=0;caseid<3;caseid=caseid+1)begin
   rst=1;de=0;vs=0;event_page=0;repeat(8)step;rst=0;
   page=caseid==0?0:caseid==1?1:5;reverse=0;age=0;event_page=1;frame;
   dut.osd.typed_count=127; // declared oldcaption prewarm, before the tested navigation
   page=caseid==0?1:0;reverse=caseid==1;label=caseid==0?"forward":caseid==1?"reverse":"wrap";event_page=1;
   for(age=0;age<=160;age=age+1)begin
    frame;
    if(dut.osd.page!==page)$fatal(1,"captionpage not atomic atframeboundary");
    if(dut.osd.swap_age!==(age>31?5'd31:age[4:0]))$fatal(1,"swapage after navigation");
    if(age<=33&&dut.osd.typed_count!=0)$fatal(1,"caption before550ms framebudget");
    if(age==40&&dut.osd.typed_count==0)$fatal(1,"19cps typewriter failed tostart");
    if(age==0||age==3||age==10||age==30||age==40||age==80||age==160)crop;
   end
  end
  if(totalpixels!=1115520)$fatal(1,"allnavigationcrops total%0d",totalpixels);
  $display("TEST_PASS finalwrappernavigation forward0to1_reverse1to0_wrap5to0,21actual640x83RGBcrops,1115520pixels,33framecaptiondelay,19cpsstart,swap32frames; acceleratedframe-state OVERLAY_SEGMENT_ONLY");$finish;
 end
 initial begin #100000000;$fatal(1,"navigationoverlaywatchdog");end
endmodule
