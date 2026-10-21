`timescale 1ns/1ps
// Audio source-selection test for the real audio_output_mux.
// Shows that the tone is the selected source until status reaches 2/3/5, and
// that the selection is sticky once WAV has been observed (including later
// error/underflow codes), so a tone does not by itself prove a WAV fault.
module tb_audio_mux;
 reg clk=0, rst=1;
 always #20 clk=~clk; // 25 MHz
 reg [3:0] status=0;
 reg [3:0] volume=8;
 reg [23:0] tone_l=24'sd2000000, tone_r=24'sd2000000;
 reg [23:0] wav_l=24'h123456, wav_r=24'h654321;
 wire [23:0] left,right; wire audio_valid, wav_selected;
 reg tone_valid=1;

 audio_output_mux dut (.clk(clk),.rst(rst),.tone_valid(tone_valid),
  .tone_left(tone_l),.tone_right(tone_r),.wav_left(wav_l),.wav_right(wav_r),
  .wav_status(status),.volume(volume),.audio_valid(audio_valid),
  .audio_left(left),.audio_right(right),.wav_selected(wav_selected));

 task show;
  input [8*24-1:0] label;
  begin
   $display("%0s status=%0d selected=%b L=%h R=%h",label,status,wav_selected,left,right);
  end
  endtask

 integer errors=0;
 initial begin
  #100 rst=0;
  @(posedge clk); #1;
  // status 1: scanning / no WAV yet -> tone (gain 8 => unity)
  status=1; @(posedge clk); #1; show("scan  ");
  if(wav_selected!==1'b0 || left!==24'sd2000000) begin $display("FAIL expected tone"); errors=errors+1; end
  // status 2: file found -> WAV
  status=2; @(posedge clk); #1; show("found ");
  if(wav_selected!==1'b1 || left!==24'h123456) begin $display("FAIL expected WAV"); errors=errors+1; end
  // status 3: playing -> WAV
  status=3; @(posedge clk); #1; show("play  ");
  if(wav_selected!==1'b1) begin $display("FAIL expected WAV play"); errors=errors+1; end
  // status 0xd: underflow -> selection remains WAV (held samples, not tone)
  status=4'hd; @(posedge clk); #1; show("under ");
  if(wav_selected!==1'b1) begin $display("FAIL selection dropped to tone"); errors=errors+1; end
  // status 0xe: error -> still WAV-selected
  status=4'he; @(posedge clk); #1; show("error ");
  if(wav_selected!==1'b1) begin $display("FAIL selection dropped to tone"); errors=errors+1; end
  $display("SUMMARY errors=%0d",errors);
  $finish;
 end
 initial begin #100000; $display("FAIL timeout"); $finish; end
endmodule
