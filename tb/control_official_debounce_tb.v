`timescale 1ns/1ps
module control_official_debounce_tb;
  reg clk=0;
  always #5 clk=~clk;
  reg rst=1, button=1;
  wire pressed;
  // Reduce only elapsed debounce duration; preserve synchronizer/edge behavior.
  key_press_debounce #(.CLK_FREQ_HZ(1000), .DEBOUNCE_MS(5)) dut
    (.clk(clk), .rst(rst), .button_in(button), .press_pulse(pressed));
  integer pulses=0;
  reg previous=0;
  always @(posedge clk) begin
    #1;
    if (rst) begin pulses=0; previous=0; end
    else begin
      if (pressed && previous) begin $display("FAIL debounce pulse width"); $fatal(1); end
      if (pressed) pulses=pulses+1;
      previous=pressed;
    end
  end
  task step; input integer count; begin repeat(count) @(negedge clk); end endtask
  task expect_count;
    input integer expected;
    begin if(pulses!=expected) begin $display("FAIL debounce got=%0d expected=%0d",pulses,expected); $fatal(1); end end
  endtask
  initial begin
    step(3); rst=0;
    button=0; step(2); button=1; step(10); expect_count(0);
    button=0; step(20); expect_count(1);
    step(30); expect_count(1);
    button=1; step(2); button=0; step(10); expect_count(1);
    button=1; step(10); button=0; step(10); expect_count(2);
    rst=1; step(3); rst=0; step(10); expect_count(1);
    button=1; step(10); button=0; step(10); expect_count(2);
    $display("TEST_PASS control_official_debounce_tb bounce held_release_repress reset"); $finish;
  end
  initial begin #10000; $display("FAIL debounce timeout"); $fatal(1); end
endmodule
