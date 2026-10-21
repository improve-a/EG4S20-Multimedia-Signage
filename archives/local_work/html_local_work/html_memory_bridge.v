// Bundled configuration is held by display_commit before the reader request.
// The existing request handshake gives two synchronizer stages plus settling.
module html_memory_bridge(
 input mem_clk,rst,video_read_req,
 input [3:0] active_view,input [1:0] zoom,transition_mode,input [2:0] focus,
 input panels_ready,
 input raw_read_en,output read_en,output [20:0] read_addr,
 input response,input [31:0] memory_data,
 output [31:0] pixel_data,output fault
);
 (* async_reg="true" *) reg [2:0] request_sync;
 reg request_previous;
 (* async_reg="true" *) reg [11:0] config_meta,config_sync;
 wire frame_latch=request_sync[2]&&!request_previous;
 wire packed_pixel,half_pixel,black_pixel;
 always @(posedge mem_clk)begin
  if(rst)begin request_sync<=0;request_previous<=0;config_meta<=0;config_sync<=0;end
  else begin
   request_sync<={request_sync[1:0],video_read_req};request_previous<=request_sync[2];
   config_meta<={panels_ready,transition_mode,focus,zoom,active_view};config_sync<=config_meta;
  end
 end
 exhibit_viewport #(.ENABLE_TRANSITION(1)) mapper(
  .clk(mem_clk),.rst(rst),.frame_latch(frame_latch),.pixel_step(raw_read_en),
  .page_index(config_sync[2:0]),.dual_enable(config_sync[3]),.zoom(config_sync[5:4]),
  .focus(config_sync[8:6]),.transition_mode(config_sync[10:9]),.panels_ready(config_sync[11]),
  .mapped_addr(read_addr),.mapped_valid(read_en),.mapped_packed(packed_pixel),
  .mapped_half(half_pixel),.mapped_black(black_pixel));
 html_read_tags tags(.clk(mem_clk),.rst(rst),.request(read_en),.packed_pixel(packed_pixel),
  .half_pixel(half_pixel),.black_pixel(black_pixel),.response(response),
  .memory_data(memory_data),.pixel_data(pixel_data),.fault(fault));
endmodule
