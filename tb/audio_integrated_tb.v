`timescale 1ns/1ps
// Offline test of official PCM and ACR sources; does not model encrypted HDMI IP.
module audio_integrated_tb;
  reg clk = 0;
  always #20 clk = ~clk; // Actual 25 MHz pixel clock.
  reg rst = 1;
  reg mute = 0;
  reg last_mute = 0;
  integer mute_stable_cycles = 0, silent_samples = 0;
  wire valid;
  wire [23:0] left_data, right_data;
  wire acr_valid;
  wire [19:0] cts, n;
  hdmi_audio_tone_pcm_scale #(.NOTE_HOLD_SAMPLES(96)) pcm (
    .I_clk(clk), .I_rst(rst), .I_mute_async(mute), .O_audio_valid(valid),
    .O_audio_left_data(left_data), .O_audio_right_data(right_data));
  audio_arc_calculate #(.ACR_N(6144)) acr (
    .I_clk(clk), .I_rst(rst), .I_audio_valid(valid),
    .O_acr_valid(acr_valid), .O_acr_cts(cts), .O_acr_n(n));
  integer cycles = 0, samples = 0, acrs = 0, last_sample = 0;
  integer last_acr = 0, gap = 0, positives = 0, negatives = 0;
  reg previous_valid = 0, previous_acr = 0;
  task fail;
    input [8*120-1:0] text;
    begin $display("FAIL audio_integrated_tb cycle=%0d sample=%0d: %0s",cycles,samples,text); $fatal(1); end
  endtask
  always @(posedge clk) begin
    #1;
    if (rst) begin
      cycles = 0; samples = 0; acrs = 0; last_sample = 0;
      last_acr = 0; positives = 0; negatives = 0;
      previous_valid = 0; previous_acr = 0;
      mute_stable_cycles = 0; silent_samples = 0; last_mute = mute;
      if (valid !== 0) fail("sample valid asserted in reset");
    end else begin
      cycles = cycles + 1;
      if(mute == last_mute) mute_stable_cycles = mute_stable_cycles + 1;
      else mute_stable_cycles = 0;
      last_mute = mute;
      if ((valid !== 0) && (valid !== 1)) fail("undefined sample valid");
      if (valid) begin
        if (previous_valid) fail("sample valid wider than one clock");
        samples = samples + 1;
        gap = cycles - last_sample;
        if (gap != 520 && gap != 521) fail("sample interval is not 520 or 521 clocks");
        last_sample = cycles;
        if (left_data !== right_data) fail("left/right samples differ");
        if (samples == 1) begin
          if (left_data !== 24'd0) fail("documented initial pipeline sample is not zero");
        end else if (mute && mute_stable_cycles >= 4) begin
          if(left_data !== 24'd0) fail("muted sample is nonzero");
          silent_samples = silent_samples + 1;
        end else if (mute_stable_cycles < 4 && left_data === 24'd0) begin
          // At most the synchronizer latency around the asynchronous toggle.
        end else if (left_data === 24'sd2000000) positives = positives + 1;
        else if (left_data === -24'sd2000000) negatives = negatives + 1;
        else fail("unexpected signed PCM amplitude or undefined bits");
      end
      if (acr_valid) begin
        acrs = acrs + 1;
        if (previous_acr) fail("ACR valid wider than one clock");
        if (n !== 20'd6144) fail("ACR N incorrect");
        // First ACR includes the source's registered-valid pipeline latency.
        if (acrs > 1 && cts !== 20'd25000) fail("steady ACR CTS incorrect");
        if (acrs > 1 && cycles-last_acr != 25000) fail("ACR interval is not 1 ms");
        last_acr = cycles;
      end
      previous_valid = valid;
      previous_acr = acr_valid;
    end
  end
  initial begin
    repeat(10) @(negedge clk);
    rst = 0;
    repeat(5000000) @(posedge clk);
    #2;
    if (samples != 9600 || acrs != 199) fail("200 ms sample or ACR total incorrect");
    if (positives == 0 || negatives == 0) fail("tone never changed polarity");
    $display("CHECK 200 ms: samples=%0d ACR=%0d positive=%0d negative=%0d",samples,acrs,positives,negatives);
    @(negedge clk); mute = 1;
    repeat(100000) @(posedge clk); #2;
    if (silent_samples < 190 || samples != 9792) fail("mute changed cadence or did not silence");
    @(negedge clk); mute = 0;
    repeat(100000) @(posedge clk); #2;
    if (samples != 9984 || acrs != 207) fail("unmute changed PCM or ACR cadence");
    @(negedge clk); rst = 1;
    repeat(10) @(negedge clk);
    rst = 0;
    repeat(500000) @(posedge clk);
    #2;
    if (samples != 960 || acrs != 19) fail("reset recovery totals incorrect");
    $display("TEST_PASS audio_integrated_tb actual_25MHz cycles=5700000 samples=10944 ACR=226 mute_unmute=PASS reset_recovery=PASS");
    $finish;
  end
  initial begin #240000000; fail("timeout"); end
endmodule
