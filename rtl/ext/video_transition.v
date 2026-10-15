// One registered pixel/sync cycle. The commit request is forwarded only after
// the old image is fully black. The real display_commit acknowledgement gates
// opening, so buffer selection and SD ownership remain with display_commit.
module video_transition #(
 parameter WIDTH=640,
 parameter STEP=32
)(
 input wire clk,rst,i_hs,i_vs,i_de,
 input wire [23:0] i_rgb,
 input wire enable,
 input wire [1:0] mode,
 input wire frame_start,
 input wire candidate_toggle_async,
 input wire commit_ack_toggle,
 output reg forwarded_commit_toggle,
 output reg o_hs,o_vs,o_de,
 output wire [23:0] o_rgb,
 output wire transition_busy
);
 localparam IDLE=2'd0,CLOSE=2'd1,WAIT_ACK=2'd2,OPEN=2'd3;
 reg [1:0] phase,locked_mode;
 reg [10:0] offset,x;
 reg prev_de,accepted_toggle;
 (* async_reg="true" *) reg [1:0] candidate_sync;
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
   o_hs<=0;o_vs<=0;o_de<=0;base_rgb_q<=0;sel_ram_q<=0;
  end else begin
   candidate_sync<={candidate_sync[0],candidate_toggle_async};
   prev_de<=i_de;
   if(frame_start)x<=0;
   else if(i_de)x<=prev_de?x+1'b1:11'd1;
   else x<=0;
   case(phase)
    IDLE: if(candidate_sync[1]!=accepted_toggle &&
              forwarded_commit_toggle==commit_ack_toggle)begin
     accepted_toggle<=candidate_sync[1];
     if(!enable || mode==0 || mode==3)begin
      forwarded_commit_toggle<=candidate_sync[1];
     end else begin
      locked_mode<=mode;offset<=0;phase<=CLOSE;
     end
    end
    CLOSE: if(frame_start)begin
     if(offset+STEP>=WIDTH)begin
      offset<=WIDTH;forwarded_commit_toggle<=accepted_toggle;phase<=WAIT_ACK;
     end else offset<=offset+STEP;
    end
    WAIT_ACK: if(frame_start && commit_ack_toggle==forwarded_commit_toggle)begin
     offset<=WIDTH>STEP?WIDTH-STEP:0;phase<=OPEN;
    end
    OPEN: if(frame_start)begin
     if(offset<=STEP)begin offset<=0;phase<=IDLE;end
     else offset<=offset-STEP;
    end
   endcase
   o_hs<=i_hs;o_vs<=i_vs;o_de<=i_de;
   sel_ram_q<=use_line_ram;
   if(i_de && animated && (offset>=WIDTH || px<offset))base_rgb_q<=0;
   else base_rgb_q<=i_rgb;
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
