// HFXL v1 locator in BMP bytes 80..111. Ordinary BMP validation is separate.
// The explicit extension is accepted only for the authored six-page 640x480 set.
module html_resource_locator(
 input clk,rst,header_start,byte_valid,input [9:0] byte_index,input [7:0] byte_data,
 input [31:0] file_len,pixel_offset,pixel_end,dib_size,width,height,
 output reg valid,output present,
 output reg [31:0] scene_offset,payload_bytes,word_base,set_id,
 output reg [15:0] page_index
);
 reg [31:0] magic;
 reg constants_ok,constants_done;
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
 assign present=magic==32'h4c584648;
 reg [32:0] aligned_pixel_end,scene_end,memory_end;
 reg format_ok,layout_ok,extent_ok;
 always @(posedge clk)begin
  if(rst||header_start)begin
   magic<=0;constants_ok<=1;constants_done<=0;scene_offset<=0;payload_bytes<=0;
   word_base<=0;page_index<=0;set_id<=0;
  end else if(byte_valid)begin
   // Callers deliver one sequential 512-byte sector; constants are checked
   // once on arrival and used only after the complete header transport.
   if(check_constant && byte_data!=expected_constant)constants_ok<=0;
   if(byte_index==111)constants_done<=1;
   case(byte_index)
    80:magic[7:0]<=byte_data;81:magic[15:8]<=byte_data;
    82:magic[23:16]<=byte_data;83:magic[31:24]<=byte_data;
    88:scene_offset[7:0]<=byte_data;89:scene_offset[15:8]<=byte_data;
    90:scene_offset[23:16]<=byte_data;91:scene_offset[31:24]<=byte_data;
    92:payload_bytes[7:0]<=byte_data;93:payload_bytes[15:8]<=byte_data;
    94:payload_bytes[23:16]<=byte_data;95:payload_bytes[31:24]<=byte_data;
    96:word_base[7:0]<=byte_data;97:word_base[15:8]<=byte_data;
    98:word_base[23:16]<=byte_data;99:word_base[31:24]<=byte_data;
    100:page_index[7:0]<=byte_data;101:page_index[15:8]<=byte_data;
    104:set_id[7:0]<=byte_data;105:set_id[15:8]<=byte_data;
    106:set_id[23:16]<=byte_data;107:set_id[31:24]<=byte_data;
   endcase
  end
 end
 // Header transport leaves at least 400 clocks after the last locator byte.
 // Pipeline extent arithmetic instead of adding a 100MHz validation chain.
 always @(posedge clk)begin
  if(rst||header_start)begin
   aligned_pixel_end<=0;scene_end<=0;memory_end<=0;
   format_ok<=0;layout_ok<=0;extent_ok<=0;valid<=0;
  end else begin
   aligned_pixel_end<=({1'b0,pixel_end}+33'd511)&33'h1fffffe00;
   scene_end<={1'b0,scene_offset}+{1'b0,payload_bytes};
   memory_end<={1'b0,word_base}+{3'b000,payload_bytes[31:2]};
   format_ok<=magic==32'h4c584648 && constants_ok && constants_done &&
    page_index<6 &&
    width==640 && height==480 && dib_size==40;
   layout_ok<=pixel_offset>=512 && pixel_offset<=1048576 &&
    scene_offset[8:0]==0 && payload_bytes[9:0]==0 &&
    payload_bytes>=4096 && payload_bytes<=2097152 && word_base[7:0]==0;
   extent_ok<=!aligned_pixel_end[32] && scene_offset==aligned_pixel_end[31:0] &&
    !scene_end[32] && file_len==scene_end[31:0] && memory_end<=1843200;
   valid<=format_ok&&layout_ok&&extent_ok;
  end
 end
endmodule
