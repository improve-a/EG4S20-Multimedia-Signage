`timescale 1ns/1ps
module audio_media_tb #(parameter FAULT=0,MONO=0,REQUEST_PAUSE=0,SHORT=0,BOUNDARY=0);
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
// At the exact decision edge, the timing pipeline must match the stable LBA.
// Includes full scan-limit exhaustion and cross-sector RIFF header cases.
integer scan_compare_checks=0;
always @(posedge sys_clk)if(!rst&&dut.state==3)begin
 if(dut.scan_current_below_limit !== (dut.current_sector<dut.SCAN_MAX_SECTOR))
  $fatal(1,"stale scan limit comparison LBA%0d",dut.current_sector);
 scan_compare_checks=scan_compare_checks+1;
end
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
always @(negedge audio_clk)begin
 cycles=cycles+1;
 if(audio_valid)begin
  if(previous_tick!=0&&cycles-previous_tick!=520&&cycles-previous_tick!=521)$fatal(1,"48k cadence spacing %0d",cycles-previous_tick);
  previous_tick=cycles;ticks=ticks+1;
  if(audio_left!=0||audio_right!=0)begin
   if($signed(audio_left)!=( (-30000+frames*97)*256))$fatal(1,"left frame %0d value %0d",frames,$signed(audio_left));
   if($signed(audio_right)!=( (MONO?-30000+frames*97:25000-frames*83)*256))$fatal(1,"right frame %0d value %0d",frames,$signed(audio_right));
   frames=frames+1;
  end
 end
end
initial begin
 if(BOUNDARY)$readmemh("tests/audio_card_boundary.hex",card);
 else if(SHORT)$readmemh("tests/audio_card_short.hex",card);
 else if(MONO)$readmemh("tests/audio_card_mono.hex",card);
 else $readmemh("tests/audio_card.hex",card);
 if(FAULT==1)for(base=0;base<3072;base=base+1)card[base]=0;
 repeat(10)@(negedge sys_clk);rst=0;audio_rst=0;enable=1;sd_ready=1;
 if(REQUEST_PAUSE)begin
  wait(dut.state==5);repeat(10)@(negedge sys_clk);paused=1;
  repeat(50)@(negedge sys_clk);
  if(!sector_req)$fatal(1,"pause withdrew pending request");
  paused=0;
 end
 if(FAULT!=0)begin
  wait(error);repeat(10)@(negedge audio_clk);
  if(dut.fault_sync!=(FAULT==1?11:FAULT==2?15:13))$fatal(1,"fault cause %0d",dut.fault_sync);
  if(frames!=0||underflow||overflow||eof)$fatal(1,"fault emitted or consumed PCM");
  $display("TEST_PASS audio media fault mode %0d: no WAV / truncated sector / SD error fail closed",FAULT);$finish;
 end
 wait(eof);repeat(10)@(negedge audio_clk);
 if(frames!=(SHORT?1:MONO?100:300)||underflow||overflow||error||fifo_level!=0)$fatal(1,"media frames=%0d UF=%0d OF=%0d error=%0d level=%0d",frames,underflow,overflow,error,fifo_level);
 if(requests!=(MONO?4:8))$fatal(1,"scan/replay sector count %0d",requests);
 $display("TEST_PASS TF WAV sector stream: scanned LBA0/1, RIFF LBA2, header across sectors, reread contiguous file, PCM frames, FIFO prefill, 48k cadence, clean EOF. requests=%0d peak=%0d",requests,wave_peak);$finish;
end
initial begin #15000000;$fatal(1,"timeout status=%0d state=%0d frames=%0d",status,dut.state,frames);end
endmodule
