`timescale 1ns/1ps
module control_modes_tb;
  reg clk=0;
  always #5 clk=~clk;
  reg rst=1, key2=1, key4=1, key3=1;
  wire next_pulse, auto_mode, paused, muted, mode_changed;
  wire [2:0] mode, contrast;
  wire signed [8:0] brightness;
  wire [7:0] interval_seconds;
  wire osd_enable;
  wire [1:0] transition_mode, scale_mode;
  wire [3:0] volume;
  wire param_changed;
  integer next_count=0;
  integer mode_changed_count=0, param_changed_count=0;
  integer interval_change_start=0;
  reg previous_next=0;
  media_controls #(.CLK_FREQ_HZ(1000), .DEBOUNCE_MS(5), .LONG_PRESS_MS(40),
                   .AUTO_PERIOD_SECONDS(3)) dut(
    .clk(clk), .rst(rst), .key_next(key2), .key_auto(key4), .key_pause_mute(key3),
    .next_pulse(next_pulse), .auto_mode(auto_mode), .paused(paused), .muted(muted),
    .mode_changed(mode_changed), .mode(mode), .brightness(brightness), .contrast(contrast),
    .interval_seconds(interval_seconds), .osd_enable(osd_enable),
    .transition_mode(transition_mode), .scale_mode(scale_mode), .volume(volume),
    .param_changed(param_changed));

  task step; input integer n; begin repeat(n) @(negedge clk); end endtask
  task fail; input [8*120-1:0] why; begin $display("FAIL control_modes_tb: %0s",why); $fatal(1); end endtask
  task tap2; begin key2=0; step(12); key2=1; step(12); end endtask
  task tap4; begin key4=0; step(12); key4=1; step(12); end endtask
  task hold4; begin key4=0; step(70); key4=1; step(12); end endtask
  task hold3; begin key3=0; step(70); key3=1; step(12); end endtask
  always @(posedge clk) begin
    #1;
    if (rst) begin
      next_count=0; previous_next=0; mode_changed_count=0; param_changed_count=0;
    end
    else begin
      if (next_pulse && previous_next) fail("next pulse was wider than one cycle");
      if (mode_changed && mode_changed_count>=0) mode_changed_count=mode_changed_count+1;
      if (param_changed && param_changed_count>=0) param_changed_count=param_changed_count+1;
      if (next_pulse) next_count=next_count+1;
      previous_next=next_pulse;
    end
  end

  initial begin
    step(3); rst=0; step(5);
    if (mode!==0 || auto_mode || paused || muted || brightness!==0 || contrast!==2 ||
        interval_seconds!==3 || !osd_enable || transition_mode!==0 || scale_mode!==0 || volume!==8)
      fail("reset defaults");

    // Short bounce is ignored; ordinary mode retains KEY2 next and KEY4 auto.
    key2=0; step(2); key2=1; step(12);
    if (next_count!=0) fail("bounce produced next");
    tap2();
    if (next_count!=1) fail("mode 0 KEY2 did not produce one next pulse");
    tap4();
    if (!auto_mode || mode!=0) fail("short KEY4 did not toggle auto in mode 0");
    if (mode_changed_count!=1 || param_changed_count!=0) fail("auto change pulse contract");
    tap4();
    if (auto_mode || mode_changed_count!=2) fail("second short KEY4 did not restore manual mode");

    // A long KEY4 press changes page once and its release cannot trigger auto.
    hold4();
    if (mode!=1 || auto_mode) fail("long KEY4 did not enter brightness mode exclusively");
    if (param_changed_count!=1 || mode_changed_count!=2) fail("page change pulse contract");
    tap4();
    if (brightness!==-9'sd16 || mode!=1) fail("KEY4 short press did not decrement brightness");
    repeat(9) tap2();
    if (brightness!==9'sd127) fail("brightness positive saturation must reach 127");
    tap2();
    if (brightness!==9'sd127) fail("brightness exceeded positive limit");
    tap4();
    if (brightness!==9'sd111) fail("brightness decrement from positive endpoint");
    repeat(16) tap4();
    if (brightness!==-9'sd128) fail("brightness negative saturation must reach -128");
    tap4();
    if (brightness!==-9'sd128) fail("brightness exceeded negative limit");

    hold4(); // contrast mode
    if (mode!=2 || auto_mode) fail("mode 1 -> 2 long navigation");
    repeat(8) tap2();
    if (contrast!==6) fail("contrast upper saturation");
    repeat(8) tap4();
    if (contrast!==0) fail("contrast lower saturation");

    hold4(); // interval mode
    if (mode!=3) fail("mode 2 -> 3 long navigation");
    interval_change_start=mode_changed_count;
    repeat(20) tap2();
    if (interval_seconds!==15) fail("interval upper saturation");
    repeat(20) tap4();
    if (interval_seconds!==1) fail("interval lower saturation");
    if (mode_changed_count-interval_change_start!=26) fail("interval change pulse count");

    hold4(); // OSD mode
    if (mode!=4 || !osd_enable) fail("mode 3 -> 4 or OSD default");
    tap2();
    if (osd_enable) fail("OSD did not turn off");
    hold4();
    if (mode!=5 || osd_enable) fail("OSD-off long navigation failed");
    tap2(); if (transition_mode!=1) fail("transition next step");
    tap2(); if (transition_mode!=2) fail("transition third choice");
    tap2(); if (transition_mode!=0) fail("transition wraps to cut");
    tap4(); if (transition_mode!=2) fail("transition previous wraps");

    hold4(); // scaling mode
    if (mode!=6) fail("mode 5 -> 6 long navigation");
    tap2(); if (scale_mode!=1) begin $display("scale after KEY2=%0d mode=%0d",scale_mode,mode); fail("scale mode toggle on"); end
    tap4(); if (scale_mode!=0) fail("scale mode toggle off");
    hold4(); // volume mode
    if (mode!=7) fail("mode 6 -> 7 long navigation");
    repeat(12) tap4(); if (volume!=0) fail("volume lower saturation");
    repeat(12) tap2(); if (volume!=8) fail("volume upper saturation");
    hold4(); if (mode!=0) fail("mode 7 -> 0 wrap");

    // KEY3 stays available on every page, including long mute and short pause.
    key3=0; step(12); key3=1; step(12);
    if (!paused || muted) fail("KEY3 short press behavior changed");
    hold3();
    if (!paused || !muted) fail("KEY3 long press behavior changed");

    // Reset restores every newly added setting as well as legacy state.
    rst=1; step(3); rst=0; step(8);
    if (mode!==0 || auto_mode || paused || muted || brightness!==0 || contrast!==2 ||
        interval_seconds!==3 || !osd_enable || transition_mode!==0 || scale_mode!==0 || volume!==8)
      fail("reset recovery/defaults");
    $display("TEST_PASS control_modes_tb debounce legacy_keys modes parameters boundaries long_short reset");
    $finish;
  end
  initial begin #2000000; fail("timeout"); end
endmodule
