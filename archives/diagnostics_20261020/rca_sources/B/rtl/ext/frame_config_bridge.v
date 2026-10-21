// Bundled-data mailbox. Source payload remains fixed through destination capture.
// Destination applies only complete snapshots on a video frame boundary.
module frame_config_bridge #(
 parameter WIDTH=47,
 parameter [WIDTH-1:0] RESET_VALUE=0
)(
 input src_clk,src_rst,
 input [WIDTH-1:0] src_config,
 input dst_clk,dst_rst,dst_frame,
 output reg [WIDTH-1:0] dst_config
);
 reg [WIDTH-1:0] payload,shadow;
 reg request,ack;
 (* async_reg="true" *) reg [1:0] ack_sync,req_sync;
 reg [1:0] settle;
 always @(posedge src_clk) begin
  if(src_rst) begin payload<=RESET_VALUE;request<=0;ack_sync<=0;end
  else begin
   ack_sync<={ack_sync[0],ack};
   if(ack_sync[1]==request && src_config!=payload) begin
    payload<=src_config;request<=~request;
   end
  end
 end
 always @(posedge dst_clk) begin
  if(dst_rst) begin
   shadow<=RESET_VALUE;dst_config<=RESET_VALUE;req_sync<=0;ack<=0;settle<=0;
  end else begin
   req_sync<={req_sync[0],request};
   if(req_sync[1]!=ack) begin
    if(settle==2)begin shadow<=payload;ack<=req_sync[1];settle<=0;end
    else settle<=settle+1'b1;
   end else settle<=0;
   if(dst_frame)dst_config<=shadow;
  end
 end
endmodule
