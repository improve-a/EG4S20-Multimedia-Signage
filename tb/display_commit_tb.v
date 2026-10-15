`timescale 1ns/1ps
module display_commit_tb;
 reg clk=0;always #20 clk=~clk;
 reg rst=1,req=0,mack=0,toggle=0,fault=0;reg[1:0]candidate=0;
 wire ack,mreq,ret;wire[1:0]active;
 display_commit dut(clk,rst,req,ack,mreq,mack,toggle,candidate,fault,active,ret);
 task cycles;input integer n;begin repeat(n)@(negedge clk);end endtask
 task reset_dut;begin rst=1;req=0;mack=0;toggle=0;fault=0;candidate=0;cycles(3);rst=0;cycles(5);end endtask
 task finish_read;input[1:0]expected;input expected_ret;
 begin
  wait(mreq);cycles(3);
  if(active!==expected || ack)$fatal(1,"address setup or premature ack");
  mack=1;cycles(1);
  if(!ack || mreq || ret!==expected_ret || active!==expected)$fatal(1,"reader handshake");
  req=0;cycles(2);mack=0;cycles(3);
  if(ack||mreq)$fatal(1,"drain handshake");
 end endtask
 initial begin
  reset_dut();
  // Delayed data models the bundled synchronizer resolving one cycle later
  // than the toggle; IDLE must not capture the stale candidate.
  toggle=1;cycles(3);req=1;candidate=1;cycles(1);
  if(active!==0 || mreq || ret)$fatal(1,"IDLE captured data too early");
  finish_read(1,1);
  candidate=0;toggle=0;cycles(4);req=1;cycles(1);
  if(ret!==1)$fatal(1,"premature commit ack");finish_read(0,0);
  // Fault observed while settling cancels publication.
  reset_dut();candidate=1;toggle=1;cycles(4);fault=1;req=1;
  finish_read(0,0);
  // Fault after request must relatch the previous front before video resumes.
  reset_dut();candidate=1;toggle=1;cycles(4);req=1;wait(mreq);cycles(1);
  fault=1;cycles(4);mack=1;cycles(1);
  if(ret || ack || mreq || active!==0)$fatal(1,"failed candidate abort");
  mack=0;cycles(1);wait(mreq);cycles(3);
  if(ret || ack || active!==0)$fatal(1,"rollback not complete");
  finish_read(0,0);
  rst=1;cycles(1);if(active||ret||mreq||ack)$fatal(1,"reset");
  $display("TEST_PASS display_commit delayed_bundle two_frames fault_settle fault_inflight rollback reset");$finish;
 end
 initial begin #100000;$fatal(1,"timeout");end
endmodule
