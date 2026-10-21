// HFXL v1 locator in sequential BMP header bytes 80..111.
// The validated 640x480/offset<=1MiB contract bounds scene_offset below 2MiB.
// Aligned fields retain their useful bits; every discarded bit is checked.
module html_resource_locator(
 input clk,rst,header_start,byte_valid,input [9:0] byte_index,input [7:0] byte_data,
 input [31:0] file_len,pixel_offset,pixel_end,dib_size,width,height,
 output reg valid,output present,
 output [31:0] scene_offset,payload_bytes,word_base,output reg [31:0] set_id,
 output [15:0] page_index
);
 reg [11:0] scene_sector,payload_blocks;
 reg [12:0] base_blocks;
 reg [2:0] page;
 reg magic_ok,magic_done,constants_ok,constants_done,field_bits_ok;
 reg check_constant;reg [7:0] expected_constant;
 always @*begin
  check_constant=1;expected_constant=0;
  case(byte_index)
   84:expected_constant=1;
   86:expected_constant=32;
   102:expected_constant=6;
   85,87,103,108,109,110,111:expected_constant=0;
   default:check_constant=0;
  endcase
 end
 assign present=magic_ok&&magic_done;
 assign scene_offset={11'd0,scene_sector,9'd0};
 assign payload_bytes={10'd0,payload_blocks,10'd0};
 assign word_base={11'd0,base_blocks,8'd0};
 assign page_index={13'd0,page};
 reg [32:0] aligned_pixel_end;
 reg [21:0] scene_end,memory_end;
 reg format_ok,layout_ok,extent_ok;
 always @(posedge clk)begin
  if(rst||header_start)begin
   magic_ok<=1;magic_done<=0;constants_ok<=1;constants_done<=0;field_bits_ok<=1;
   scene_sector<=0;payload_blocks<=0;base_blocks<=0;page<=0;set_id<=0;
  end else if(byte_valid)begin
   if(check_constant && byte_data!=expected_constant)constants_ok<=0;
   if(byte_index==111)constants_done<=1;
   case(byte_index)
    80:if(byte_data!=8'h48)magic_ok<=0;
    81:if(byte_data!=8'h46)magic_ok<=0;
    82:if(byte_data!=8'h58)magic_ok<=0;
    83:begin if(byte_data!=8'h4c)magic_ok<=0;magic_done<=1;end
    88,91,92,95,96,99,101:if(byte_data!=0)field_bits_ok<=0;
    89:begin scene_sector[6:0]<=byte_data[7:1];if(byte_data[0])field_bits_ok<=0;end
    90:begin scene_sector[11:7]<=byte_data[4:0];if(byte_data[7:5]!=0)field_bits_ok<=0;end
    93:begin payload_blocks[5:0]<=byte_data[7:2];if(byte_data[1:0]!=0)field_bits_ok<=0;end
    94:begin payload_blocks[11:6]<=byte_data[5:0];if(byte_data[7:6]!=0)field_bits_ok<=0;end
    97:base_blocks[7:0]<=byte_data;
    98:begin base_blocks[12:8]<=byte_data[4:0];if(byte_data[7:5]!=0)field_bits_ok<=0;end
    100:begin page<=byte_data[2:0];if(byte_data[7:3]!=0)field_bits_ok<=0;end
    104:set_id[7:0]<=byte_data;105:set_id[15:8]<=byte_data;
    106:set_id[23:16]<=byte_data;107:set_id[31:24]<=byte_data;
   endcase
  end
 end
 // Keep the original validation pipeline latency. The caller consumes valid
 // only after the complete sequential512byte header, well after byte111.
 always @(posedge clk)begin
  if(rst||header_start)begin
   aligned_pixel_end<=0;scene_end<=0;memory_end<=0;
   format_ok<=0;layout_ok<=0;extent_ok<=0;valid<=0;
  end else begin
   aligned_pixel_end<=({1'b0,pixel_end}+33'd511)&33'h1fffffe00;
   scene_end<={1'b0,scene_sector,9'd0}+{payload_blocks,10'd0};
   memory_end<={1'b0,base_blocks,8'd0}+{2'b00,payload_blocks,8'd0};
   format_ok<=present && constants_ok && constants_done && field_bits_ok &&
    page<6 && width==640 && height==480 && dib_size==40;
   layout_ok<=pixel_offset>=512 && pixel_offset<=1048576 &&
    payload_blocks>=4 && payload_blocks<=2048;
   extent_ok<=scene_offset==aligned_pixel_end &&
    file_len=={10'd0,scene_end} && memory_end<=1843200;
   valid<=format_ok&&layout_ok&&extent_ok;
  end
 end
endmodule
