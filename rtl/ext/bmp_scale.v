// One source scanline, no frame store. Input/output are BMP bottom-up order;
// frame_fifo_write WRITE_V_FLIP=1 therefore restores the normal display order.
// Integer 1x/2x nearest-neighbour preserves aspect ratio and centers in 640x480.
module bmp_scale #(parameter PIXEL_PERIOD=16)(
 input clk, rst, start, input [9:0] source_width, source_height,
 input [1:0] scale_mode, input source_valid, input [23:0] source_pixel,
 output source_ready, output reg pixel_valid, output reg [23:0] pixel,
 output reg done
);
 localparam IDLE=0, SETUP=1, BOTTOM=2, COLLECT=3, IMAGE=4, TOP=5;
 reg [2:0] state;
 reg [23:0] line_mem [0:639];
 reg [23:0] line_q;
 reg [9:0] width_l, height_l, image_width, image_height, left_bar, bottom_bar;
 reg [9:0] input_x, source_y, canvas_x, canvas_y;
 reg double_size, repeat_row;
 reg [7:0] pace;
 wire [9:0] relative_x=canvas_x-left_bar;
 wire [9:0] line_addr=double_size ? {1'b0,relative_x[9:1]} : relative_x;
 wire inside_image=(canvas_x>=left_bar)&&(canvas_x<left_bar+image_width);
 assign source_ready=(state==COLLECT);
 // Synchronous read permits a single true block-RAM scanline. canvas_x remains
 // stable for PIXEL_PERIOD clocks, so line_q is settled before each output.
 always @(posedge clk) begin
  if(source_valid && source_ready) line_mem[input_x]<=source_pixel;
  if(state==IMAGE && inside_image) line_q<=line_mem[line_addr];
 end
 always @(posedge clk) begin
  if(rst) begin
   state<=IDLE;pixel_valid<=0;pixel<=0;done<=0;pace<=0;
   width_l<=0;height_l<=0;image_width<=0;image_height<=0;
   left_bar<=0;bottom_bar<=0;input_x<=0;source_y<=0;
   canvas_x<=0;canvas_y<=0;double_size<=0;repeat_row<=0;
  end else begin
   pixel_valid<=0;done<=0;
   if(start) begin
    width_l<=source_width;height_l<=source_height;
    double_size<=(scale_mode!=1)&&(source_width<=320)&&(source_height<=240);
    state<=SETUP;pace<=0;input_x<=0;source_y<=0;canvas_x<=0;canvas_y<=0;repeat_row<=0;
   end else case(state)
    SETUP: begin
     image_width<=double_size ? (width_l<<1) : width_l;
     image_height<=double_size ? (height_l<<1) : height_l;
     left_bar<=(640-(double_size ? (width_l<<1) : width_l))>>1;
     bottom_bar<=(481-(double_size ? (height_l<<1) : height_l))>>1;
     if((double_size ? (height_l<<1) : height_l)==480) state<=COLLECT;
     else state<=BOTTOM;
    end
    COLLECT: if(source_valid) begin
     if(input_x==width_l-1) begin input_x<=0;state<=IMAGE;pace<=0;canvas_x<=0;end
     else input_x<=input_x+1'b1;
    end
    BOTTOM,IMAGE,TOP: begin
     if(pace==PIXEL_PERIOD-1) begin
      pace<=0;pixel_valid<=1;
      pixel<=(state==IMAGE && inside_image) ? line_q : 24'd0;
      if(canvas_x==639) begin
       canvas_x<=0;canvas_y<=canvas_y+1'b1;
       if(canvas_y==479) begin state<=IDLE;done<=1;end
       else if(state==BOTTOM && canvas_y+1==bottom_bar) state<=COLLECT;
       else if(state==IMAGE) begin
        if(double_size && !repeat_row) repeat_row<=1;
        else begin
         repeat_row<=0;
         if(source_y==height_l-1) state<=TOP;
         else begin source_y<=source_y+1'b1;state<=COLLECT;end
        end
       end
      end else canvas_x<=canvas_x+1'b1;
     end else pace<=pace+1'b1;
    end
    default: state<=IDLE;
   endcase
  end
 end
endmodule

// Buffer a complete sector before parsing it. Pausing the parser while a line
// is emitted cannot lose SPI bytes, and the next sector is requested only after
// the buffer has been consumed. Header reread follows the legacy write handshake.
module bmp_scale_read #(parameter TIMEOUT_CYCLES=200_000_000)(
 input clk,rst, output ready,
 input scan_start, input [31:0] scan_start_sector,scan_max_sector,
 input [3:0] scan_target_count,
 output reg scan_done,scan_found_valid, output reg [31:0] scan_found_sector,
 output reg [3:0] scan_found_total,
 input load_start,load_abort,input [31:0] load_sector,input [1:0] scale_mode,
 input sd_init_done,output reg [3:0] state_code,
 output reg write_req,input write_req_ack,
 output reg sd_sec_read,output reg [31:0] sd_sec_read_addr,
 input [7:0] sd_sec_read_data,input sd_sec_read_data_valid,
 input sd_sec_read_end,sd_sec_read_error,
 output reg load_done,output reg [3:0] error_code,
 output bmp_data_wr_en,output [23:0] bmp_data
);
 localparam IDLE=0,HREQ=1,HRECV=2,HCHECK=3,WAIT_ACK=4,DREQ=5,DRECV=6,PARSE=7,DRAIN=8;
 reg [3:0] state;
 reg scanning;
 reg [1:0] mode_l;
 reg [31:0] start_sector, file_len,pixel_offset,dib_size,width,height,compression;
 reg [15:0] planes,bit_count;
 reg [15:0] signature;
 reg [9:0] receive_count,parse_index;
 reg [7:0] sector_mem [0:511];
 reg [31:0] file_position,row_position;
 reg [1:0] component;
 reg [23:0] source_pixel;
 reg source_valid,scale_start;
 wire source_ready,scale_valid,scale_done;
 wire [23:0] scale_pixel;
 reg [31:0] timeout_count;
 // Header bytes are stable hundreds of clocks before HCHECK. Stage the
 // arithmetic to keep the wide validation out of a single 100MHz path.
 reg [11:0] rgb_row_narrow,row_stride_narrow;
 reg [20:0] image_bytes;
 reg [32:0] pixel_end_wide,next_sector,last_sector;
 reg [31:0] file_sectors,max_file_len;
 wire [31:0] rgb_row={20'd0,rgb_row_narrow};
 wire [31:0] row_stride={20'd0,row_stride_narrow};
 wire [31:0] pixel_end=pixel_end_wide[31:0];
 always @(posedge clk) begin
  if(rst) begin
   rgb_row_narrow<=0;row_stride_narrow<=0;image_bytes<=0;
   pixel_end_wide<=0;file_sectors<=0;next_sector<=0;last_sector<=0;max_file_len<=0;
  end else begin
   rgb_row_narrow<=({2'd0,width[9:0]}<<1)+{2'd0,width[9:0]};
   row_stride_narrow<=(rgb_row_narrow+12'd3)&12'hffc;
   image_bytes<=row_stride_narrow*height[8:0];
   pixel_end_wide<={1'b0,pixel_offset}+{12'd0,image_bytes};
   max_file_len<=pixel_end+32'd65536;
   file_sectors<=(file_len+32'd511)>>9;
   next_sector<={1'b0,sd_sec_read_addr}+{1'b0,file_sectors};
   last_sector<={1'b0,start_sector}+{1'b0,file_sectors}-1'b1;
  end
 end
 // Field comparators and final acceptance are registered independently.
 // In the fastest legal transport, byte33 precedes the decision by478 clocks;
 // this pipeline has ample settle time without altering any header bound.
 reg [32:0] dib_end;
 reg signature_ok,width_ok,height_ok,planes_ok,bits_ok,compression_ok,dib_ok;
 reg offset_lower_ok,offset_upper_ok,extent_lower_ok,extent_upper_ok,end_ok,lba_ok;
 reg dimensions_ok,format_ok,offset_ok,extent_ok;
 reg header_ok;
 always @(posedge clk) begin
  if(rst) begin
   dib_end<=0;signature_ok<=0;width_ok<=0;height_ok<=0;planes_ok<=0;
   bits_ok<=0;compression_ok<=0;dib_ok<=0;offset_lower_ok<=0;offset_upper_ok<=0;
   extent_lower_ok<=0;extent_upper_ok<=0;end_ok<=0;lba_ok<=0;
   dimensions_ok<=0;format_ok<=0;offset_ok<=0;extent_ok<=0;header_ok<=0;
  end else begin
   dib_end<={1'b0,dib_size}+33'd14;
   signature_ok<=signature==16'h4d42;
   width_ok<=(width!=0)&&(width<=32'd640);
   height_ok<=(height!=0)&&(height<=32'd480);
   planes_ok<=planes==16'd1;bits_ok<=bit_count==16'd24;
   compression_ok<=compression==0;
   dib_ok<=(dib_size==32'd40)||(dib_size==32'd108)||(dib_size==32'd124);
   offset_lower_ok<=!dib_end[32]&&({1'b0,pixel_offset}>=dib_end);
   offset_upper_ok<=pixel_offset<=32'd1048576;
   extent_lower_ok<=file_len>=pixel_end;
   extent_upper_ok<=file_len<=max_file_len;
   end_ok<=!pixel_end_wide[32];lba_ok<=!last_sector[32];
   dimensions_ok<=signature_ok&&width_ok&&height_ok;
   format_ok<=planes_ok&&bits_ok&&compression_ok&&dib_ok;
   offset_ok<=offset_lower_ok&&offset_upper_ok;
   extent_ok<=extent_lower_ok&&extent_upper_ok&&end_ok&&lba_ok;
   header_ok<=dimensions_ok&&format_ok&&offset_ok&&extent_ok;
  end
 end
 wire [7:0] parsed_byte=sector_mem[parse_index[8:0]];
 wire is_rgb=(file_position>=pixel_offset)&&(file_position<pixel_end)&&(row_position<rgb_row);
 wire parser_can_step=!is_rgb || (source_ready&&!source_valid);
 wire active=(state>=WAIT_ACK);
 assign ready=(state==IDLE);
 assign bmp_data_wr_en=scale_valid&&active&&!load_abort&&!sd_sec_read_error;
 assign bmp_data=scale_pixel;
 bmp_scale scaler(.clk(clk),.rst(rst||load_abort||!sd_init_done||state==IDLE),
 .start(scale_start),.source_width(width[9:0]),.source_height(height[9:0]),
 .scale_mode(mode_l),.source_valid(source_valid),.source_pixel(source_pixel),
 .source_ready(source_ready),.pixel_valid(scale_valid),.pixel(scale_pixel),.done(scale_done));
 always @(posedge clk) if(state==DRECV && sd_sec_read_data_valid && receive_count<512)
  sector_mem[receive_count[8:0]]<=sd_sec_read_data;
 always @(posedge clk) begin
  if(rst) begin
   state<=IDLE;scanning<=0;mode_l<=0;start_sector<=0;
   scan_done<=0;scan_found_valid<=0;scan_found_sector<=0;scan_found_total<=0;
   write_req<=0;sd_sec_read<=0;sd_sec_read_addr<=0;load_done<=0;error_code<=0;state_code<=0;
   file_len<=0;pixel_offset<=0;dib_size<=0;width<=0;height<=0;compression<=0;
   planes<=0;bit_count<=0;signature<=0;receive_count<=0;parse_index<=0;
   file_position<=0;row_position<=0;component<=0;source_pixel<=0;source_valid<=0;
   scale_start<=0;timeout_count<=0;
  end else begin
   scan_found_valid<=0;load_done<=0;source_valid<=0;scale_start<=0;
   if(state==IDLE||sd_sec_read_data_valid||sd_sec_read_end||write_req_ack||
      scale_valid||(state==PARSE && parser_can_step)) timeout_count<=0;
   else if(timeout_count<TIMEOUT_CYCLES) timeout_count<=timeout_count+1'b1;
   if(load_abort||!sd_init_done) begin
    state<=IDLE;sd_sec_read<=0;write_req<=0;scan_done<=0;state_code<=0;
   end else if(state!=IDLE && (sd_sec_read_error||timeout_count>=TIMEOUT_CYCLES)) begin
    state<=IDLE;sd_sec_read<=0;write_req<=0;scan_done<=1;state_code<=14;
    error_code<=sd_sec_read_error?3:4;
   end else case(state)
    IDLE: begin
     sd_sec_read<=0;write_req<=0;state_code<=1;
     if(scan_start||load_start) begin
      scanning<=scan_start;
      // Discovery completion is sticky across image loads, as in legacy.
      // sd_card_bmp uses it to enable later manual/automatic selections.
      if(scan_start) begin scan_done<=0;scan_found_total<=0;end
      error_code<=0;
      mode_l<=scale_mode;start_sector<=scan_start?scan_start_sector:load_sector;
      sd_sec_read_addr<=scan_start?scan_start_sector:load_sector;state<=HREQ;
     end
    end
    HREQ: begin
     receive_count<=0;signature<=0;file_len<=0;pixel_offset<=0;dib_size<=0;
     width<=0;height<=0;planes<=0;bit_count<=0;compression<=0;
     sd_sec_read<=1;state<=HRECV;state_code<=2;
    end
    HRECV: begin
     if(sd_sec_read_data_valid) begin
      if(receive_count<513) receive_count<=receive_count+1'b1;
      case(receive_count)
       0:signature[7:0]<=sd_sec_read_data;1:signature[15:8]<=sd_sec_read_data;
       2:file_len[7:0]<=sd_sec_read_data;3:file_len[15:8]<=sd_sec_read_data;
       4:file_len[23:16]<=sd_sec_read_data;5:file_len[31:24]<=sd_sec_read_data;
       10:pixel_offset[7:0]<=sd_sec_read_data;11:pixel_offset[15:8]<=sd_sec_read_data;
       12:pixel_offset[23:16]<=sd_sec_read_data;13:pixel_offset[31:24]<=sd_sec_read_data;
       14:dib_size[7:0]<=sd_sec_read_data;15:dib_size[15:8]<=sd_sec_read_data;
       16:dib_size[23:16]<=sd_sec_read_data;17:dib_size[31:24]<=sd_sec_read_data;
       18:width[7:0]<=sd_sec_read_data;19:width[15:8]<=sd_sec_read_data;
       20:width[23:16]<=sd_sec_read_data;21:width[31:24]<=sd_sec_read_data;
       22:height[7:0]<=sd_sec_read_data;23:height[15:8]<=sd_sec_read_data;
       24:height[23:16]<=sd_sec_read_data;25:height[31:24]<=sd_sec_read_data;
       26:planes[7:0]<=sd_sec_read_data;27:planes[15:8]<=sd_sec_read_data;
       28:bit_count[7:0]<=sd_sec_read_data;29:bit_count[15:8]<=sd_sec_read_data;
       30:compression[7:0]<=sd_sec_read_data;31:compression[15:8]<=sd_sec_read_data;
       32:compression[23:16]<=sd_sec_read_data;33:compression[31:24]<=sd_sec_read_data;
      endcase
     end
     if(sd_sec_read_end) begin
      sd_sec_read<=0;
      if(receive_count+(sd_sec_read_data_valid?1:0)!=512) begin
       error_code<=2;state_code<=14;scan_done<=1;state<=IDLE;
      end else state<=HCHECK;
     end
    end
    HCHECK: begin
     if(scanning) begin
      if(header_ok) begin
       scan_found_valid<=1;scan_found_sector<=sd_sec_read_addr;scan_found_total<=scan_found_total+1'b1;
       if(scan_found_total+1>=scan_target_count||next_sector[32]||next_sector>scan_max_sector) begin
        scan_done<=1;state<=IDLE;
       end else begin sd_sec_read_addr<=next_sector[31:0];start_sector<=next_sector[31:0];state<=HREQ;end
      end else if(sd_sec_read_addr>=scan_max_sector) begin scan_done<=1;state<=IDLE;end
      else begin sd_sec_read_addr<=sd_sec_read_addr+1'b1;start_sector<=start_sector+1'b1;state<=HREQ;end
     end else if(header_ok) begin write_req<=1;state<=WAIT_ACK;end
     else begin error_code<=1;state_code<=14;state<=IDLE;end
    end
    WAIT_ACK: begin
     state_code<=3;
     if(write_req_ack) begin
      write_req<=0;scale_start<=1;file_position<=0;row_position<=0;component<=0;
      sd_sec_read_addr<=start_sector;state<=DREQ;
     end
    end
    DREQ: begin receive_count<=0;sd_sec_read<=1;state<=DRECV;state_code<=4;end
    DRECV: begin
     if(sd_sec_read_data_valid) if(receive_count<513) receive_count<=receive_count+1'b1;
     if(sd_sec_read_end) begin
      sd_sec_read<=0;parse_index<=0;
      if(receive_count+(sd_sec_read_data_valid?1:0)!=512) begin
       error_code<=2;state_code<=14;state<=IDLE;
      end else state<=PARSE;
     end
    end
    PARSE: if(parser_can_step) begin
     file_position<=file_position+1'b1;parse_index<=parse_index+1'b1;
     if(file_position>=pixel_offset && file_position<pixel_end) begin
      if(row_position==row_stride-1) row_position<=0;
      else row_position<=row_position+1'b1;
      if(is_rgb) begin
       case(component)
        0:source_pixel[7:0]<=parsed_byte;
        1:source_pixel[15:8]<=parsed_byte;
        2:begin source_pixel[23:16]<=parsed_byte;source_valid<=1;end
       endcase
       component<=(component==2)?0:component+1'b1;
      end
     end
     if(file_position+1>=pixel_end) state<=DRAIN;
     else if(parse_index==511) begin sd_sec_read_addr<=sd_sec_read_addr+1'b1;state<=DREQ;end
    end
    DRAIN: if(scale_done) begin load_done<=1;state<=IDLE;end
    default: state<=IDLE;
   endcase
  end
 end
endmodule
