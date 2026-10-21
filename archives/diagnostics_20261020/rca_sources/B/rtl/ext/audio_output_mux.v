// One continuous inherited HDMI sample clock for both sources. The WAV player
// updates held PCM in this same pixel-clock domain at the same 48kHz rate.
module audio_output_mux(
 input clk,rst,tone_valid,
 input [23:0] tone_left,tone_right,wav_left,wav_right,
 input [3:0] wav_status,volume,
 output audio_valid,output [23:0] audio_left,audio_right,
 output reg wav_selected
);
 always @(posedge clk)begin
  if(rst)wav_selected<=0;
  // PAUSE (4) can also describe an initial scan; it does not prove a file was
  // found. Once prefill/play/EOF selects WAV, later errors/EOF remain silence.
  else if(wav_status==2 || wav_status==3 || wav_status==5)wav_selected<=1;
 end
 wire [3:0] gain=volume>8 ? 4'd8 : volume;
 wire signed [28:0] tone_gain_left=$signed(tone_left)*$signed({1'b0,gain});
 wire signed [28:0] tone_gain_right=$signed(tone_right)*$signed({1'b0,gain});
 assign audio_valid=tone_valid;
 assign audio_left=wav_selected ? wav_left : (tone_gain_left>>>3);
 assign audio_right=wav_selected ? wav_right : (tone_gain_right>>>3);
endmodule
