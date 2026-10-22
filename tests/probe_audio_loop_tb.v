`timescale 1ns/1ps
// Real 07_MUSIC.WAV bytes through audio_media -> parser -> FIFO -> 48kHz player.
// The playback cadence is accelerated 130x (one PCM frame every 4 audio clocks
// instead of 520/521 at 25MHz) while sample order, data length, FIFO and control
// behaviour are unchanged; the 4:1 sys/audio clock ratio matches 100:25MHz.
// The sector model is deliberately slower, relative to playback, than the card
// (~0.55 -> 1 sys_clk per byte), so the FIFO margin here is no better than real.
// LOOP_MODE=1 exercises the retained-FIFO EOF loop; LOOP_MODE=0 exercises the
// legacy eof -> external restart (rescan) path for the stall comparison.
module probe_audio_loop_tb #(
 parameter LOOP_MODE=1,
 parameter LBA=64,
 parameter CARD_BYTES=1572864
);
 localparam integer FILE_BYTES=1536044;
 localparam integer SAMPLES=768000;
 localparam integer O=LBA*512;
 localparam integer DATA=44;
 reg sys_clk=0,audio_clk=0;
 always #5 sys_clk=~sys_clk;      // 4 sys clocks per audio clock
 always #20 audio_clk=~audio_clk;
 reg rst=1,audio_rst=1,enable=0,paused=0,muted=0,restart=0;
 reg [3:0] volume=8;
 reg sd_ready=0,sector_grant=0,sector_valid=0,sector_end=0,sector_error=0;
 reg [7:0] sector_data;
 wire sector_req,sector_urgent;
 wire [31:0] sector_addr;
 wire audio_valid;
 wire [23:0] audio_left,audio_right;
 wire [3:0] status;
 wire [15:0] wave_peak;
 wire underflow,overflow,eof,error;
 wire [11:0] fifo_level;
 // LOOP_MODE=2 instantiates audio_media with no LOOP_PLAY override at all, so it
 // proves the production default (1) loops without any frozen-top parameter.
 generate
  if(LOOP_MODE==2)begin : g
   audio_media #(.SYS_CLK_HZ(768000),.AUDIO_CLK_HZ(192000)) dut(
    sys_clk,rst,audio_clk,audio_rst,enable,paused,muted,restart,volume,sd_ready,sector_grant,
    sector_data,sector_valid,sector_end,sector_error,sector_req,sector_addr,sector_urgent,
    audio_valid,audio_left,audio_right,status,wave_peak,underflow,overflow,eof,error,fifo_level);
  end else begin : g
   audio_media #(.SYS_CLK_HZ(768000),.AUDIO_CLK_HZ(192000),.LOOP_PLAY(LOOP_MODE)) dut(
    sys_clk,rst,audio_clk,audio_rst,enable,paused,muted,restart,volume,sd_ready,sector_grant,
    sector_data,sector_valid,sector_end,sector_error,sector_req,sector_addr,sector_urgent,
    audio_valid,audio_left,audio_right,status,wave_peak,underflow,overflow,eof,error,fifo_level);
  end
 endgenerate
 wire playing_w=g.dut.playing;
 wire pop_w=g.dut.fifo_pop;
 wire starved_w=g.dut.player.pending_zero;
 wire mute_latched_w=g.dut.player.pending_mute;
 wire [3:0] state_w=g.dut.state;

 // ---- card image: the real WAV file at LBA, zeros elsewhere --------------
 reg [7:0] card[0:CARD_BYTES-1];
 integer fd,got,i;
 reg [8*512-1:0] wav_path;
 initial begin
  if(!$value$plusargs("wav=%s",wav_path))$fatal(1,"+wav=<07_MUSIC.WAV> is required");
  for(i=0;i<CARD_BYTES;i=i+1)card[i]=0;
  fd=$fopen(wav_path,"rb");
  if(fd==0)$fatal(1,"cannot open %0s",wav_path);
  got=$fread(card,fd,O,FILE_BYTES);
  $fclose(fd);
  if(got!=FILE_BYTES)$fatal(1,"WAV read %0d bytes, expected %0d",got,FILE_BYTES);
  if({card[O+0],card[O+1],card[O+2],card[O+3]}!=="RIFF")$fatal(1,"no RIFF at LBA%0d",LBA);
  if({card[O+8],card[O+9],card[O+10],card[O+11]}!=="WAVE")$fatal(1,"no WAVE id");
  if({card[O+36],card[O+37],card[O+38],card[O+39]}!=="data")$fatal(1,"no data chunk");
  if({card[O+43],card[O+42],card[O+41],card[O+40]}!==SAMPLES*2)
   $fatal(1,"data length %0d, expected %0d",{card[O+43],card[O+42],card[O+41],card[O+40]},SAMPLES*2);
  if({card[O+21],card[O+20]}!==16'd1||{card[O+23],card[O+22]}!=16'd1)
   $fatal(1,"format is not mono PCM");
  if({card[O+35],card[O+34]}!==16'd16)$fatal(1,"not 16 bit");
  if({card[O+27],card[O+26],card[O+25],card[O+24]}!==32'd48000)$fatal(1,"rate is not 48000");
  $display("WAV_OK bytes=%0d samples=%0d data_offset=%0d",FILE_BYTES,SAMPLES,DATA);
 end

 // ---- sector transport model -------------------------------------------
 integer base=0,offset=0,delay_count=0,busy=0;
 integer requests=0,scan_requests=0,play_requests=0,post_play_below_lba=0;
 reg play_seen=0;
 always @(negedge sys_clk)begin
  sector_grant=0;sector_valid=0;sector_end=0;sector_error=0;
  if(playing_w)play_seen<=1;
  if(busy==0&&sector_req)begin
   base=sector_addr*512;offset=0;busy=1;delay_count=1;sector_grant=1;
   requests=requests+1;
   if(play_seen)begin
    play_requests=play_requests+1;
    if(sector_addr<LBA)post_play_below_lba=post_play_below_lba+1;
   end else scan_requests=scan_requests+1;
  end else if(busy==1)begin
   if(delay_count>0)delay_count=delay_count-1;
   else if(offset<512)begin
    sector_valid=1;sector_data=card[base+offset];offset=offset+1;
   end else begin sector_end=1;busy=2;delay_count=8;end
  end else if(busy==2)begin
   if(delay_count>0)delay_count=delay_count-1;else busy=0;
  end
 end

 // ---- legacy eof -> restart, exactly as the frozen top drives it ---------
 (* async_reg="true" *) reg [2:0] eof_sync=0;
 always @(posedge sys_clk)eof_sync<={eof_sync[1:0],eof};
 always @(eof_sync) restart = (LOOP_MODE==0)&&eof_sync[1]&&!eof_sync[2];

 // ---- stream checker ----------------------------------------------------
 integer idx=0,checked=0,gaps=0,loops=0,restarts=0,after_restart=0;
 integer min_level=4095,max_level=0,peak_max=0,peak_min=65535,eof_pulses=0;
 integer mute_done=0,stalled=0,post_mute=0;
 reg started=0,verified=0,smoke=0;
 reg [15:0] want_left,want_right;
 always @(posedge audio_clk)begin
  if(pop_w)started<=1;
  if(eof)eof_pulses=eof_pulses+1;
  if(started&&playing_w&&fifo_level<min_level)min_level=fifo_level;
  if(started&&fifo_level>max_level)max_level=fifo_level;
  if(wave_peak>peak_max)peak_max=wave_peak;
  if(wave_peak<peak_min)peak_min=wave_peak;
  if(started&&audio_valid)begin
   want_left={card[O+DATA+2*(idx%SAMPLES)+1],card[O+DATA+2*(idx%SAMPLES)]};
   want_right=want_left;
   if(starved_w)begin
    // FIFO starved: the player can only emit silence for this 48kHz frame.
    gaps=gaps+1;stalled=1;
   end else begin
    if(stalled)begin
     if(LOOP_MODE!=0)$fatal(1,"loop mode starved at %0d frames",idx);
     // Legacy restart: the rescan must restart exactly at the file beginning.
     if($signed(audio_left)!==$signed(want_left)*256)
      $fatal(1,"restart does not resume at the file start: got%0d",$signed(audio_left));
     idx=0;loops=0;stalled=0;restarts=restarts+1;
    end
    if(mute_latched_w)begin
     if(audio_left!==0||audio_right!==0)$fatal(1,"muted frame not silent at %0d",idx);
    end else begin
     if($signed(audio_left)!==$signed(want_left)*256)
      $fatal(1,"left mismatch idx%0d got%0d want%0d",idx,$signed(audio_left),$signed(want_left)*256);
     if($signed(audio_right)!==$signed(want_right)*256)
      $fatal(1,"right mismatch idx%0d got%0d want%0d",idx,$signed(audio_right),$signed(want_right)*256);
    end
    idx=idx+1;checked=checked+1;
    if(restarts>0)after_restart=after_restart+1;
    if(idx%SAMPLES==0)loops=loops+1;
    if(post_mute>0)post_mute=post_mute+1;
    // Mute for 12000 frames (0.25s) inside the first pass: frames are consumed
    // silently and the PCM after unmute must continue at the same index.
    if(idx==96000&&mute_done==0)begin muted=1;end
    if(muted&&idx==108000)begin muted=0;mute_done=1;post_mute=1;end
   end
  end
  if(smoke&&checked>=20000)begin
   if(gaps!=0||underflow||overflow||error)$fatal(1,"smoke gaps=%0d uf=%0d of=%0d err=%0d",gaps,underflow,overflow,error);
   $display("SMOKE_PASS loop_mode=%0d frames=%0d fifo_min=%0d peak_max=%0d state=%0d status=%0d",
    LOOP_MODE,checked,min_level,peak_max,state_w,status);
   $finish;
  end
  if(!verified)begin
   if(LOOP_MODE!=0&&loops>=1&&idx>=(SAMPLES+96000))verified<=1;
   if(LOOP_MODE==0&&restarts>=1&&after_restart>=48000)verified<=1;
  end
 end

 initial begin
  repeat(10)@(negedge sys_clk);rst=0;audio_rst=0;enable=1;sd_ready=1;
  if(LOOP_MODE==2)$display("RUN_START loop_mode=2 loop_play=production_default lba=%0d",LBA);
  else if(LOOP_MODE==1)$display("RUN_START loop_mode=1 loop_play=explicit_1 lba=%0d",LBA);
  else $display("RUN_START loop_mode=0 loop_play=explicit_0_legacy lba=%0d",LBA);
  if($test$plusargs("smoke"))smoke=1;
  wait(verified);
  repeat(200)@(negedge audio_clk);
  if(mute_done!=1)$fatal(1,"mute/unmute window did not run");
  if(post_mute<48000)$fatal(1,"not enough unmuted frames after the mute window");
  if(underflow)$fatal(1,"unexpected underflow");
  if(overflow)$fatal(1,"unexpected overflow");
  if(error)$fatal(1,"unexpected fault");
  if(LOOP_MODE!=0)begin
   if(gaps!=0)$fatal(1,"loop produced %0d starved 48k frames",gaps);
   if(eof_pulses!=0)$fatal(1,"EOF asserted in loop mode");
   if(post_play_below_lba!=0)$fatal(1,"loop rescanned %0d sectors before the file",post_play_below_lba);
   if(loops<1)$fatal(1,"did not complete the repeat");
   if(peak_max!=26028)$fatal(1,"wave peak max %0d, expected 26028",peak_max);
   if(min_level<64)$fatal(1,"FIFO margin collapsed to %0d frames",min_level);
   $display("TEST_PASS probe_audio_loop loop_mode=%0d frames=%0d loops=%0d gaps=%0d fifo_min=%0d fifo_max=%0d peak=%0d..%0d requests=%0d play_requests=%0d rescan=0 mute=12000",
    LOOP_MODE,checked,loops,gaps,min_level,max_level,peak_min,peak_max,requests,play_requests);
  end else begin
   if(eof_pulses==0)$fatal(1,"legacy path never reported EOF");
   if(post_play_below_lba<LBA)$fatal(1,"legacy restart did not rescan the card");
   if(restarts<1)$fatal(1,"legacy restart did not reload the file");
   if(gaps<=0)$fatal(1,"legacy restart stall not observed");
   $display("TEST_PASS probe_audio_loop loop_mode=%0d frames=%0d loops=%0d stall_frames=%0d stall_ms=%0.2f eof_pulses=%0d rescan_sectors=%0d requests=%0d peak_max=%0d",
    LOOP_MODE,checked,loops,gaps,gaps/48.0,eof_pulses,post_play_below_lba,requests,peak_max);
  end
  $finish;
 end
 initial begin #500000000;$fatal(1,"watchdog state=%0d idx=%0d status=%0d gaps=%0d",state_w,idx,status,gaps);end
endmodule
