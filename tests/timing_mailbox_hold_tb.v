`timescale 1ns/1ps
// Protocol contract only. Ideal RTL clocks do not model metastability.
module timing_mailbox_hold_tb;
 wire[9:0]done;
 mailbox_contract #(.WIDTH(51),.PHASE(0.001)) a0(done[0]);
 mailbox_contract #(.WIDTH(3),.PHASE(0.001)) a1(done[1]);
 mailbox_contract #(.WIDTH(51),.PHASE(4.999)) b0(done[2]);
 mailbox_contract #(.WIDTH(3),.PHASE(4.999)) b1(done[3]);
 mailbox_contract #(.WIDTH(51),.PHASE(9.7)) c0(done[4]);
 mailbox_contract #(.WIDTH(3),.PHASE(9.7)) c1(done[5]);
 mailbox_contract #(.WIDTH(51),.PHASE(19.999)) d0(done[6]);
 mailbox_contract #(.WIDTH(3),.PHASE(19.999)) d1(done[7]);
 mailbox_contract #(.WIDTH(51),.PHASE(5.001)) e0(done[8]);
 mailbox_contract #(.WIDTH(3),.PHASE(5.001)) e1(done[9]);
 initial begin wait(&done);$display("TEST_PASS timing_mailbox_hold widths=51,3 phase_trials=5 clock_periods=10ns,40ns capture_before>=160ns payload_reuse_after>20ns reset_aborts_separate");$finish;end
 initial begin #50000;$fatal(1,"mailbox watchdog");end
endmodule
module mailbox_contract #(parameter WIDTH=51,parameter real PHASE=0)(output reg done=0);
 reg sc=0,dc=0,sr=1,dr=1,frame=0,freeze=0;
 always #5 sc=~sc;
 initial begin #(PHASE);forever #20 dc=~dc;end
 reg[WIDTH-1:0]src_word=0;wire[WIDTH-1:0]dest;
 frame_config_bridge #(.WIDTH(WIDTH)) dut(sc,sr,src_word,dc,dr,frame,dest);
 integer k=0,dc_count=0,captures=0,updates=0,aborted=0,commits=0,after_checks=0;
 real payload_time=0,capture_time=0,min_before=1.0e9,min_after=1.0e9,delta;
 reg payload_valid=0,capture_valid=0,was_pending=0;
 reg[WIDTH-1:0]expected_payload,pre_payload,pre_shadow,old_dest=0;
 reg real_capture,sampled_frame;
 function[WIDTH-1:0]word(input integer n);begin
  if(WIDTH==51)word={3'b101,n[15:0],~n[15:0],n[15:0]};else word=n[2:0];
 end endfunction
 always @(negedge sc)if(!freeze)begin k=k+1;src_word=word(k);end
 // Recognize real source transactions from the actual enable and check the
 // exact snapshot. Capture times exclude coordinated reset aborts.
 always @(posedge sc)begin
  if(sr||dr)begin payload_valid=0;capture_valid=0;end
  else if(dut.ack_sync[1]==dut.request&&src_word!=dut.payload)begin
   expected_payload=src_word;
   if(capture_valid)begin
    delta=$realtime-capture_time;
    if(delta<=20.0)$fatal(1,"payload reused before ackroundtrip WIDTH=%0d phase=%f delta=%f",WIDTH,PHASE,delta);
    if(delta<min_after)min_after=delta;after_checks=after_checks+1;
   end
   payload_time=$realtime;payload_valid=1;capture_valid=0;updates=updates+1;
   #0.001;if(dut.payload!==expected_payload)$fatal(1,"source snapshot incoherent");
  end
 end
 always @(negedge dc)begin
  dc_count=dc_count+1;
  // Long frame stalls demonstrate ack/shadow transfer is independent of commit.
  frame=!dr&&dc_count>100&&(dc_count%17==0);
 end
 always @(posedge dc)begin
  real_capture=!dr&&(dut.req_sync[1]!=dut.ack)&&(dut.settle==2);
  pre_payload=dut.payload;pre_shadow=dut.shadow;sampled_frame=frame;
  if(real_capture)begin
   if(!payload_valid)$fatal(1,"capture without a nonaborted source transaction");
   delta=$realtime-payload_time;
   if(delta<160.0)$fatal(1,"payload stablebeforecapture too short WIDTH=%0d phase=%f delta=%f",WIDTH,PHASE,delta);
   if(delta<min_before)min_before=delta;
   capture_time=$realtime;capture_valid=1;captures=captures+1;
  end
  #0.002;
  if(real_capture&&dut.shadow!==pre_payload)$fatal(1,"capturedword incoherent");
  if(!dr)begin
   if(dest!==old_dest)begin
    if(!sampled_frame||dest!==pre_shadow)$fatal(1,"frame commit or atomicity mismatch");
    commits=commits+1;
   end
   if(WIDTH==51&&dest!=0)begin
    if(dest[50:48]!==3'b101||dest[47:32]!==dest[15:0]||dest[31:16]!==~dest[15:0])$fatal(1,"torn51bit src_word");
   end
  end
  old_dest=dest;
 end
 task abort_reset(input real ns);
 begin
  if(dut.request!=dut.ack)aborted=aborted+1;
  sr=1;dr=1;payload_valid=0;capture_valid=0;
  #(ns);sr=0;dr=0;
 end endtask
 initial begin
  #113.13;sr=0;dr=0;
  #187.11;abort_reset(83.17);
  #721.3;abort_reset(121.71);
  #2131.07;abort_reset(93.31);
  #21000;freeze=1;
  repeat(150)@(negedge dc);
  if(dest!==src_word)$fatal(1,"final src_word not committed");
  if(captures<40||after_checks<30||commits<5||aborted<1)$fatal(1,"insufficient mailbox coverage");
  $display("MAILBOX_CONTRACT WIDTH=%0d PHASE_NS=%f captures=%0d updates=%0d commits=%0d reset_aborts=%0d min_before_ns=%f min_after_ns=%f after_checks=%0d",WIDTH,PHASE,captures,updates,commits,aborted,min_before,min_after,after_checks);
  done=1;
 end
endmodule
