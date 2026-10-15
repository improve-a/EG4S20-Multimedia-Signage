// HTML_FIDELITY_INTEGRATED
// Source holds the candidate until acknowledgement. Synchronize the event, then
// allow an extra destination cycle before sampling the bundled address. A source
// acknowledgement releases the old front buffer only after the reader accepts.
module display_commit #(parameter BUFFER_BITS=2)(
 input video_clk, rst,
 input raw_read_req,
 output reg raw_read_ack,
 output reg mem_read_req,
 input mem_read_ack,
 input commit_toggle_async,
 input [BUFFER_BITS-1:0] candidate_async,
 input fault_async,
 output reg [BUFFER_BITS-1:0] active_buf,
 output reg commit_ack_toggle
);
 (* async_reg = "true" *) reg [1:0] commit_sync, fault_sync;
 reg [BUFFER_BITS-1:0] candidate_meta, candidate_sync, previous_buf;
 reg [2:0] state;
 reg [1:0] settle;
 reg accepted_toggle,accept_commit;
 localparam IDLE=0,SETTLE=1,WAIT_ACK=2,DRAIN=3,ABORT_DRAIN=4;
 always @(posedge video_clk or posedge rst) begin
  if(rst) begin
   commit_sync<=0;fault_sync<=0;candidate_meta<=0;candidate_sync<=0;
   state<=IDLE;settle<=0;accepted_toggle<=0;accept_commit<=0;previous_buf<=0;
   raw_read_ack<=0;mem_read_req<=0;active_buf<=0;commit_ack_toggle<=0;
  end else begin
   commit_sync<={commit_sync[0],commit_toggle_async};
   fault_sync<={fault_sync[0],fault_async};
   candidate_meta<=candidate_async;candidate_sync<=candidate_meta;
   case(state)
    IDLE: if(raw_read_req) begin
     accept_commit<=(commit_sync[1]!=commit_ack_toggle) && !fault_sync[1];
     accepted_toggle<=commit_sync[1];previous_buf<=active_buf;
     settle<=3;state<=SETTLE;
    end
    SETTLE: begin
     if(fault_sync[1]) begin active_buf<=previous_buf;accept_commit<=0;end
     else if(settle==2 && accept_commit)active_buf<=candidate_sync;
     if(settle!=0)settle<=settle-1'b1;
     else begin mem_read_req<=1;state<=WAIT_ACK;end
    end
    WAIT_ACK: if(mem_read_ack)begin
     mem_read_req<=0;
     if(accept_commit && fault_sync[1])begin
      // The candidate may already have reached SDRAM. Drain this handshake and
      // explicitly relatch the old base before acknowledging video timing.
      active_buf<=previous_buf;accept_commit<=0;state<=ABORT_DRAIN;
     end else begin
      raw_read_ack<=1;
      if(accept_commit)commit_ack_toggle<=accepted_toggle;
      state<=DRAIN;
     end
    end
    ABORT_DRAIN: if(!mem_read_ack)begin settle<=2;state<=SETTLE;end
    DRAIN: if(!raw_read_req && !mem_read_ack) begin raw_read_ack<=0;state<=IDLE;end
    default:state<=IDLE;
   endcase
  end
 end
endmodule
