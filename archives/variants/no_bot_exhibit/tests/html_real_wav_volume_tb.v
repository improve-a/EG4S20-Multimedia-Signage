`timescale 1ns/1ps
module html_real_wav_volume_tb #(parameter FAULT=0,MONO=0,REQUEST_PAUSE=0,SHORT=0,BOUNDARY=0);
reg sys_clk=0,audio_clk=0;always #5 sys_clk=~sys_clk;always #20 audio_clk=~audio_clk;
reg rst=1,audio_rst=1,enable=0,paused=0,muted=0,restart=0;
reg[3:0] volume=8;reg sd_ready=0,sector_grant=0,sector_valid=0,sector_end=0,sector_error=0;
reg[7:0] sector_data;wire sector_req,sector_urgent;wire[31:0]sector_addr;
wire audio_valid;wire[23:0]audio_left,audio_right;wire[3:0]status;wire[15:0]wave_peak;
wire underflow,overflow,eof,error;wire[9:0]fifo_level;
reg[7:0]card[0:3071];integer base=0,offset=0,delay_count=0,busy=0,frames=0,requests=0,ticks=0;
reg[31:0]previous_tick=0;integer cycles=0;
audio_media #(.FIFO_ADDRESS_BITS(9),.PREFILL_FRAMES(128),.SCAN_MAX_SECTOR(5)) dut(
 sys_clk,rst,audio_clk,audio_rst,enable,paused,muted,restart,volume,sd_ready,sector_grant,
 sector_data,sector_valid,sector_end,sector_error,sector_req,sector_addr,sector_urgent,
 audio_valid,audio_left,audio_right,status,wave_peak,underflow,overflow,eof,error,fifo_level);
// Sector transport model supplies actual bytes with gaps, 512B per transaction.
always @(negedge sys_clk)begin
 sector_grant=0;sector_valid=0;sector_end=0;sector_error=0;
 if(busy==0&&sector_req)begin
  if(sector_addr>5)$fatal(1,"outside card LBA %0d",sector_addr);
  base=sector_addr*512;offset=0;busy=REQUEST_PAUSE?3:1;delay_count=REQUEST_PAUSE?200:5;sector_grant=REQUEST_PAUSE?0:1;requests=requests+1;
 end else if(busy==3)begin
  if(!sector_req||sector_addr*512!=base)$fatal(1,"pending sector request withdrawn or address changed");
  if(delay_count>0)delay_count=delay_count-1;else begin sector_grant=1;busy=1;delay_count=5;end
 end else if(busy==1)begin
  if(delay_count>0)delay_count=delay_count-1;
  else if(FAULT==3&&offset==20)begin sector_error=1;busy=2;delay_count=4;end
  else if(offset<(FAULT==2?511:512))begin
   sector_valid=1;sector_data=card[base+offset];offset=offset+1;delay_count=4;
   if(BOUNDARY&&offset==512)begin sector_end=1;busy=2;delay_count=4;end
  end
  else begin sector_end=1;busy=2;delay_count=4;end
 end else if(busy==2)begin if(delay_count>0)delay_count=delay_count-1;else busy=0;end
end

reg[31:0]pcm[0:299];reg[23:0]expect_left[0:299],expect_right[0:299];integer popped=0,received=0,lv,rv,gain;
always @(posedge audio_clk)if(!audio_rst&&dut.fifo_pop)begin
 if(popped>=300)$fatal(1,"real WAV over-consumed");
 gain=volume>8?8:volume;
 lv=($signed(pcm[popped][31:16])*gain)>>>3;rv=($signed(pcm[popped][15:0])*gain)>>>3;
 expect_left[popped]=muted?0:lv*256;expect_right[popped]=muted?0:rv*256;popped=popped+1;
end
always @(negedge audio_clk)if(!audio_rst&&audio_valid)begin
 if(received<popped)begin
  if(audio_left!==expect_left[received]||audio_right!==expect_right[received])$fatal(1,"real WAV gain/mute frame%0d got%x/%x expected%x/%x",received,audio_left,audio_right,expect_left[received],expect_right[received]);
  received=received+1;
  case(received)50:volume=4;100:volume=1;150:volume=15;200:muted=1;250:begin muted=0;volume=0;end 275:volume=8;endcase
 end else if(audio_left!==0||audio_right!==0)$fatal(1,"nonzero outside actual WAV frames");
end
initial begin
 $readmemh("tests/audio_card.hex",card);$readmemh("tests/html_real_wav_pcm.hex",pcm);
 repeat(10)@(negedge sys_clk);rst=0;audio_rst=0;enable=1;sd_ready=1;
 wait(eof);repeat(10)@(negedge audio_clk);
 if(received!=300||popped!=300||underflow||overflow||error||fifo_level!=0)$fatal(1,"real WAV EOF/flow received%0d popped%0d UF%0d OF%0d err%0d level%0d",received,popped,underflow,overflow,error,fifo_level);
 $display("TEST_PASS REAL_WAV_VOLUME actual300PCMframes gain8/4/1/15clamp, mute50framesdrains, gain0, gain8resume, cleanEOF");$finish;
end
initial begin #15000000;$fatal(1,"real WAV volume timeout");end
endmodule
