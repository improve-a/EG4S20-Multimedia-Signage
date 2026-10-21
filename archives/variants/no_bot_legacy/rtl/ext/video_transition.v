// One registered pixel/sync cycle, using only the current scanout pixel and a
// constant mask (plus the original one-line slide RAM). In pre-load mode the
// source first requests cover, waits for cover_ack_toggle, loads the back
// buffer, and then publishes candidate_toggle_async. Actual reader acceptance
// still gates reveal. Pre-load mode observes one complete post-ACK frame with
// no FIFO fault before opening. Neither video timing nor audio is stopped.
module video_transition #(
 parameter WIDTH=640,
 parameter STEP=32,
 parameter COVER_BEFORE_LOAD=0,
 parameter CLOSE_STEP=STEP, OPEN_STEP=STEP,
 parameter [23:0] MASK_COLOR=24'd0
)(
 input wire clk,rst,i_hs,i_vs,i_de,
 input wire [23:0] i_rgb,
 input wire enable,
 input wire [1:0] mode,
 input wire frame_start,
 input wire candidate_toggle_async,
 input wire commit_ack_toggle,
 input wire display_fault_async,
 input wire cover_request_toggle_async,
 output reg cover_ack_toggle,
 output reg forwarded_commit_toggle,
 output reg o_hs,o_vs,o_de,
 output wire [23:0] o_rgb,
 output wire transition_busy
);
 localparam IDLE=3'd0,CLOSE=3'd1,WAIT_ACK=3'd2,OPEN=3'd3,WAIT_LOAD=3'd4;
 reg [2:0] phase;
 reg [1:0] locked_mode;
 reg accepted_cover,reveal_armed;
 reg [10:0] offset,x;
 reg prev_de,accepted_toggle;
 (* async_reg="true" *) reg [1:0] candidate_sync,cover_sync,display_fault_sync;
 wire [23:0] line_q;
 reg [23:0] base_rgb_q;
 reg sel_ram_q;
 wire [10:0] px=prev_de?x:11'd0;
 wire animated=phase!=IDLE;
 wire use_line_ram=i_de && animated && locked_mode==2 && offset!=0 &&
                   offset<WIDTH && px>=offset && px<WIDTH;
 assign o_rgb=sel_ram_q?line_q:base_rgb_q;
 assign transition_busy=animated || forwarded_commit_toggle!=commit_ack_toggle;
 // Power-of-two RAM depth and exact 10-bit port addresses keep bounds
 // selection logic outside TD's synchronous block-RAM inference template.
 // Only the guarded sel_ram_q consumes a read; offset zero bypasses the RAM.
 wire [10:0] line_read_index=px-offset;
 video_transition_line_ram line_store(.clk(clk),
  .write_enable(i_de && px<WIDTH),.write_addr(px[9:0]),.write_data(i_rgb),
  .read_addr(line_read_index[9:0]),.read_data(line_q));
 always @(posedge clk) begin
  if(rst)begin
   phase<=IDLE;locked_mode<=0;offset<=0;x<=0;prev_de<=0;
   accepted_toggle<=0;candidate_sync<=0;forwarded_commit_toggle<=0;
   accepted_cover<=0;cover_sync<=0;cover_ack_toggle<=0;
   reveal_armed<=0;display_fault_sync<=0;
   o_hs<=0;o_vs<=0;o_de<=0;base_rgb_q<=0;sel_ram_q<=0;
  end else begin
   candidate_sync<={candidate_sync[0],candidate_toggle_async};
   cover_sync<={cover_sync[0],cover_request_toggle_async};
   display_fault_sync<={display_fault_sync[0],display_fault_async};
   prev_de<=i_de;
   if(frame_start)x<=0;
   else if(i_de)x<=prev_de?x+1'b1:11'd1;
   else x<=0;
   // A sticky storage fault must never turn a covered, unready frame visible.
   // Legacy mode keeps its historical interface behavior.
   if(COVER_BEFORE_LOAD && display_fault_sync[1])begin
    offset<=WIDTH;phase<=WAIT_ACK;reveal_armed<=0;
   end else case(phase)
    IDLE: if(COVER_BEFORE_LOAD)begin
     if(cover_sync[1]!=accepted_cover &&
        forwarded_commit_toggle==commit_ack_toggle)begin
      accepted_cover<=cover_sync[1];reveal_armed<=0;
      locked_mode<=enable?mode:2'd0;offset<=0;phase<=CLOSE;
     end
    end else if(candidate_sync[1]!=accepted_toggle &&
                forwarded_commit_toggle==commit_ack_toggle)begin
     accepted_toggle<=candidate_sync[1];
     if(!enable || mode==0 || mode==3)
      forwarded_commit_toggle<=candidate_sync[1];
     else begin locked_mode<=mode;offset<=0;phase<=CLOSE;end
    end
    CLOSE: if(frame_start)begin
     if(offset+CLOSE_STEP>=WIDTH || locked_mode==0 || locked_mode==3)begin
      offset<=WIDTH;
      if(COVER_BEFORE_LOAD)begin cover_ack_toggle<=accepted_cover;phase<=WAIT_LOAD;end
      else begin forwarded_commit_toggle<=accepted_toggle;phase<=WAIT_ACK;end
     end else offset<=offset+CLOSE_STEP;
    end
    WAIT_LOAD: if(candidate_sync[1]!=accepted_toggle)begin
     accepted_toggle<=candidate_sync[1];
     forwarded_commit_toggle<=candidate_sync[1];phase<=WAIT_ACK;reveal_armed<=0;
    end
    WAIT_ACK: if(frame_start && commit_ack_toggle==forwarded_commit_toggle)begin
     // The old ACK clears/latches the reader; it is not a prefill-complete ACK.
     // First boundary starts a complete covered frame of the new front. Only
     // the following boundary may reveal, after its FIFO checks have settled.
     if(COVER_BEFORE_LOAD && !reveal_armed)reveal_armed<=1;
     else if(locked_mode==0 || locked_mode==3)begin offset<=0;phase<=IDLE;end
     else begin offset<=WIDTH>OPEN_STEP?WIDTH-OPEN_STEP:0;phase<=OPEN;end
    end
    OPEN: if(frame_start)begin
     if(offset<=OPEN_STEP)begin offset<=0;phase<=IDLE;end
     else offset<=offset-OPEN_STEP;
    end
    default:begin phase<=IDLE;offset<=0;end
   endcase
   o_hs<=i_hs;o_vs<=i_vs;o_de<=i_de;
   if(COVER_BEFORE_LOAD && display_fault_sync[1])begin
    sel_ram_q<=0;base_rgb_q<=MASK_COLOR;
   end else begin
    sel_ram_q<=use_line_ram;
    if(i_de && animated && (offset>=WIDTH || px<offset))base_rgb_q<=MASK_COLOR;
    else base_rgb_q<=i_rgb;
   end
  end
 end
endmodule

// Standard synchronous simple-dual-port RAM. No reset or data mux is attached
// to read_data. Extra locations 640..1023 are padding, never consumed by RGB.
// Reading an unwritten location during blanking is harmless: the parent output
// mux is disabled for all invalid/unused reads. Supports WIDTH <=1024.
module video_transition_line_ram(
 input wire clk,write_enable,
 input wire [9:0] write_addr,read_addr,
 input wire [23:0] write_data,
 output reg [23:0] read_data
);
 reg [23:0] memory [0:1023]; /* fehdl force_ram=1, ram_style="bram" */
 always @(posedge clk) begin
  if(write_enable)memory[write_addr]<=write_data;
  read_data<=memory[read_addr];
 end
endmodule
