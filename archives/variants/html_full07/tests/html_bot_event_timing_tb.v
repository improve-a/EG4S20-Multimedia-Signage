`timescale 1ns/1ps
module html_bot_event_timing_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,vs=0,event_in=0;reg signed[1:0] direction=1;
 html_bot_overlay dut(.clk(clk),.rst(rst),.i_hs(1'b0),.i_vs(vs),.i_de(1'b0),.i_rgb(24'd0),
  .enable(1'b1),.page_event(event_in),.page_direction(direction),.speaking(1'b0),.syllable(1'b0),.audio_level(8'd0),
  .o_hs(),.o_vs(),.o_de(),.o_rgb());
 integer n,rev,delivery,expected_gx,expected_tilt,checks=0,old_x,old_age;
 task step;begin @(posedge clk);#2;@(negedge clk);end endtask
 task frame;begin vs=1;step;vs=0;event_in=0;repeat(3)step;end endtask
 task seed;
 begin
  dut.frame_count=128;dut.reaction_age=255;dut.gaze_x=0;dut.gaze_y=0;dut.gaze_vx=0;dut.gaze_vy=0;
  dut.tilt=0;dut.tilt_v=0;dut.shape=0;dut.shape_v=0;dut.hop=0;dut.hop_v=0;dut.event_pending=0;
 end endtask
 initial begin
  repeat(4)step;rst=0;frame;
  // Event beforeVS, event onVS, and event lateafterVS all use the next
  // committed direction and integrateage0 exactly once at the nextVS.
  for(rev=0;rev<2;rev=rev+1)for(delivery=0;delivery<3;delivery=delivery+1)begin
   seed;direction=rev ? -2'sd1 : 2'sd1;
   if(delivery==2)begin frame;seed;repeat(10)step;end
   event_in=1;
   if(delivery!=1)begin step;event_in=0;old_x=dut.gaze_x;old_age=dut.reaction_age;repeat(12)step;
    if(dut.gaze_x!==old_x||dut.reaction_age!==old_age)$fatal(1,"event integratedoutsideframe");end
   #1;
   if(dut.target_age!==0||dut.gx_target!==direction*144||dut.target_direction!==direction)$fatal(1,"eventtarget didnotusecommitteddirection");
   frame;
   if(dut.reaction_age!==0||dut.gaze_x!==direction*18||dut.tilt!==0)$fatal(1,"first committedframe eyesnotimmediate");
   for(n=1;n<=120;n=n+1)begin
    expected_gx=n<25 ? direction*144 : n<66 ? -direction*80 : n<93 ? -112 : 0;
    expected_tilt=n<6 ? 0 : n<25 ? direction*288 : n<66 ? -direction*112 : 0;
    if(n<6&&dut.tilt!==0)$fatal(1,"body tiltedbefore90ms");
    #1;
    if(dut.target_age!==n||dut.gx_target!==expected_gx||dut.tilt_target!==expected_tilt)
     $fatal(1,"timeline target mismatch frame%0d reverse%0d gx%0d tilt%0d",n,rev,dut.gx_target,dut.tilt_target);
    frame;
    if(dut.reaction_age!==n)$fatal(1,"timeline age mismatch");
    if(n==6&&dut.tilt==0)$fatal(1,"body didnotfollowonfirstframeafter90ms");
    if(n==6||n==25||n==66||n==93)$display("KEYFRAME_PASS reverse%0d delivery%0d frame%0d gaze%0d tilt%0d",rev,delivery,n,dut.gaze_x,dut.tilt);
    checks=checks+1;
   end
  end
  $display("TEST_PASS Bot firstcommittedframeeyes,90msbody,0/6/25/66/93timeline,bothdirections,early/same/latependingevents checks%0d",checks);$finish;
 end
endmodule
