// All controls are already atomic and frame-latched in the pixel domain.
module video_extensions #(parameter ENABLE_AUDIO_VIS=0)(
 input clk,rst,i_hs,i_vs,i_de,
 input [23:0] i_rgb,
 input [46:0] config_data,
 input sample_valid,input [23:0] sample_left,sample_right,
 input [15:0] audio_peak,input [3:0] audio_status,
 output o_hs,o_vs,o_de,
 output [23:0] o_rgb
);
 wire [3:0] state,volume;
 wire mute,paused,auto_mode,osd_enable;
 wire [7:0] progress,interval_seconds;
 wire [1:0] scale_mode,transition_mode;
 wire [2:0] contrast,mode;
 wire signed [8:0] brightness;
 assign {state,mute,paused,auto_mode,progress,volume,scale_mode,transition_mode,
         osd_enable,interval_seconds,contrast,brightness,mode}=config_data;
 wire h,v,d;wire [23:0] rgb;
 pixel_adjust adjust(.clk(clk),.rst(rst),.i_hs(i_hs),.i_vs(i_vs),.i_de(i_de),.i_rgb(i_rgb),
 .brightness(brightness),.contrast(contrast),.o_hs(h),.o_vs(v),.o_de(d),.o_rgb(rgb));
 wire vh,vv,vd;wire [23:0] vrgb;
 generate if(ENABLE_AUDIO_VIS)begin: with_audio_visual
 audio_visualizer visual(.clk(clk),.rst(rst),.i_hs(h),.i_vs(v),.i_de(d),.i_rgb(rgb),
 .sample_valid(sample_valid),.sample_left(sample_left),.sample_right(sample_right),
 .peak(audio_peak),.audio_status(audio_status),.enable(osd_enable),
 .o_hs(vh),.o_vs(vv),.o_de(vd),.o_rgb(vrgb));
 end else begin: without_audio_visual
 assign vh=h;assign vv=v;assign vd=d;assign vrgb=rgb;
 end endgenerate
 osd_overlay osd(.clk(clk),.rst(rst),.i_hs(vh),.i_vs(vv),.i_de(vd),.i_rgb(vrgb),
 .osd_enable(osd_enable),.mode(mode),.brightness(brightness),.contrast(contrast),
 .interval(interval_seconds),.transition_mode(transition_mode),.scale_mode(scale_mode),.volume(volume),
 .paused(paused),.auto_mode(auto_mode),.mute(mute),.state(state),.progress(progress),
 .title_x(10'd16),.title_y(10'd16),.status_x(10'd16),.status_y(10'd40),.ticker_y(10'd450),
 .fg_rgb(24'hffffff),.accent_rgb(24'h28dce8),
 .o_hs(o_hs),.o_vs(o_vs),.o_de(o_de),.o_rgb(o_rgb));
endmodule
