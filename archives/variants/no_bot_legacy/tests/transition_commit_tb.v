`timescale 1ns/1ps
module transition_commit_tb;
reg vc=0,sc=0;always #20 vc=~vc;always #5 sc=~sc;
reg rst=1,raw=0,mem_ack=0,valid_display=0;
reg [1:0] mode=0,candidate_buf=0;
reg candidate_toggle=0,hs=0,vs=0,de=0;
reg [23:0] rgb=0;
wire raw_ack,mem_req,ack,forwarded,busy,oh,ov,od;wire [1:0] active_buf;wire [23:0] out;
reg raw_prev=0;
wire frame_start=raw && !raw_prev;
always @(posedge vc)if(rst)raw_prev<=0;else raw_prev<=raw;
video_transition transition(.clk(vc),.rst(rst),.i_hs(hs),.i_vs(vs),.i_de(de),.i_rgb(rgb),.enable(valid_display),.mode(mode),.frame_start(frame_start),.candidate_toggle_async(candidate_toggle),.display_fault_async(1'b0),.commit_ack_toggle(ack),.cover_request_toggle_async(1'b0),.cover_ack_toggle(),.forwarded_commit_toggle(forwarded),.o_hs(oh),.o_vs(ov),.o_de(od),.o_rgb(out),.transition_busy(busy));
display_commit commit(vc,rst,raw,raw_ack,mem_req,mem_ack,forwarded,candidate_buf,1'b0,active_buf,ack);
// Model SDRAM read-base acceptance, with a deliberately long response delay.
reg mem_prev=0;integer delay_count=0;reg [1:0] read_buf=0;
always @(posedge vc)begin
 if(rst)begin mem_ack<=0;mem_prev<=0;delay_count<=0;read_buf<=0;end
 else begin
  mem_prev<=mem_req;
  if(mem_req && !mem_prev)begin
   read_buf<=active_buf;delay_count<=40;
  end else if(delay_count>0)begin
   delay_count<=delay_count-1;
   if(delay_count==1)mem_ack<=1;
  end
  if(!mem_req)mem_ack<=0;
 end
end
// SD owns its candidate until the actual ACK crosses back to 100 MHz. The old
// displayed buffer cannot become a writable back buffer before that crossing.
reg [1:0] ack_sync=0,sd_front=0,held_candidate=0;
reg pending=0;integer swaps=0;
always @(posedge sc)begin
 if(rst)begin ack_sync<=0;sd_front<=0;pending<=0;swaps<=0;end
 else begin
  ack_sync<={ack_sync[0],ack};
  if(pending)begin
   if(candidate_buf!==held_candidate)$fatal(1,"SD candidate changed before ACK");
   if(candidate_buf==sd_front)$fatal(1,"SD wrote displayed front buffer");
   if(ack_sync[1]==candidate_toggle)begin sd_front<=candidate_buf;pending<=0;swaps<=swaps+1;end
  end
 end
end
reg ack_prev=0;integer checks=0,frames=0,x,k,watchdog;
reg [23:0] expected;reg [1:0] expected_read=0;
always @(posedge vc)begin
 if(!rst)begin
  if(de && active_buf!==read_buf)$fatal(1,"read base changed within active line");
  if(ack!=ack_prev && !mem_ack)$fatal(1,"commit ACK before SDRAM acceptance");
  if(forwarded!=ack && valid_display && mode!=0 && transition.offset!=640)$fatal(1,"forwarded before black");
 end
 ack_prev<=ack;
end
task blank;
 begin
 de=0;hs=1;rgb=24'h112233;
 @(posedge vc);#1;
 if({oh,ov,od}!=={hs,vs,de} || out!==rgb)$fatal(1,"blank/sync");
 @(negedge vc);
 end
endtask
task submit;
 input [1:0] next_mode;
 begin
 if(pending)$fatal(1,"second outstanding SD candidate");
 @(negedge sc);mode=next_mode;candidate_buf=sd_front==0?1:0;
 held_candidate=candidate_buf;candidate_toggle=~candidate_toggle;pending=1;
 // Land event before frame boundary; source and destination clocks are distinct.
 repeat(10)blank;
 end
endtask
task video_frame;
 input integer offset;input integer sliding;input [1:0] expected_buffer;
 begin
 raw=1;vs=1;watchdog=0;
 while(!raw_ack)begin blank;watchdog=watchdog+1;if(watchdog>150)$fatal(1,"read handshake timeout");end
 raw=0;vs=0;repeat(8)blank;
 if(read_buf!==expected_buffer || active_buf!==expected_buffer)$fatal(1,"frame base got %d/%d expected %d",read_buf,active_buf,expected_buffer);
 for(x=0;x<640;x=x+1)begin
  de=1;hs=0;rgb=((16+read_buf)<<16)+(frames<<10)+x;
  expected=0;
  // Width of expression is explicit to avoid an unsized concatenation operand.
  if(x>=offset)expected=((16+read_buf)<<16)+(frames<<10)+(sliding?(x-offset):x);
  @(posedge vc);#1;
  if({oh,ov,od}!=={hs,vs,de} || out!==expected)$fatal(1,"frame%0d x%0d got%h expected%h",frames,x,out,expected);
  checks=checks+1;@(negedge vc);
 end
 blank;frames=frames+1;
 end
endtask
initial begin
 repeat(4)@(negedge vc);rst=0;
 // First image requests slide but valid=0 bypasses closing. Its real ACK releases
 // buffer zero only after display_commit and the delayed SDRAM model complete.
 submit(2);video_frame(0,0,1);repeat(4)blank;
 if(pending || sd_front!==1)$fatal(1,"first image SD ownership");valid_display=1;
 // Direct swap and a request close to a boundary still wait for memory ACK.
 submit(0);video_frame(0,0,0);repeat(4)blank;
 if(pending || sd_front!==0)$fatal(1,"direct SD ownership");
 submit(1);
 for(k=1;k<=20;k=k+1)video_frame(k*32,0,0);
 if(ack==candidate_toggle || !pending)$fatal(1,"wipe ACK before next frame acceptance");
 video_frame(640,0,1);repeat(4)blank;
 if(pending || sd_front!==1)$fatal(1,"wipe SD ownership");
 // SD can prepare the now-free old front while the new front is still opening.
 submit(2);
 for(k=19;k>=0;k=k-1)video_frame(k*32,0,1);
 for(k=1;k<=20;k=k+1)video_frame(k*32,1,1);
 if(ack==candidate_toggle || !pending)$fatal(1,"slide ACK before acceptance");
 video_frame(640,1,0);repeat(4)blank;
 if(pending || sd_front!==0)$fatal(1,"slide SD ownership");
 for(k=19;k>=0;k=k-1)video_frame(k*32,1,0);
 repeat(4)blank;
 // Boundary-critical event: submit less than one destination cycle before raw
 // request. It must defer to the following frame, never partially switch bases.
 @(negedge sc);mode=0;candidate_buf=1;held_candidate=1;
 candidate_toggle=~candidate_toggle;pending=1;
 video_frame(0,0,0);
 if(!pending)$fatal(1,"critical-boundary request accepted too early");
 video_frame(0,0,1);repeat(4)blank;
 if(busy || swaps!=5)$fatal(1,"end state swaps%0d busy%b",swaps,busy);
 $display("TEST_PASS transition_commit %0d frames %0d RGB/sync checks %0d acknowledged swaps",frames,checks,swaps);$finish;
end
endmodule
