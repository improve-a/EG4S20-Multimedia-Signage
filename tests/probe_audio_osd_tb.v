`timescale 1ns/1ps
// OSD audio-bar pixel test. Real html_video_overlay + html_osd_overlay at the
// production 25MHz pixel cadence, real glyph/column/palette ROMs, and one
// audio_peak value per frame taken from the actual 07_MUSIC.WAV 64-sample
// windows (plus silence, mute and range boundaries). Only the scan y counter is
// driven row by row, as the existing focused OSD probe does; every logic,
// palette and blend stage is the production one.
module probe_audio_osd_tb #(parameter FRAMES=21);
 reg clk=0;always #20 clk=~clk;         // 25MHz
 reg rst=1,hs=0,vs=0,de=0;
 reg [15:0] audio_peak=0;
 reg mute_f=0;
 reg [15:0] peak_mem[0:FRAMES-1];
 reg [7:0] mute_mem[0:FRAMES-1];
 // fraction,state,mute,paused,auto,progress,volume,scale,transition,osd,interval,contrast,brightness,mode
 wire [50:0] cfg={4'd4,4'd0,mute_f,1'b0,1'b1,8'd0,4'd8,2'd0,2'd1,1'b1,8'd5,3'd2,9'sd0,3'd0};
 wire oh,ov,od;wire [23:0] rgb;
 html_video_overlay dut(.clk(clk),.rst(rst),.i_hs(hs),.i_vs(vs),.i_de(de),.i_rgb(24'h808080),
  .config_data(cfg),.page_event(1'b0),.page_index(3'd0),.dual_enable(1'b0),
  .page_reverse(1'b0),.focus(3'd0),.audio_peak(audio_peak),.audio_status(4'd3),
  .o_hs(oh),.o_vs(ov),.o_de(od),.o_rgb(rgb));
 task step;begin @(posedge clk);#2;@(negedge clk);end endtask
 integer dfd,frame=0,x0,y0,xx=0,yy=0,dumped=0;
 reg[2:0]sq[0:5];reg cq[0:5];reg checking=0;
 integer xq[0:5],yq[0:5],j;
 always @(posedge clk)begin
  if(rst)begin for(j=0;j<6;j=j+1)begin sq[j]=0;cq[j]=0;xq[j]=0;yq[j]=0;end end
  else begin
   for(j=5;j>0;j=j-1)begin sq[j]=sq[j-1];cq[j]=cq[j-1];xq[j]=xq[j-1];yq[j]=yq[j-1];end
   sq[0]={hs,vs,de};cq[0]=checking;xq[0]=xx;yq[0]=yy;
   #1;
   if({oh,ov,od}!==sq[5])$fatal(1,"six-cycle sync mismatch frame%0d",frame);
   if(cq[5]&&od&&xq[5]>=440&&xq[5]<512&&yq[5]>=384&&yq[5]<434)begin
    $fwrite(dfd,"%0d %0d %0d %06x\n",frame,xq[5],yq[5],rgb);dumped=dumped+1;
   end
  end
 end
 task row;input integer target;begin
  de=0;repeat(8)step;dut.osd.y=target;yy=target;checking=1;de=1;
  for(x0=0;x0<512;x0=x0+1)begin xx=x0;step;end
  de=0;checking=0;repeat(8)step;
 end endtask
 initial begin
  if(!$value$plusargs("dump=%s",dump_name))$fatal(1,"+dump=<file> required");
  dfd=$fopen(dump_name,"w");
  if(dfd==0)$fatal(1,"cannot open dump");
  $readmemh("osd_peaks.hex",peak_mem);
  $readmemh("osd_mute.hex",mute_mem);
  repeat(4)step;rst=0;repeat(8)step;
  for(frame=0;frame<FRAMES;frame=frame+1)begin
   audio_peak=peak_mem[frame];
   mute_f=mute_mem[frame][0];
   vs=1;step;vs=0;repeat(32)step;      // frame_start latches the history
   for(y0=384;y0<442;y0=y0+1)row(y0);
  end
  $fclose(dfd);
  if(dumped<FRAMES*3500)$fatal(1,"only %0d ROI pixels captured",dumped);
  $display("TEST_PASS probe_audio_osd frames=%0d pixels=%0d",FRAMES,dumped);
  $finish;
 end
 reg [255:0] dump_name;
 initial begin #120000000;$fatal(1,"osd watchdog frame%0d",frame);end
endmodule
