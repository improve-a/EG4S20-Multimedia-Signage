// Current pixels come from the legacy composed frame; OSD stays in screen coordinates.
// No character layer: one pixel-adjust stage plus five OSD stages (six clocks).
// RGB and all three video qualifiers use this same registered path.
module html_video_overlay(
 input clk,rst,i_hs,i_vs,i_de,input [23:0] i_rgb,
 input [50:0] config_data,input page_event,input [2:0] page_index,input dual_enable,input page_reverse,input [2:0] focus,
 input [15:0] audio_peak,input [3:0] audio_status,
 output o_hs,o_vs,o_de,output [23:0] o_rgb
);
 wire [3:0] state,volume;
 wire mute,paused,auto_mode,osd_enable;
 wire [7:0] progress,interval_seconds;
 wire [1:0] scale_mode,transition_mode;
 wire [2:0] contrast,mode;
 wire signed [8:0] brightness;
 wire [3:0] interval_fraction=config_data[50:47];
 assign {state,mute,paused,auto_mode,progress,volume,scale_mode,transition_mode,
         osd_enable,interval_seconds,contrast,brightness,mode}=config_data[46:0];
 wire ah,av,ad;
 wire [23:0] argb;
 pixel_adjust adjust(.clk(clk),.rst(rst),.i_hs(i_hs),.i_vs(i_vs),.i_de(i_de),.i_rgb(i_rgb),
  .brightness(brightness),.contrast(contrast),.o_hs(ah),.o_vs(av),.o_de(ad),.o_rgb(argb));
 html_osd_overlay osd(.clk(clk),.rst(rst),.i_hs(ah),.i_vs(av),.i_de(ad),.i_rgb(argb),
  .osd_enable(osd_enable),.page_event(page_event),.page_index(page_index),.dual_enable(dual_enable),
  .zoom_enable(scale_mode!=0),.scale_mode(scale_mode),.focus(focus),.progress(progress),.brightness(brightness),.contrast(contrast),
  .mode(mode),.volume(volume),.mute(mute),.paused(paused),.auto_mode(auto_mode),.interval(interval_seconds),.interval_fraction(interval_fraction),
  .audio_peak(audio_peak),.audio_status(audio_status),.speaking(),.syllable(),
  .o_hs(o_hs),.o_vs(o_vs),.o_de(o_de),.o_rgb(o_rgb));
endmodule
