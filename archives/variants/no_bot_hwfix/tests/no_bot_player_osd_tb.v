`timescale 1ns/1ps
// Real 25MHz/48kHz audio and 64sample peak, accelerated VS for bounded OSD crop.
module no_bot_player_osd_tb;
 reg clk=0;always #20 clk=~clk;reg rst=1,vs=0,de=0;reg[23:0]src=0;
 reg[15:0]pcm[0:4095];reg[23:0]background[0:53119];reg[31:0]fifo_data=0;
 wire pop,valid,uf,drained;wire[23:0]left,right;wire[15:0]peak;
 integer feed=0,checked=0,windows=0,acc=0,absval=0,cycles=0,lastcycle=0,delta=0,j,k,xx,yy,fd,pixels=0;integer hist[0:8];reg capture=0;
 audio_pcm_player player(.clk(clk),.rst(rst),.enabled(1'b1),.paused(1'b0),.muted(1'b0),.ready(1'b1),.eof(1'b0),.volume(4'd8),.fifo_empty(feed>=4096),.fifo_data(fifo_data),.fifo_pop(pop),.audio_valid(valid),.audio_left(left),.audio_right(right),.underflow(uf),.drained(drained),.wave_peak(peak));
 wire oh,ov,od;wire[23:0]rgb;wire[50:0]cfg={4'd4,4'd0,1'b0,1'b0,1'b1,8'd0,4'd8,2'd0,2'd1,1'b1,8'd5,3'd2,9'd0,3'd0};
 html_video_overlay dut(.clk(clk),.rst(rst),.i_hs(1'b0),.i_vs(vs),.i_de(de),.i_rgb(src),.config_data(cfg),.page_event(1'b0),.page_index(3'd0),.dual_enable(1'b0),.page_reverse(1'b0),.focus(3'd0),.audio_peak(peak),.audio_status(4'd2),.o_hs(oh),.o_vs(ov),.o_de(od),.o_rgb(rgb));
 always @(posedge clk)begin
  if(!rst&&pop)begin fifo_data<={pcm[feed],pcm[feed]};feed=feed+1;end
  #1;
  if(!rst)begin
   cycles=cycles+1;if(uf)$fatal(1,"realPCMunderflow");
   if(valid)begin
    if(left!=={pcm[checked],8'd0}||right!==left)$fatal(1,"PCMorderedmismatch%0d",checked);
    if(checked>0)begin delta=cycles-lastcycle;if(delta!=520&&delta!=521)$fatal(1,"not48kdelta%0d",delta);end
    lastcycle=cycles;absval=pcm[checked][15]?(65536-pcm[checked]):pcm[checked];if(absval>acc)acc=absval;checked=checked+1;
    if(checked%64==0)begin if(peak!==acc)$fatal(1,"64samplepeak got%0d expected%0d",peak,acc);windows=windows+1;$display("PCM_PEAK window%0d sample%0d peak%0d time%0t",windows,checked,peak,$time);acc=0;end
   end
  end
  if(capture&&od)begin if(^rgb===1'bx)$fatal(1,"unknownactualRGB");$fwrite(fd,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);pixels=pixels+1;end
 end
 task step;begin @(posedge clk);#2;@(negedge clk);end endtask
 initial begin
  $readmemh("formal_pcm.hex",pcm);$readmemh("home_crop.hex",background);for(j=0;j<9;j=j+1)hist[j]=0;
  repeat(8)step;rst=0;
  for(k=1;k<=9;k=k+1)begin
   wait(windows>=k);@(negedge clk);for(j=8;j>0;j=j-1)hist[j]=hist[j-1];hist[0]=peak>=32768?29:(peak>>10);vs=1;step;vs=0;repeat(100)step;
   for(j=0;j<9;j=j+1)if(dut.osd.audio_history[j]!==hist[j])$fatal(1,"actualOSDhistory%0d got%0d expected%0d",j,dut.osd.audio_history[j],hist[j]);
  end
  $write("ACTUAL_HISTORY");for(j=0;j<9;j=j+1)$write(" %0d",hist[j]);$write("\n");
  fd=$fopen("actual_player_osd.ppm","wb");if(!fd)$fatal(1,"cropfile");$fwrite(fd,"P6\n640 83\n255\n");dut.osd.y=386;capture=1;
  for(yy=0;yy<83;yy=yy+1)begin for(xx=0;xx<640;xx=xx+1)begin de=1;src=background[yy*640+xx];step;end de=0;step;end
  repeat(12)step;capture=0;$fclose(fd);if(pixels!=53120||checked<576||windows<9)$fatal(1,"shortcoverage");
  $display("TEST_PASS ACTUAL_PLAYER_OSD samples%0d windows%0d pixels%0d 25MHz48kHz gain8 identity actual64samplepeaks wired finalwrapper; acceleratedVS cropONLY",checked,windows,pixels);$finish;
 end
 initial begin #25000000;$fatal(1,"playerOSDwatchdog");end
endmodule
