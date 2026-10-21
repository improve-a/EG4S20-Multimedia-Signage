// 48kHz cadence remains active during mute, pause, preload and EOF.
// Controls/eof/ready synchronous to this clock; 16-bit PCM becomes HDMI 24-bit.
module audio_pcm_player #(parameter CLK_HZ=25000000,SAMPLE_HZ=48000)(
 input clk,rst,enabled,paused,muted,ready,eof,input [3:0] volume,
 input fifo_empty,input [31:0] fifo_data,output fifo_pop,
 output reg audio_valid,output reg [23:0] audio_left,audio_right,
 output reg underflow,output reg drained,output reg [15:0] wave_peak
);
reg [31:0] phase;
wire [32:0] phase_sum={1'b0,phase}+SAMPLE_HZ;
wire tick=phase_sum>=CLK_HZ;
assign fifo_pop=tick&&enabled&&ready&&!paused&&!fifo_empty;
reg pending,pending_zero,pending_mute;
reg [3:0] pending_volume;
wire [3:0] gain=pending_volume>8?4'd8:pending_volume;
wire signed [20:0] left_scaled=$signed(fifo_data[31:16])*$signed({1'b0,gain});
wire signed [20:0] right_scaled=$signed(fifo_data[15:0])*$signed({1'b0,gain});
wire signed [15:0] left_value=left_scaled>>>3;
wire signed [15:0] right_value=right_scaled>>>3;
wire [15:0] left_abs=left_value[15]?(~left_value+1'b1):left_value;
wire [15:0] right_abs=right_value[15]?(~right_value+1'b1):right_value;
wire [15:0] peak=left_abs>right_abs?left_abs:right_abs;
reg [5:0] peak_count;
reg [15:0] peak_acc;
always @(posedge clk)begin
 if(rst)begin phase<=0;pending<=0;pending_zero<=1;pending_mute<=0;pending_volume<=8;
  audio_valid<=0;audio_left<=0;audio_right<=0;underflow<=0;drained<=0;wave_peak<=0;peak_count<=0;peak_acc<=0;end
 else begin
  phase<=tick?phase_sum-CLK_HZ:phase_sum;
  audio_valid<=pending;pending<=tick;
  if(tick)begin
   pending_zero<=!fifo_pop;pending_mute<=muted;pending_volume<=volume;
   if(enabled&&ready&&!paused&&fifo_empty&&!eof)underflow<=1;
   if(enabled&&ready&&fifo_empty&&eof)drained<=1;
  end
  if(pending)begin
   audio_left<=(pending_zero||pending_mute)?24'd0:{left_value,8'b0};
   audio_right<=(pending_zero||pending_mute)?24'd0:{right_value,8'b0};
   // One maximum every 64 output samples (750 waveform points/second).
   if(peak_count==63)begin
    wave_peak<=(pending_zero||pending_mute)?peak_acc:(peak>peak_acc?peak:peak_acc);
    peak_count<=0;peak_acc<=0;
   end else begin
    peak_count<=peak_count+1'b1;
    if(!pending_zero&&!pending_mute&&peak>peak_acc)peak_acc<=peak;
   end
  end
 end
end
endmodule
