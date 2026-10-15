`timescale 1ns/1ps
module transition_tb;
localparam W=640,S=32,N=W/S;
reg clk=0;always #5 clk=~clk;
reg rst=1,hs=0,vs=0,de=0,enable=1,frame=0,candidate=0,ack=0;
reg [1:0] mode=0;reg [23:0] rgb=0;
wire forwarded,oh,ov,od,busy;wire [23:0] out;
video_transition #(.WIDTH(W),.STEP(S))dut(clk,rst,hs,vs,de,rgb,enable,mode,frame,candidate,ack,forwarded,oh,ov,od,out,busy);
integer checks=0,x,k;reg [23:0] expected;reg [23:0] base=24'h010000;
task cycle;
 input [23:0] exp;
 begin @(posedge clk);#1;
 if({oh,ov,od}!=={hs,vs,de} || out!==exp)$fatal(1,"pixel/sync x%0d got%h expected%h",x,out,exp);
 checks=checks+1;@(negedge clk);end
endtask
task blank;
 begin de=0;hs=1;rgb=24'h112233;cycle(rgb);end
endtask
task boundary;
 begin frame=1;blank;frame=0;vs=1;blank;vs=0;blank;end
endtask
task line;
 input integer shift;input integer sliding;
 begin
 for(x=0;x<W;x=x+1)begin
  de=1;hs=0;rgb=base+x;
  if(x<shift)expected=0;
  else expected=base+x-(sliding?shift:0);
  cycle(expected);
 end
 blank;
 end
endtask
task wait_sync;
 begin repeat(5)blank;end
endtask
initial begin
 @(posedge clk);#1;if({oh,ov,od,out,forwarded}!==0)$fatal(1,"reset");
 @(negedge clk);rst=0;
 // Direct mode and first image bypass have no animation, but still need a real ACK.
 mode=0;candidate=1;wait_sync;
 if(forwarded!==1 || !busy)$fatal(1,"direct request");line(0,0);ack=1;blank;
 enable=0;mode=2;candidate=0;wait_sync;
 if(forwarded!==0)$fatal(1,"first image request");line(0,0);ack=0;enable=1;blank;
 // Wipe locks mode despite live changes; no commit until fully black.
 mode=1;candidate=1;wait_sync;mode=2;
 for(k=1;k<=N;k=k+1)begin
  boundary;line(k*S,0);
  if(forwarded!==(k==N))$fatal(1,"early wipe commit");
 end
 // A queued second request waits for the complete opening.
 candidate=0;wait_sync;
 repeat(2)begin boundary;line(W,0);if(forwarded!==1)$fatal(1,"pending commit escaped");end
 ack=1;base=24'h020000;
 for(k=N-1;k>=0;k=k-1)begin boundary;line(k*S,0);end
 // Queued mode2 slide begins after opening and shifts actual pixels.
 wait_sync;
 for(k=1;k<=N;k=k+1)begin
  boundary;line(k*S,1);
  if(forwarded!==(k==N?0:1))$fatal(1,"early slide commit");
 end
 boundary;line(W,1);ack=0;base=24'h030000;
 for(k=N-1;k>=0;k=k-1)begin boundary;line(k*S,1);end
 wait_sync;if(busy)$fatal(1,"never completed");
 // Illegal mode degrades to direct. No invented acknowledgement.
 mode=3;candidate=1;wait_sync;
 if(forwarded!==1 || !busy)$fatal(1,"illegal mode fallback");line(0,0);
 ack=1;blank;if(busy)$fatal(1,"direct ack");
 mode=2;candidate=0;wait_sync;boundary;line(S,1);
 rst=1;@(posedge clk);#1;if({oh,ov,od,out,forwarded}!==0)$fatal(1,"midstream reset");
 $display("TEST_PASS video_transition %0d pixel/sync checks",checks);$finish;
end
endmodule
