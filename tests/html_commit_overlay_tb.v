`timescale 1ns/1ps
// Actual display_commit, inherited video timing, and production overlays.
// ReaderACK is a bounded delay model here; the separate full-chain bench uses
// the real reader/FIFOs/bridge. Counters preload into blanking for short runs.
module html_commit_overlay_tb;
 reg clk=0;always #20 clk=~clk;
 reg rst=1,commit_toggle=0;
 reg [4:0] candidate=1;
 wire raw_req,raw_ack,mem_req,hs,vs,de;reg mem_ack=0;
 wire [4:0] active_view;wire commit_ack;
 reg previous_commit=0;
 wire page_event=commit_ack^previous_commit;
 always @(posedge clk)if(rst)previous_commit<=0;else previous_commit<=commit_ack;
 video_timing_data timing(.video_clk(clk),.rst(rst),.read_req(raw_req),.read_req_ack(raw_ack),.hs(hs),.vs(vs),.de(de));
 display_commit #(.BUFFER_BITS(5)) commit_dut(.video_clk(clk),.rst(rst),.raw_read_req(raw_req),.raw_read_ack(raw_ack),
  .mem_read_req(mem_req),.mem_read_ack(mem_ack),.commit_toggle_async(commit_toggle),.candidate_async(candidate),
  .fault_async(1'b0),.active_buf(active_view),.commit_ack_toggle(commit_ack));
 wire oh,ov,od;wire[23:0] rgb;
 wire[50:0] config_data={4'd4,4'd0,1'b0,1'b0,1'b1,8'd0,4'd8,2'd0,2'd0,1'b1,8'd5,3'd2,9'd0,3'd0};
 html_video_overlay overlay(.clk(clk),.rst(rst),.i_hs(hs),.i_vs(vs),.i_de(de),.i_rgb(24'h123456),
  .config_data(config_data),.page_event(page_event),.page_index(active_view[2:0]),.dual_enable(active_view[3]),
  .page_reverse(active_view[4]),.focus(3'd0),.audio_peak(16'd0),.audio_status(4'd0),.o_hs(oh),.o_vs(ov),.o_de(od),.o_rgb(rgb));
 integer ack_delay=10,waited=0,testcase,events=0,osd_seen=0;
 integer cycle=0,event_cycle=0,osd_margin=0;
 reg watching=0;
 always @(posedge clk)begin
  if(rst)begin waited<=0;mem_ack<=0;end
  else if(!mem_req)begin waited<=0;mem_ack<=0;end
  else if(waited>=ack_delay)mem_ack<=1;
  else waited<=waited+1;
  cycle=cycle+1;
  if(watching&&page_event)begin event_cycle=cycle;events=events+1;end
  if(watching&&overlay.osd.frame_start)begin
   osd_margin=cycle-event_cycle;
   if(events!=1||osd_margin<=0)$fatal(1,"commit event did not precedeOSD frame capture");
   #1;
   if(overlay.osd.page!==candidate[2:0]||overlay.osd.typed_count!==0||overlay.osd.typing_delay!==33)
    $fatal(1,"OSD missed first committedframe");
   osd_seen=osd_seen+1;
  end

 end
 task step;begin @(posedge clk);#3;@(negedge clk);end endtask
 initial begin
  for(testcase=0;testcase<3;testcase=testcase+1)begin
   watching=0;rst=1;commit_toggle=0;repeat(5)step;rst=0;step;
   // Preload only timing state, never output RGB or overlay state machine.
   timing.color_bar_m0.h_cnt=0;timing.color_bar_m0.v_cnt=8;
   timing.color_bar_m0.vs_reg=1;timing.color_bar_m0.vs_reg_d0=1;
   timing.video_vs_d0=1;timing.video_vs_d1=1;
   repeat(30)step;
   overlay.osd.typed_count=20;
   candidate=testcase==0 ? 5'd1 : testcase==1 ? 5'd18 : 5'd5;
   ack_delay=testcase==0 ? 10 : testcase==1 ? 400 : 1400;
   commit_toggle=1;events=0;osd_seen=0;watching=1;
   wait(osd_seen==1);watching=0;wait(od);step;
   if(!overlay.osd.swap_palette_ready)$fatal(1,"serialswap palette missed first activepixel");
   if(overlay.osd.page!==candidate[2:0]||active_view!==candidate||overlay.osd.seconds_fraction!==4)$fatal(1,"committed config mismatch");
   $display("COMMIT_PASS ACKdelay%0d clocks OSDmargin%0dclocks page%0d reverse%0d captiondelay%0d",ack_delay,osd_margin,active_view[2:0],active_view[4],overlay.osd.typing_delay);
  end
  $display("TEST_PASS actualdisplay_commit + real640x480timing + overlays: first committedframe reaction,captionreset,fraction capture,10/400/1400clockACKdelays");$finish;
 end
 initial begin #10000000;$fatal(1,"commitoverlay watchdog");end
endmodule
