`timescale 1ns/1ps
module no_bot_actual_top_tb #(parameter EOF_CASE=0,PCM_SAMPLES=4096);
reg clk=0,rst_n=0;always#10 clk=~clk;
wire[5:0]seg_sel;wire[7:0]seg_data;wire hc,h0,h1,h2,ddc,cs,sclk,mosi;tri sda;
top dut(.clk(clk),.rst_n(rst_n),.key1(1'b1),.key2(1'b1),.key3(1'b1),.seg_sel(seg_sel),.seg_data(seg_data),.HDMI_CLK_P(hc),.HDMI_D0_P(h0),.HDMI_D1_P(h1),.HDMI_D2_P(h2),.HDMI_DDC_SCL(ddc),.HDMI_DDC_SDA(sda),.sd_ncs(cs),.sd_dclk(sclk),.sd_mosi(mosi),.sd_miso(1'b1));
reg[23:0]gold[0:307199];reg[15:0]pcm[0:PCM_SAMPLES-1];
integer read_checks=0;
integer i,syscycle=0,vc=0,writes=0,write_finishes=0,commits=0,restarts=0,eofs=0,player_index=0,pcm_checked=0,pcm_loops=0,hdmi_audio=0,hdmi_wav_nonzero=0,acr_count=0,last_audio_cycle=0,delta=0;
integer axis_pixels=0,axis_lines=0,axis_sofs=0,axis_lasts=0,linepx=0,px=0,py=0,qualified_frames=0,captured_pixels=0,sourcepixels=0,fd=0,rawx=0,rawy=0,last_sof=0,frame_front=0;
reg previous_axis=0,previous_vs=0,previous_raw_de=0,previous_raw_vs=0,previous_commit=0,previous_restart=0,previous_eof=0,seen_axis_sof=0,capture=0,have_frame=0;reg[3:0]oldstate=15;reg[2:0]oldphase=7;reg old_display=0;
wire av=dut.u_hdmi_1_4b_transmitter_core_wrapper.I_axis_s_valid;
wire au=dut.u_hdmi_1_4b_transmitter_core_wrapper.I_axis_s_user;
wire al=dut.u_hdmi_1_4b_transmitter_core_wrapper.I_axis_s_last;
wire[23:0]ad=dut.u_hdmi_1_4b_transmitter_core_wrapper.I_axis_s_data;
wire hav=dut.u_hdmi_1_4b_transmitter_core_wrapper.I_audio_valid;
wire[23:0]hal=dut.u_hdmi_1_4b_transmitter_core_wrapper.I_audio_left_data;
wire[23:0]har=dut.u_hdmi_1_4b_transmitter_core_wrapper.I_audio_right_data;
initial begin $readmemh("gold_image.hex",gold);$readmemh("real_pcm.hex",pcm);repeat(10)@(negedge clk);rst_n=1;end
always@(negedge dut.rst_all)begin $display("ACTUAL_RESET_RELEASE time%0t cnt%0d",$time,dut.rst_cnt);$fflush();end
always@(posedge dut.sd_card_clk)if(!dut.sd_rst)begin
 syscycle=syscycle+1;
 if(dut.state_code!==oldstate)begin $display("ACTUAL_MEDIA_STATE code%0h internal%0d found%0d catalog%0d loaderr%0d time%0t",dut.state_code,dut.sd_card_bmp_m0.state,dut.sd_card_bmp_m0.found_count,dut.sd_card_bmp_m0.catalog_ready,dut.sd_card_bmp_m0.loader_error,$time);$fflush();oldstate=dut.state_code;end
 if(dut.wav_restart&&!previous_restart)begin restarts=restarts+1;$display("ACTUAL_TOP_WAV_RESTART %0d eofsync%b PCMloops%0d PCMchecked%0d time%0t",restarts,dut.wav_eof_sync,pcm_loops,pcm_checked,$time);$fflush();end previous_restart=dut.wav_restart;
 if(dut.display_valid&&!old_display)begin $display("ACTUAL_DISPLAY_VALID candidate%h active%h writes%0d time%0t",dut.candidate_view,dut.active_view,writes,$time);$fflush();end old_display=dut.display_valid;
 if(dut.sd_card_bmp_m0.state==6)$fatal(1,"actualmediacontrollerFAILEDcode%h",dut.state_code);
 if(syscycle%1000000==0)begin $display("TOP_PROGRESS ms%0d state%h phase%0d writes%0d reads%0d sectors%0d WAVstate%0d WAVLBA%0d WAVstatus%0h frames%0d PCM%0d restart%0d time%0t",syscycle/100000,dut.state_code,dut.transition.phase,writes,dut.U3.reads,dut.sd_card_bmp_m0.sd_card_top_m0.sectors,dut.wav.state,dut.wav.current_sector,dut.wav_status,qualified_frames,pcm_checked,restarts,$time);$fflush();end
end
always@(posedge dut.ext_mem_clk)if(!dut.mem_rst)begin
 if(dut.App_wr_en)begin
  if(dut.App_wr_addr!==((479-writes/640)*640+writes%640))$fatal(1,"actualwriteorder%0d addr%0d",writes,dut.App_wr_addr);
  if(dut.App_wr_din!=={gold[dut.App_wr_addr],8'd0})$fatal(1,"actualBMPtoSDRAMword%0d addr%0d got%h expected%h",writes,dut.App_wr_addr,dut.App_wr_din,{gold[dut.App_wr_addr],8'd0});writes=writes+1;
 end
 if(dut.frame_write_finish)begin write_finishes=write_finishes+1;if(writes!=307200)$fatal(1,"actualwritefinishearly%0d",writes);$display("ACTUAL_WRITE_FINISH words%0d time%0t",writes,$time);$fflush();end
 if(dut.App_rd_en)begin if(dut.App_rd_addr!==dut.active_view[1:0]*307200+read_checks%307200)$fatal(1,"actualacceptedreadsequence addr%0d count%0d",dut.App_rd_addr,read_checks);read_checks=read_checks+1;end
 if(dut.fifo_fault)$fatal(1,"actualFIFOfault state%h reads%0d writes%0d",dut.state_code,dut.U3.reads,writes);
end
always@(posedge dut.video_clk)begin
 if(dut.video_rst)begin previous_axis=0;previous_vs=0;previous_raw_de=0;previous_raw_vs=0;previous_commit=0;end
 else begin
  vc=vc+1;
  if(dut.vs&&!previous_raw_vs)begin rawx=0;rawy=0;end previous_raw_vs=dut.vs;
  if(dut.de&&dut.display_valid_sync[1])begin
   if(dut.vout_data_raw!==gold[rawy*640+rawx])$fatal(1,"actualFIFOvideo_delayRGB x%0d y%0d got%h expected%h",rawx,rawy,dut.vout_data_raw,gold[rawy*640+rawx]);sourcepixels=sourcepixels+1;if(rawx==639)rawx=0;else rawx=rawx+1;
  end
  if(previous_raw_de&&!dut.de)rawy=rawy+1;previous_raw_de=dut.de;
  if(dut.commit_ack_toggle!=previous_commit)begin commits=commits+1;$display("ACTUAL_COMMIT_ACK %0d active%h writes%0d time%0t",commits,dut.active_view,writes,$time);$fflush();end previous_commit=dut.commit_ack_toggle;
  if(dut.transition.phase!=oldphase)begin $display("ACTUAL_TRANSITION phase%0d offset%0d revealarmed%0d time%0t",dut.transition.phase,dut.transition.offset,dut.transition.reveal_armed,$time);$fflush();oldphase=dut.transition.phase;end
  // Observe the actual HDMI input, not a substitute video source.
  if((au||al)&&!av)$fatal(1,"HDMIinputSOForTLASTwithoutvalid");
  if(av)begin
   if(^ad===1'bx)$fatal(1,"HDMIunknownRGB");
   if(au)begin
    if(seen_axis_sof)begin if(axis_pixels!=307200||axis_lines!=480||axis_lasts!=480||vc-last_sof!=420000)$fatal(1,"HDMIframecontract P%0d L%0d LAST%0d delta%0d",axis_pixels,axis_lines,axis_lasts,vc-last_sof);end
    seen_axis_sof=1;axis_sofs=axis_sofs+1;last_sof=vc;axis_pixels=0;axis_lines=0;axis_lasts=0;px=0;py=0;
    capture=dut.display_valid_sync[1]&&!dut.transition_busy&&!have_frame;frame_front=dut.active_view[1:0];
    if(capture)begin if(writes!=307200||commits==0||dut.active_view[7:6]!=1)$fatal(1,"visiblebeforeactualloadcommit/default2x");fd=$fopen("actual_hdmi_input.ppm","wb");if(!fd)$fatal(1,"captureopen");$fwrite(fd,"P6\n640 480\n255\n");captured_pixels=0;$display("ACTUAL_CAPTURE_START active%h config%h time%0t",dut.active_view,dut.display_config,$time);$fflush();end
   end
   if(!previous_axis)linepx=0;
   if(al!==(linepx==639))$fatal(1,"HDMIinputTLASTx%0d",linepx);
   if(seen_axis_sof)begin if((axis_pixels==0)!==au)$fatal(1,"HDMIinputSOFposition");axis_pixels=axis_pixels+1;if(al)begin axis_lines=axis_lines+1;axis_lasts=axis_lasts+1;end end
   if(capture)begin
    if(dut.active_view[1:0]!=frame_front)$fatal(1,"frontchangedinsideactualcapturedframe");
    if(!(px>=500&&py<105)&&!(px>=24&&px<510&&py>=386&&py<466))begin if(ad!==gold[py*640+px])$fatal(1,"actualHDMIimage x%0d y%0d got%h expected%h",px,py,ad,gold[py*640+px]);end
    $fwrite(fd,"%c%c%c",ad[23:16],ad[15:8],ad[7:0]);captured_pixels=captured_pixels+1;
    if(captured_pixels==307200)begin $fclose(fd);capture=0;have_frame=1;qualified_frames=qualified_frames+1;$display("ACTUAL_HDMI_IMAGE_FRAME_PASS pixels307200 baseRGBexact active%h time%0t",dut.active_view,$time);$fflush();end
   end
   if(px==639)begin px=0;py=py+1;end else px=px+1;linepx=linepx+1;
  end else if(previous_axis&&linepx!=640)$fatal(1,"HDMIlinewidth%0d",linepx);
  previous_axis=av;
  if(hav)begin
   if(last_audio_cycle!=0)begin delta=vc-last_audio_cycle;if(delta!=520&&delta!=521)$fatal(1,"HDMIaudio48kcadence%0d",delta);end last_audio_cycle=vc;hdmi_audio=hdmi_audio+1;
   if(^hal===1'bx||^har===1'bx)$fatal(1,"HDMIunknownaudio");
   if(dut.wav_selected&&hal!=0)hdmi_wav_nonzero=hdmi_wav_nonzero+1;
  end
  if(dut.u_hdmi_1_4b_transmitter_core_wrapper.I_acr_valid)begin
   if(dut.u_hdmi_1_4b_transmitter_core_wrapper.I_acr_n!=6144||dut.u_hdmi_1_4b_transmitter_core_wrapper.I_acr_cts<24999||dut.u_hdmi_1_4b_transmitter_core_wrapper.I_acr_cts>25004)$fatal(1,"HDMIACR N%0d CTS%0d",dut.acr_n,dut.acr_cts);acr_count=acr_count+1;
  end
  if(dut.wav_eof&&!previous_eof)begin eofs=eofs+1;$display("ACTUAL_PLAYER_EOF %0d PCMindex%0d checked%0d time%0t",eofs,player_index,pcm_checked,$time);$fflush();end previous_eof=dut.wav_eof;
  if(dut.wav_underflow||dut.wav_overflow||dut.wav_error)$fatal(1,"actualaudiofault status%h underflow%b overflow%b err%b",dut.wav_status,dut.wav_underflow,dut.wav_overflow,dut.wav_error);
  #1;
  if(dut.wav.player_rst)player_index=0;
  else if(dut.wav.player.audio_valid&&!dut.wav.player.pending_zero)begin
   if(player_index>=PCM_SAMPLES)$fatal(1,"unexpectedPCMlength%0d",player_index);
   if(dut.wav.player.audio_left!=={pcm[player_index],8'd0}||dut.wav.player.audio_right!=={pcm[player_index],8'd0})$fatal(1,"actualWAVplayerPCM idx%0d got%h expected%h",player_index,dut.wav.player.audio_left,{pcm[player_index],8'd0});
   player_index=player_index+1;pcm_checked=pcm_checked+1;
   if(player_index==PCM_SAMPLES)begin pcm_loops=pcm_loops+1;$display("ACTUAL_PCM_COMPLETE loop%0d samples%0d time%0t",pcm_loops,PCM_SAMPLES,$time);$fflush();end
  end
  if(have_frame&&hdmi_wav_nonzero>0&&acr_count>0&&((!EOF_CASE&&pcm_checked>=64)||(EOF_CASE&&pcm_loops>=2&&restarts>=2)))begin
   $display("TEST_PASS ACTUAL_TOP case%0d visibleframes%0d writes%0d writefinishes%0d commits%0d sourceSDsectors%0d reads%0d responses%0d HDMIaudio%0d HDMIWAVnonzero%0d actualPCMchecked%0d PCMloops%0d EOF%0d TOPautomaticrestart%0d ACR%0d actualgeneratedFIFO fault0; leafcard/SDRAM/PLL/HDMImodels physicalIPnotqualified",EOF_CASE,qualified_frames,writes,write_finishes,commits,dut.sd_card_bmp_m0.sd_card_top_m0.sectors,dut.U3.reads,dut.U3.responses,hdmi_audio,hdmi_wav_nonzero,pcm_checked,pcm_loops,eofs,restarts,acr_count);$fflush();$finish;
  end
 end
end
initial begin#600000000;$fatal(1,"actualtopwatchdog");end
endmodule
