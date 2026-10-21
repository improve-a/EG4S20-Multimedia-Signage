// Read-only HDMI input diagnostics. No outputs feed the video/audio datapath.
module hdmi_probe #(
 parameter WINDOW_CYCLES=25000000, FRAME_PIXELS=307200, LINE_PIXELS=640
)(
 input clk,rst,vs,hs,de,av,au,al,ready,locked,audio_valid,
 output wire [27:0] flags
);
 reg [24:0] timer;
 reg prev_vs,prev_hs,prev_av,prev_lock,axis_vs,axis_vs_prev,expected_de;
 reg frame_started,frame_arm;
 reg [19:0] frame_pixels;
 reg [10:0] line_pixels;
 reg [4:0] ever,window_events,recent;
 wire [4:0] events={audio_valid,(av!=prev_av),de,(hs!=prev_hs),(vs&&!prev_vs)};
 reg frame_good,frame_bad,no_de,user_seen,last_seen,user_bad,line_bad;
 reg ready_high,ready_low,backpressure,sol_conflict;
 reg lock_ever,lock_drop,lock_timeout,lock_low_window,lock_full_window,heartbeat;
 wire vs_edge=vs&&!prev_vs;
 wire tick=timer==WINDOW_CYCLES-1;
 assign flags={1'b0,recent[1],ever[1],heartbeat,recent[4],ever[4],
               sol_conflict,backpressure,ready_low,ready_high,line_bad,user_bad,
               last_seen,user_seen,recent[3],ever[3],no_de,frame_bad,frame_good,
               recent[2],ever[2],recent[0],ever[0],
               lock_timeout,lock_drop,
               (lock_full_window&&!lock_low_window&&locked),lock_ever,locked};
 // flags[27] is reserved zero (27 payload bits).
 always @(posedge clk) begin
  if(rst)begin
   timer<=0;prev_vs<=0;prev_hs<=0;prev_av<=0;prev_lock<=0;
   axis_vs<=0;axis_vs_prev<=0;expected_de<=0;
   frame_started<=0;frame_arm<=1;frame_pixels<=0;line_pixels<=0;
   ever<=0;window_events<=0;recent<=0;
   frame_good<=0;frame_bad<=0;no_de<=0;user_seen<=0;last_seen<=0;user_bad<=0;line_bad<=0;
   ready_high<=0;ready_low<=0;backpressure<=0;sol_conflict<=0;
   lock_ever<=0;lock_drop<=0;lock_timeout<=0;lock_low_window<=0;lock_full_window<=0;heartbeat<=0;
  end else begin
   prev_vs<=vs;prev_hs<=hs;prev_av<=av;prev_lock<=locked;
   axis_vs<=vs;axis_vs_prev<=axis_vs;expected_de<=de;
   ever<=ever|events;
   if(tick)begin
    timer<=0;heartbeat<=!heartbeat;recent<=window_events|events;window_events<=0;
    if(!(window_events[2]||de))no_de<=1;
    if(!(lock_ever||locked))lock_timeout<=1;
    lock_full_window<=!lock_low_window&&locked;
    lock_low_window<=0;
   end else begin
    timer<=timer+1'b1;window_events<=window_events|events;
    if(!locked)lock_low_window<=1;
   end
   if(locked)lock_ever<=1;
   if(prev_lock&&!locked)lock_drop<=1;
   if(vs_edge)begin
    if(frame_started)begin
     if(frame_pixels==FRAME_PIXELS)frame_good<=1;else frame_bad<=1;
    end
    frame_started<=1;frame_pixels<=0;
   end else if(de)frame_pixels<=frame_pixels+1'b1;
   // AXIS is one pixel-clock register after the observed fx_* signals.
   if(axis_vs&&!axis_vs_prev)frame_arm<=1;
   if(av)begin
    if(!prev_av)begin
     if(au!=frame_arm)user_bad<=1;
     frame_arm<=0;
    end else if(au)user_bad<=1;
    if(al!=(line_pixels==LINE_PIXELS-1))line_bad<=1;
    line_pixels<=line_pixels+1'b1;
   end else begin
    if(prev_av && line_pixels!=LINE_PIXELS)line_bad<=1;
    line_pixels<=0;
   end
   if(au)begin user_seen<=1;if(!av)user_bad<=1;end
   if(al)begin last_seen<=1;if(!av)line_bad<=1;end
   if(av!=expected_de)line_bad<=1;
   if(ready)ready_high<=1;else ready_low<=1;
   if(av&&!ready)begin
    backpressure<=1;
    if(!prev_av)sol_conflict<=1;
   end
  end
 end
endmodule

// Only independent, slowly changing status bits cross into the 50MHz domain.
// No pixel count or multi-bit timer is sampled across clock domains.
module hdmi_probe_display #(parameter PAGE_CYCLES=150000000)(
 input clk,rst,
 input [27:0] flags_async,
 input video_rst_async,sys_lock_async,video_lock_async,
 output reg [23:0] digits,
 output wire [2:0] page_number
);
 (* async_reg="true", preserve="true" *) reg [30:0] status_meta,status_sync;
 reg [27:0] page_timer;
 reg [2:0] page;
 wire [27:0] f=status_sync[27:0];
 assign page_number=page+1'b1;
 function [3:0] activity;
  input seen,active;
  begin activity=active?4'd2:seen?4'd1:4'd0;end
 endfunction
 function [3:0] bit_digit;
  input value;
  begin bit_digit={3'b0,value};end
 endfunction
 always @(posedge clk)begin
  if(rst)begin status_meta<=0;status_sync<=0;page_timer<=0;page<=0;end
  else begin
   status_meta<={video_lock_async,sys_lock_async,video_rst_async,flags_async};
   status_sync<=status_meta;
   if(page_timer==PAGE_CYCLES-1)begin page_timer<=0;page<=page==4?0:page+1'b1;end
   else page_timer<=page_timer+1'b1;
  end
 end
 always @*begin
  case(page)
   0:digits={4'd1,bit_digit(f[0]),bit_digit(f[1]),bit_digit(f[2]),bit_digit(f[3]),bit_digit(f[4])};
   1:digits={4'd2,activity(f[5],f[6]),activity(f[7],f[8]),activity(f[25],f[26]),bit_digit(f[9]),bit_digit(f[10])};
   2:digits={4'd3,activity(f[12],f[13]),bit_digit(f[14]),bit_digit(f[15]),bit_digit(f[16]),bit_digit(f[17])};
   3:digits={4'd4,bit_digit(f[18]),bit_digit(f[19]),bit_digit(f[20]),bit_digit(f[21]),bit_digit(f[11])};
   4:digits={4'd5,activity(f[22],f[23]),bit_digit(status_sync[28]),bit_digit(status_sync[29]),bit_digit(status_sync[30]),bit_digit(f[24])};
   default:digits=24'h000000;
  endcase
 end
endmodule
