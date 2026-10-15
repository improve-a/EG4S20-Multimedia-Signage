`timescale 1ns/1ps
module audio_player_tb;
reg clk=0;always #20 clk=~clk;
reg rst=1,enabled=1,paused=0,muted=0,ready=1,eof=0,empty=0;
reg [3:0] volume=8;reg[31:0]data=0;wire pop,valid,underflow,drained;wire[23:0]left,right;wire[15:0]peak;
integer pops=0,old_pops,prev_cycle=0,cycles=0,ticks=0,i;
audio_pcm_player dut(clk,rst,enabled,paused,muted,ready,eof,volume,empty,data,pop,valid,left,right,underflow,drained,peak);
always @(posedge clk)if(pop)begin data<=32'h80007fff;pops=pops+1;end
always @(negedge clk)begin
 cycles=cycles+1;
 if(rst)prev_cycle=0;
 else if(valid)begin
  if(prev_cycle!=0&&cycles-prev_cycle!=520&&cycles-prev_cycle!=521)$fatal(1,"cadence spacing %0d",cycles-prev_cycle);
  prev_cycle=cycles;ticks=ticks+1;
 end
end
task check_samples;
 input integer n;input integer l,r;integer j;
 begin
  // Settle pending sample and one full cadence interval.
  repeat(2)begin @(negedge clk);while(!valid)@(negedge clk);end
  for(j=0;j<n;j=j+1)begin
   @(negedge clk);while(!valid)@(negedge clk);
   if($signed(left)!=l||$signed(right)!=r)$fatal(1,"gain/mute sample l=%0d r=%0d exp %0d %0d",$signed(left),$signed(right),l,r);
  end
 end
endtask
initial begin
 repeat(4)@(negedge clk);rst=0;
 check_samples(70,-8388608,8388352);
 if(peak!=32768)$fatal(1,"wave peak %0d",peak);
 volume=0;check_samples(10,0,0);
 volume=4;check_samples(20,-4194304,4194048);
 volume=1;check_samples(20,-1048576,1048320);
 volume=15;check_samples(20,-8388608,8388352);
 muted=1;old_pops=pops;check_samples(20,0,0);
 if(pops-old_pops<20)$fatal(1,"mute stopped consumption");
 muted=0;paused=1;old_pops=pops;check_samples(20,0,0);
 if(pops!=old_pops)$fatal(1,"pause consumed frames");
 paused=0;empty=1;check_samples(5,0,0);if(!underflow||drained)$fatal(1,"underflow missing");
 rst=1;repeat(4)@(negedge clk);rst=0;eof=1;
 check_samples(5,0,0);if(underflow||!drained)$fatal(1,"EOF misclassified as underflow");
 $display("TEST_PASS PCM player: 48k fractional cadence 520/521 cycles, signed volume/clamp, mute drains, pause holds, underflow silence, EOF distinction and 64-sample wave peak");$finish;
end
endmodule
