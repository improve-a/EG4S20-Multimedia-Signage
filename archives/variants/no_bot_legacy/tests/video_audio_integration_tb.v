`timescale 1ns/1ps
// Production unencrypted video/audio path. PCM is parsed from actual WAV bytes.
// This is subsystem RTL verification, not encrypted HDMI/whole-board simulation.
module video_audio_integration_tb;
reg clk=0,sc=0;always #20 clk=~clk;always #5 sc=~sc;
reg rst=1,srst=1,hs=0,vs=0,de=0;reg[23:0]rgb=0;
reg[46:0]cfg=0;reg signed[8:0]brightness=40;reg[2:0]contrast=2;reg osd_enable=0;
wire th,tv,td;wire[23:0]trgb;wire forwarded,busy;
wire oh,ov,od;wire[23:0]out;wire av,user,last;wire[23:0]axis_data;
wire audio_valid,wav_valid,tone_valid;wire[23:0]left,right,wav_left,wav_right,tone_left,tone_right;wire[15:0]peak;wire[3:0]audio_status;
wire wav_selected;
wire acr_valid;wire[19:0]acr_cts,acr_n;integer acr_packets=0;
audio_output_mux production_mux(clk,rst,tone_valid,tone_left,tone_right,wav_left,wav_right,audio_status,4'd8,audio_valid,left,right,wav_selected);
wire[23:0]tone_abs=left[23]?(~left+24'd1):left;
wire[15:0]visual_peak=wav_selected?peak:tone_abs[23:8];
hdmi_audio_tone_pcm_scale tone(clk,rst,1'b0,tone_valid,tone_left,tone_right);
audio_arc_calculate acr(clk,rst,audio_valid,acr_valid,acr_cts,acr_n);

wire uf,of,eof,error,req,urgent;wire[31:0]addr;wire[11:0]level;
reg grant=0,sdv=0,sde=0;reg[7:0]sddata=0;reg[7:0]card[0:11263];
integer sd_busy=0,sd_offset=0,sd_base=0,sd_delay=0,requests=0;
integer f=-1,x=-1,y=-1,h,v,k,checks=0,pixels=0,sof_count=0,eol_count=0,pcm_frames=0;
integer wave_checks=0,peak_checks=0,render_pixels=0,handle;
reg[23:0]qrgb[0:5];reg[2:0]qsync[0:5];reg qmask[0:5];
integer qx[0:5],qy[0:5],qf[0:5];
integer hist_l[0:255],hist_r[0:255],hist_count=0,hist_wr=0,decimate=0;
integer pos,location,lval,rval,bar_width,ticker_pos,ref_scroll=0;
reg ref_prev_vs=0;
video_transition transition(.clk(clk),.rst(rst),.i_hs(hs),.i_vs(vs),.i_de(de),.i_rgb(rgb),
 .enable(1'b1),.mode(2'd0),.frame_start(vs),.candidate_toggle_async(1'b0),
 .display_fault_async(1'b0),.commit_ack_toggle(1'b0),.forwarded_commit_toggle(forwarded),
 .o_hs(th),.o_vs(tv),.o_de(td),.o_rgb(trgb),.transition_busy(busy));
video_extensions #(.ENABLE_AUDIO_VIS(1)) extensions(.clk(clk),.rst(rst),
 .i_hs(th),.i_vs(tv),.i_de(td),.i_rgb(trgb),.config_data(cfg),
 .sample_valid(audio_valid),.sample_left(left),.sample_right(right),
 .audio_peak(visual_peak),.audio_status(audio_status),.o_hs(oh),.o_vs(ov),.o_de(od),.o_rgb(out));
video_rgb_to_axis_640x480 hdmi_axis_video(clk,rst,ov,od,out,user,av,last,axis_data);
audio_media media(sc,srst,clk,rst,1'b1,1'b0,1'b0,1'b0,4'd8,1'b1,
 grant,sddata,sdv,sde,1'b0,req,addr,urgent,wav_valid,wav_left,wav_right,audio_status,peak,uf,of,eof,error,level);
// Fast SD sector transport only; slower physical SPI/fair sharing was separately
// checked by audio_arbiter_003. Each transaction is still exactly 512 WAV bytes.
always @(negedge sc)begin
 grant=0;sdv=0;sde=0;
 if(!srst)begin
  if(sd_busy==0&&req)begin
   if(addr>21)$fatal(1,"WAV sector beyond vector %0d",addr);
   sd_base=addr*512;sd_offset=0;sd_busy=1;sd_delay=10;grant=1;requests=requests+1;
  end else if(sd_busy==1)begin
   if(sd_delay>0)sd_delay=sd_delay-1;
   else if(sd_offset<512)begin sdv=1;sddata=card[sd_base+sd_offset];sd_offset=sd_offset+1;sd_delay=3;end
   else begin sde=1;sd_busy=2;sd_delay=4;end
  end else if(sd_busy==2)begin if(sd_delay>0)sd_delay=sd_delay-1;else sd_busy=0;end
 end
end
function[7:0] adjust;
 input[7:0]p;input signed[8:0]b;input[2:0]c;integer n,q;
 begin q=c==7?4:c+2;n=(p-128)*q;
 n=(n>=0?n/4:-((-n+3)/4))+128+$signed(b);
 adjust=n<0?0:n>255?255:n;
 end
endfunction
// Independent staged pixel reference: transition, adjustment, history read,
// history output, OSD, then AXIS. The history model samples actual WAV PCM.
always @(posedge clk)begin
 if(rst)begin
  for(k=0;k<6;k=k+1)begin qrgb[k]=0;qsync[k]=0;qmask[k]=1;qx[k]=-1;qy[k]=-1;qf[k]=-1;end
  hist_count=0;hist_wr=0;decimate=0;ref_scroll=0;ref_prev_vs=0;
 end else begin
  for(k=5;k>0;k=k-1)begin
   qrgb[k]=qrgb[k-1];qsync[k]=qsync[k-1];qmask[k]=qmask[k-1];
   qx[k]=qx[k-1];qy[k]=qy[k-1];qf[k]=qf[k-1];
   if(k==1)qrgb[k]=qsync[k][0]?{adjust(qrgb[k][23:16],brightness,contrast),
       adjust(qrgb[k][15:8],brightness,contrast),adjust(qrgb[k][7:0],brightness,contrast)}:0;
   if(k==2&&osd_enable&&qsync[k][0])begin
    if(qx[k]>=16&&qx[k]<528&&qy[k]>=320&&qy[k]<416)begin
     qrgb[k]=24'h0a0e14;
     if(qy[k]==320||qy[k]==415||qx[k]==16||qx[k]==527)qrgb[k]=24'h405060;
     else if(qy[k]==368)qrgb[k]=24'h263340;
     pos=(qx[k]-16)/2;
     if(hist_count==256||pos>=256-hist_count)begin
      location=hist_count==256?(hist_wr+pos)%256:pos-(256-hist_count);
      lval=hist_l[location];rval=hist_r[location];
      if(qy[k]==368-lval)qrgb[k]=24'h00ff80;
      if(qy[k]==368-rval)qrgb[k]=24'h40a0ff;
      if(qy[k]==368-lval&&qy[k]==368-rval)qrgb[k]=24'hffffff;
     end
    end else if(qx[k]>=16&&qx[k]<528&&qy[k]>=428&&qy[k]<440)begin
     bar_width=visual_peak>=32768?512:visual_peak/64;
     qrgb[k]=qx[k]-16<bar_width?24'hffaa30:24'h0a0e14;
    end else if(qx[k]>=16&&qx[k]<80&&qy[k]>=304&&qy[k]<318)begin
     qmask[k]=0;
     // Independent W top-row anchors (state is PLAY for this WAV).
     if(qy[k]==304&&(qx[k]==16||qx[k]==17||qx[k]==24||qx[k]==25))begin qmask[k]=1;qrgb[k]=24'hffffff;end
     if(qy[k]==304&&(qx[k]==18||qx[k]==19))begin qmask[k]=1;qrgb[k]=24'h0a0e14;end
    end
   end
   if(k==4&&osd_enable&&qsync[k][0])begin
    if(qy[k]>=468&&qy[k]<472&&qx[k]>=16&&qx[k]<272)qrgb[k]=qx[k]<144?24'h28dce8:24'h202020;
    if(qy[k]>=450&&qy[k]<459)begin
     qmask[k]=0;ticker_pos=(qx[k]+ref_scroll)&255;
     // First T/F have five lit top-row columns, followed by three spaces.
     if(qy[k]==450&&qx[k]<8&&ticker_pos<16)begin
      qmask[k]=1;qrgb[k]=ticker_pos%8<5?24'h28dce8:24'h101820;
     end
    end
    if(qx[k]>=16&&qx[k]<392&&qy[k]>=40&&qy[k]<49)begin
     qmask[k]=0;
     if(qy[k]==40&&qx[k]==16)begin qmask[k]=1;qrgb[k]=24'hffffff;end
     if(qy[k]==40&&qx[k]==20)begin qmask[k]=1;qrgb[k]=24'h101820;end
    end
    if(qx[k]>=16&&qx[k]<208&&qy[k]>=16&&qy[k]<32)begin
     qmask[k]=0;
     if(qy[k]==16&&(qx[k]==16||qx[k]==17||qx[k]==24||qx[k]==25))begin qmask[k]=1;qrgb[k]=24'hffffff;end
     if(qy[k]==16&&(qx[k]==18||qx[k]==19||qx[k]==26||qx[k]==27))begin qmask[k]=1;qrgb[k]=24'h101820;end
     // H row2 differs from X: catches a truncated board-name first character.
     if(qy[k]==20&&(qx[k]==16||qx[k]==17))begin qmask[k]=1;qrgb[k]=24'hffffff;end
     if(qy[k]==20&&(qx[k]==18||qx[k]==19))begin qmask[k]=1;qrgb[k]=24'h101820;end
    end
   end
  end
  if(qsync[4][1]&&!ref_prev_vs)ref_scroll=(ref_scroll+1)&255;
  ref_prev_vs=qsync[4][1];
  qrgb[0]=rgb;qsync[0]={hs,vs,de};qmask[0]=1;qx[0]=x;qy[0]=y;qf[0]=f;
  // Update after reference RAM read, matching synchronous read-before-write.
  if(audio_valid)begin
   if(decimate==63)begin
    hist_l[hist_wr]=$signed(left)>>>18;hist_r[hist_wr]=$signed(right)>>>18;
    hist_wr=(hist_wr+1)%256;if(hist_count<256)hist_count=hist_count+1;
   end
   decimate=(decimate+1)%64;
   if(wav_selected&&(left!=0||right!=0))begin
    if($signed(left)!=(-30000+(pcm_frames%600)*97)*256)$fatal(1,"PCM L frame %0d",pcm_frames);
    if($signed(right)!=(25000-(pcm_frames%500)*83)*256)$fatal(1,"PCM R frame %0d",pcm_frames);
    pcm_frames=pcm_frames+1;
   end
  end
  #1;
  if({th,tv,td,trgb}!=={qsync[0],qrgb[0]})$fatal(1,"transition pipeline mismatch");
  if({oh,ov,od}!==qsync[4])$fatal(1,"5-register sync mismatch f%0d x%0d y%0d",qf[4],qx[4],qy[4]);
  if(qmask[4]&&out!==qrgb[4])$fatal(1,"video mismatch f%0d x%0d y%0d got%h exp%h",qf[4],qx[4],qy[4],out,qrgb[4]);
  if({av,user,last}!=={qsync[5][0],qsync[5][0]&&qx[5]==0&&qy[5]==0,qsync[5][0]&&qx[5]==639})$fatal(1,"AXIS SOF/EOL/valid misalignment f%0d x%0d y%0d",qf[5],qx[5],qy[5]);
  if(qmask[5]&&axis_data!==qrgb[5])$fatal(1,"AXIS RGB mismatch");
  if(av)begin
   pixels=pixels+1;
   if(qf[5]==1)begin
    $fwrite(handle,"%0d %0d %0d\n",axis_data[23:16],axis_data[15:8],axis_data[7:0]);render_pixels=render_pixels+1;
    if(qy[5]>=320&&qy[5]<416&&qx[5]>=16&&qx[5]<528&&(axis_data==24'h00ff80||axis_data==24'h40a0ff))wave_checks=wave_checks+1;
    if(qy[5]>=428&&qy[5]<440&&axis_data==24'hffaa30)peak_checks=peak_checks+1;
   end
  end
  if(user)sof_count=sof_count+1;if(last)eol_count=eol_count+1;
  if(acr_valid)begin
   acr_packets=acr_packets+1;
   if(acr_packets>1&&(acr_cts!=25000||acr_n!=6144))$fatal(1,"shared cadence ACR CTS/N %0d/%0d",acr_cts,acr_n);
  end
  checks=checks+1;
 end
end
task tick;begin @(posedge clk);#2;@(negedge clk);end endtask
initial begin
 $readmemh("tests/audio_arbiter_card.hex",card);
 repeat(10)tick;rst=0;srst=0;
 cfg={4'd1,1'b0,1'b0,1'b0,8'd128,4'd8,2'd0,2'd0,1'b0,8'd10,contrast,brightness,3'd0};
 // Real 10ms pre-run: audio/video clocks and 48k PCM cadence are unchanged.
 repeat(250000)tick;
 if(hist_count<7||pcm_frames<450||uf||of||error)$fatal(1,"WAV preload/history not valid");
 handle=$fopen("video_audio_integration_mux_final.ppm.out","w");$fwrite(handle,"P3\n640 480\n255\n");
 for(f=0;f<2;f=f+1)begin
  if(f==0)begin brightness=40;contrast=2;osd_enable=0;end
  else begin brightness=-1;contrast=0;osd_enable=1;end
  cfg={4'd3,1'b0,1'b0,1'b0,8'd128,4'd8,2'd0,2'd0,osd_enable,8'd10,contrast,brightness,3'd0};
  // Only commit configuration while DE is low and every old packet has drained.
  x=-1;y=-1;de=0;rgb=0;hs=0;vs=1;repeat(10)tick;vs=0;repeat(10)tick;
  for(v=0;v<525;v=v+1)begin
   for(h=0;h<800;h=h+1)begin
    x=h;y=v;de=(h<640)&&(v<480);hs=(h>=656)&&(h<752);vs=(v>=490)&&(v<492);
    rgb={h[7:0],v[7:0],(h[7:0]^v[7:0]^(f?8'h49:8'h00))};tick;
   end
  end
  x=-1;y=-1;de=0;vs=0;hs=0;rgb=0;repeat(10)tick;
 end
 $fclose(handle);
 if(pixels!=614400||sof_count!=2||eol_count!=960||render_pixels!=307200)$fatal(1,"frame totals %0d %0d %0d render%0d",pixels,sof_count,eol_count,render_pixels);
 if(wave_checks<20||peak_checks<1000||acr_packets<40||uf||of||error||busy)$fatal(1,"wave/peak/audio metrics %0d %0d flags %0d%0d%0d",wave_checks,peak_checks,uf,of,error);
 $display("TEST_PASS video+audio subsystem: unified tone-valid/held WAV actual output; real WAV PCM frames=%0d; checks=%0d; full VGA frames=2; pixels=%0d SOF=%0d EOL=%0d; 5-stage RGB/sync + AXIS; off brightness math and frame change; waveform trace pixels=%0d peakbar pixels=%0d; ACR CTS25000/N6144 packets=%0d; actual RTL PPM render 640x480",pcm_frames,checks,pixels,sof_count,eol_count,wave_checks,peak_checks,acr_packets);$finish;
end
initial begin #50000000;$fatal(1,"subsystem simulation timeout");end
endmodule
