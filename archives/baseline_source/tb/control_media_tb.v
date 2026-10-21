`timescale 1ns/1ps
module control_media_tb;
  reg clk=0;
  always #5 clk=~clk;
  reg rst=1, next_key=1, auto_key=1, pause_key=1;
  wire next_pulse, auto_mode, paused, muted, mode_changed;
  integer steps=0;
  reg prev_pulse=0;
  media_controls #(.CLK_FREQ_HZ(1000), .DEBOUNCE_MS(5), .LONG_PRESS_MS(40)) dut
    (.clk(clk),.rst(rst),.key_next(next_key),.key_auto(auto_key),.key_pause_mute(pause_key),
     .next_pulse(next_pulse),.auto_mode(auto_mode),.paused(paused),.muted(muted),.mode_changed(mode_changed));
  task wait_cycles; input integer count; begin repeat(count) @(negedge clk); end endtask
  task fail; input [8*100-1:0] why; begin $display("FAIL control_media_tb: %0s",why); $fatal(1); end endtask
  always @(posedge clk) begin
    #1;
    if(rst) begin steps=0; prev_pulse=0; end
    else begin
      if(next_pulse && prev_pulse) fail("next pulse multiple cycles");
      if(next_pulse) steps=steps+1;
      prev_pulse=next_pulse;
    end
  end
  initial begin
    wait_cycles(3); rst=0;
    if(auto_mode || paused || muted) fail("reset values");
    next_key=0; wait_cycles(2); next_key=1; wait_cycles(10);
    if(steps!=0) fail("bounce accepted");
    next_key=0; wait_cycles(50);
    if(steps!=1) fail("held next not exactly once");
    next_key=1; wait_cycles(10); next_key=0; wait_cycles(10); next_key=1; wait_cycles(10);
    if(steps!=2) fail("release/repress failed");
    auto_key=0; wait_cycles(50);
    if(!auto_mode) fail("auto not enabled");
    auto_key=1; wait_cycles(10); auto_key=0; wait_cycles(10); auto_key=1; wait_cycles(10);
    if(auto_mode) fail("manual mode not restored");
    pause_key=0; wait_cycles(12); pause_key=1; wait_cycles(10);
    if(!paused || muted) fail("short press must pause only");
    // Long press toggles mute once, not pause; holding must not toggle repeatedly.
    pause_key=0; wait_cycles(150);
    if(!paused || !muted) fail("long press must mute once without resuming");
    pause_key=1; wait_cycles(10);
    if(!paused || !muted) fail("long release changed pause");
    pause_key=0; wait_cycles(12); pause_key=1; wait_cycles(10);
    if(paused || !muted) fail("resume must retain mute");
    pause_key=0; wait_cycles(60); pause_key=1; wait_cycles(10);
    if(paused || muted) fail("second long press must unmute only");
    // A sub-debounce release does not split one held press into two actions.
    pause_key=0; wait_cycles(12); pause_key=1; wait_cycles(2); pause_key=0; wait_cycles(60);
    if(paused || !muted) fail("release bounce caused pause or lost long press");
    pause_key=1; wait_cycles(10);
    rst=1; wait_cycles(3); rst=0; wait_cycles(10);
    if(auto_mode || paused || muted || steps!=0) fail("reset recovery failed");
    $display("TEST_PASS control_media_tb bounce next auto pause long_mute reset"); $finish;
  end
  initial begin #20000; fail("timeout"); end
endmodule
