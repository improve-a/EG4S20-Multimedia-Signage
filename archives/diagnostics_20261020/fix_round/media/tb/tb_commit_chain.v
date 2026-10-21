`timescale 1ns/1ps
// Short boundary test for the real display_commit + video_transition chain.
// The source model follows legacy_exhibit_media's COVER -> LOAD -> COMMIT
// sequence: request cover, wait for cover ack, wait a load delay, publish a
// commit toggle, wait for the commit ack.  All source-side signals are in the
// sd_card_clk domain; video_transition/display_commit are in video_clk.
//
// PHASE_NS sweeps the sd clock phase against the 25 MHz video clock.
// FAULT_AFTER_COMMITS injects a sticky fifo_fault after N successful commits.
module tb_commit_chain;
 parameter PHASE_NS = 0;
 parameter integer FAULT_AFTER_COMMITS = 1;
 parameter integer LOAD_CYCLES = 300;   // sd clocks between cover ack and commit

 reg video_clk=0, sd_clk=0, rst=1;
 always #20 video_clk=~video_clk;                 // 25 MHz
 initial begin #(PHASE_NS); forever #5 sd_clk=~sd_clk; end  // 100 MHz

 // video timing model: 400-cycle frames, 8 active pixels
 reg vs=0, hs=0, de=0;
 reg [9:0] vc=0;
 reg [23:0] i_rgb=24'h123456;
 reg frame_start=0;
 always @(posedge video_clk) begin
  frame_start<=0;
  if(!rst) begin
   if(vc==399) begin
    vc<=0; vs<=1; de<=0; frame_start<=1;
   end else begin
    vc<=vc+1'b1;
    vs<=0;
    de <= (vc>=100 && vc<108);
   end
  end else begin
   vc<=0; vs<=0; de<=0;
  end
 end
 // one-cycle delayed image for comparison with the transition output
 reg de_d=0; reg [23:0] rgb_d=0;
 always @(posedge video_clk) begin de_d<=de; rgb_d<=i_rgb; end

 // raw read request model identical to video_timing_data: set on vs rise,
 // clear on ack.
 reg raw_req=0;
 wire raw_ack;
 always @(posedge video_clk) begin
  if(rst) raw_req<=0;
  else if(frame_start) raw_req<=1;
  else if(raw_ack) raw_req<=0;
 end
 // memory read ack: 3 video cycles after request, held while request high
 reg [2:0] ack_dly=0; wire mem_read_req; reg mem_ack=0;
 always @(posedge video_clk) begin
  if(rst) begin ack_dly<=0; mem_ack<=0; end
  else begin
   if(mem_read_req) begin
    if(ack_dly<3) begin ack_dly<=ack_dly+1'b1; mem_ack<=0; end
    else mem_ack<=1;
   end else begin ack_dly<=0; mem_ack<=0; end
  end
 end

 // sticky fault, injected by the checker
 reg fault=0;

 wire [11:0] active_buf;
 wire commit_ack_toggle;
 wire forwarded_toggle, transition_busy;
 reg cover_req=0, commit_toggle=0;
 reg [11:0] candidate=12'h001;
 wire cover_ack, o_hs,o_vs,o_de; wire [23:0] o_rgb;
 display_commit #(.BUFFER_BITS(12),.REQUIRE_INITIAL_COMMIT(1)) commit (
  .video_clk(video_clk),.rst(rst),.raw_read_req(raw_req),.raw_read_ack(raw_ack),
  .mem_read_req(mem_read_req),.mem_read_ack(mem_ack),
  .commit_toggle_async(forwarded_toggle),.candidate_async(candidate),
  .fault_async(fault),.active_buf(active_buf),.commit_ack_toggle(commit_ack_toggle));

 video_transition #(.COVER_BEFORE_LOAD(1),.CLOSE_STEP(54),.OPEN_STEP(36),.MASK_COLOR(24'h151615)) tr (
  .clk(video_clk),.rst(rst),.i_hs(hs),.i_vs(vs),.i_de(de),.i_rgb(i_rgb),
  .enable(1'b1),.mode(2'd0),.frame_start(frame_start),
  .candidate_toggle_async(commit_toggle),.commit_ack_toggle(commit_ack_toggle),
  .display_fault_async(fault),
  .cover_request_toggle_async(cover_req),.cover_ack_toggle(cover_ack),
  .forwarded_commit_toggle(forwarded_toggle),.o_hs(o_hs),.o_vs(o_vs),.o_de(o_de),.o_rgb(o_rgb),
  .transition_busy(transition_busy));

 // Source-side (sd domain) 2FF synchronizers, as in the real design.
 reg [1:0] cover_ack_s=0, commit_ack_s=0, busy_s=0;
 always @(posedge sd_clk) begin
  if(rst) begin cover_ack_s<=0; commit_ack_s<=0; busy_s<=0; end
  else begin
   cover_ack_s<={cover_ack_s[0],cover_ack};
   commit_ack_s<={commit_ack_s[0],commit_ack_toggle};
   busy_s<={busy_s[0],transition_busy};
  end
 end

 // Simulation control / checks
 integer commits_done=0, i, errors=0;
 integer t_cover=0, t_commit1=0, t_ack1=0, t_fault=0, t_commit2=0;
 reg [23:0] seen_mask=0, seen_img=0;
 initial begin
  #200 rst=0;
  // wait until the transition is out of reset and in IDLE
  @(posedge sd_clk); @(posedge sd_clk);
  // 1) cover request, wait for ack
  cover_req=~cover_req; t_cover=$time;
  i=0; while(cover_ack_s[1]!==cover_req && i<200000) begin @(posedge sd_clk); i=i+1; end
  if(cover_ack_s[1]!==cover_req) begin $display("FAIL cover ack timeout"); errors=errors+1; end
  else $display("PASS cover ack at %0t (sd cycles=%0d)",$time,i);
  // 2) load delay, then commit
  repeat(LOAD_CYCLES) @(posedge sd_clk);
  commit_toggle=~commit_toggle; t_commit1=$time;
  i=0; while(commit_ack_s[1]!==commit_toggle && i<200000) begin @(posedge sd_clk); i=i+1; end
  if(commit_ack_s[1]!==commit_toggle) begin $display("FAIL first commit ack timeout"); errors=errors+1; end
  else begin
   t_ack1=$time;
   $display("PASS first commit ack at %0t (sd cycles=%0d) active_buf=%h",$time,i,active_buf);
   if(active_buf!==12'h001) begin $display("FAIL active_buf=%h expected 001",active_buf); errors=errors+1; end
   commits_done=1;
  end
  // 3) wait for the transition to finish revealing, then sample pixels
  i=0; while(busy_s[1] && i<200000) begin @(posedge sd_clk); i=i+1; end
  repeat(50) @(posedge video_clk);
  // image must be visible after reveal
  i=0;
  while(i<5) begin
   @(posedge video_clk);
   if(o_de) begin
    if(o_rgb!==rgb_d) begin $display("FAIL image pixel %h != %h",o_rgb,rgb_d); errors=errors+1; end
    else seen_img=seen_img+1;
    i=i+1;
   end
  end
  $display("image pixels checked=%0d",seen_img);
  // 4) sticky fault, then a second commit.  The fault must mask the image and
  //    no second commit may be acknowledged.
  fault=1; t_fault=$time;
  repeat(5) @(posedge video_clk);
  i=0;
  while(i<5) begin
   @(posedge video_clk);
   if(o_de) begin
    if(o_rgb!==24'h151615) begin $display("FAIL fault pixel %h != mask",o_rgb); errors=errors+1; end
    else seen_mask=seen_mask+1;
    i=i+1;
   end
  end
  $display("mask pixels checked=%0d",seen_mask);
  // try a second cover/commit while faulted
  cover_req=~cover_req; i=0;
  while(cover_ack_s[1]!==cover_req && i<20000) begin @(posedge sd_clk); i=i+1; end
  if(cover_ack_s[1]!==cover_req) $display("INFO no cover ack while faulted (expected)");
  candidate=12'h002; commit_toggle=~commit_toggle; t_commit2=$time;
  i=0; while(commit_ack_s[1]!==commit_toggle && i<20000) begin @(posedge sd_clk); i=i+1; end
  if(commit_ack_s[1]===commit_toggle) begin $display("FAIL second commit acked while faulted"); errors=errors+1; end
  else $display("PASS second commit not acked while faulted");
  if(active_buf!==12'h001) begin $display("FAIL active_buf changed while faulted: %h",active_buf); errors=errors+1; end
  $display("SUMMARY PHASE_NS=%0d errors=%0d commits=%0d",PHASE_NS,errors,commits_done);
  $finish;
 end
 // timeout
 initial begin #5000000; $display("FAIL global timeout"); $finish; end
endmodule
