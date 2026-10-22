// Load-time BMP compositor for the preserved sequential frame writer.
// One640x24 line and one512x8 sector buffer; no random SDRAM read path.
// Input resources are immutable during a load. Pixel stream is bottom-up RGB;
// inherited WRITE_V_FLIP places it into the normal top-down framebuffer.
// A real 800x600 single-image page is seen through a fixed 640x480 virtual
// source window at physical (80,60): the loader reads exactly 640 columns
// (linear stride 2400) into the unchanged 640-entry line RAM, so sample_x,
// the 36-entry origin table, the 1/2/3x divisors and dual pairing are all
// unchanged. The output canvas and the 307200-word write stay 640x480.
module legacy_exhibit_loader #(
 parameter TIMEOUT_CYCLES=200_000_000,parameter PIXEL_PERIOD=16
)(
 input clk,rst,start,abort,input[31:0]sector_left,sector_right,
 input[2:0]page,input dual,input[1:0]zoom,input[2:0]focus,input sd_init_done,
 output ready,busy,output reg done,output reg[3:0]error,
 output reg write_req,input write_req_ack,
 output reg pixel_valid,output reg[23:0]pixel,
 output reg sector_req,output reg[31:0]sector_addr,
 input[7:0]sector_data,input sector_valid,sector_end,sector_error
);
 localparam IDLE=0,HREQ=1,HWAIT=2,HCHECK=3,WREQ=4,WRELEASE=5,
 ROW=6,POSITION=7,RREQ=8,RWAIT=9,RCHECK=10,BYTE_GET=11,BYTE_USE=12,
 OUTPUT_SETUP=13,OUTPUT_GET=14,OUTPUT_WAIT=15,DRAIN=16,FAILED=17,
 ROW_STRIDE=18,ROW_ADDRESS=19,ROW_OFFSET=20;
 reg[4:0]state;
 assign ready=state==IDLE&&sd_init_done;
 assign busy=state!=IDLE&&state!=FAILED;
 reg[31:0]left_base,right_base,timeout_count,sector_watch;
 reg dual_l,header_right,right_segment,header_bad,line_valid,wide_l;
 reg[31:0]hdr_size;
 reg[9:0]hdr_w,hdr_h;
 reg[1:0]divisor,rx,ry,x_remainder,byte_phase;
 reg[9:0]ox,sample_x,out_x,line_write;
 reg[8:0]oy,source_y,line_y,out_row;
 reg[9:0]native_row_l;
 reg[13:0]row_fifteen;
 reg[20:0]byte_position;
 reg[21:0]row_offset_l;
 reg[11:0]bytes_left;
 reg[9:0]sector_bytes;
 reg[8:0]buffer_index;
 reg[7:0]buffer_byte;
 reg[15:0]assembled;
 reg[23:0]line_pixel;
 reg[15:0]pixel_wait;
 reg[7:0]sector_buffer[0:511];
 reg[23:0]line_buffer[0:639];
 wire[23:0]new_origin=origin(page==0,focus,zoom);
 // 800x600 keeps the 640x480 canvas arithmetic: source_y stays the logical row
 // inside the 640x480 window, so row_numerator keeps 479/ry unchanged, and only
 // the stored bottom-up file row moves to 539-source_y (window top offset 60).
 wire[9:0]row_numerator=10'd479-{1'b0,out_row}+{8'd0,ry};
 wire[9:0]row_quotient=divisor==1?row_numerator:divisor==2?(row_numerator>>1):row_numerator/10'd3;
 wire[9:0]row_last=wide_l?10'd539:10'd479;
 // Registered15*n, then wiring selects15*64/15*128/15*160. This removes the
 // source_y subtraction -> MULT18 -> mux -> address-adder timing chain. The
 // single-800 2400-byte term and its 240-byte (3*80) window start are folded
 // into the row_offset_l register, so the address adder is unchanged.
 wire[21:0]row_off_1920={1'b0,row_fifteen,7'b0};
 wire[21:0]row_off_2400=row_off_1920+{3'b0,row_fifteen,5'b0};
 // Strict authored geometry: one 640x480 or one 800x600 single page, or the
 // existing 320x480 dual panel. Anything else fails the header check and no
 // write_req is asserted.
 wire geometry_ok=dual_l?(hdr_w==10'd320&&hdr_h==10'd480&&hdr_size==32'd461312):
  (hdr_w==10'd640&&hdr_h==10'd480&&hdr_size==32'd922112)||
  (hdr_w==10'd800&&hdr_h==10'd600&&hdr_size==32'd1440512);
 reg checked;reg[7:0]expected_byte;
 // Fixed authored delivery format, deliberately no general BMP parser.
 // Bytes 2..5 (bfSize), 18..19 (width) and 22..23 (height) are latched and
 // matched against the two single-page geometries plus the dual panel; every
 // other fixed-format byte keeps its exact comparison, including the zero
 // high halves at 20,21 and 24,25.
 always@*begin
  checked=1;expected_byte=0;
  case(sector_bytes)
   0:expected_byte="B";1:expected_byte="M";
   10:expected_byte=0;11:expected_byte=2;12,13:expected_byte=0;
   14:expected_byte=40;15,16,17:expected_byte=0;
   20,21:expected_byte=0;24,25:expected_byte=0;
   26:expected_byte=1;27:expected_byte=0;28:expected_byte=24;
   29,30,31,32,33:expected_byte=0;
   default:checked=0;
  endcase
 end
 function [23:0] origin;
 input home;input[2:0] f;input[1:0] z;
 begin case({home,(f>5?3'd0:f),(z>2?2'd2:z)})
  6'd0:origin=24'h000000;
  6'd1:origin=24'h480350;
  6'd2:origin=24'h5545d4;
  6'd4:origin=24'h000000;
  6'd5:origin=24'h280780;
  6'd6:origin=24'h354a04;
  6'd8:origin=24'h000000;
  6'd9:origin=24'h000780;
  6'd10:origin=24'h0d4a04;
  6'd12:origin=24'h000000;
  6'd13:origin=24'h500780;
  6'd14:origin=24'h5d4a04;
  6'd16:origin=24'h000000;
  6'd17:origin=24'h280000;
  6'd18:origin=24'h354284;
  6'd20:origin=24'h000000;
  6'd21:origin=24'h280f00;
  6'd22:origin=24'h355184;
  6'd32:origin=24'h000000;
  6'd33:origin=24'h44c480;
  6'd34:origin=24'h520704;
  6'd36:origin=24'h000000;
  6'd37:origin=24'h280780;
  6'd38:origin=24'h354a04;
  6'd40:origin=24'h000000;
  6'd41:origin=24'h000780;
  6'd42:origin=24'h0d4a04;
  6'd44:origin=24'h000000;
  6'd45:origin=24'h500780;
  6'd46:origin=24'h5d4a04;
  6'd48:origin=24'h000000;
  6'd49:origin=24'h280000;
  6'd50:origin=24'h354284;
  6'd52:origin=24'h000000;
  6'd53:origin=24'h280f00;
  6'd54:origin=24'h355184;
 default:origin=0;
 endcase end endfunction
 // Neither payload RAM is reset or bulk-cleared. Reads are synchronous.
 always@(posedge clk)begin
  if(state==RWAIT&&sector_valid&&sector_bytes<512)sector_buffer[sector_bytes[8:0]]<=sector_data;
  if(state==BYTE_GET)buffer_byte<=sector_buffer[buffer_index];
  if(state==BYTE_USE&&byte_phase==2)line_buffer[line_write]<={buffer_byte,assembled};
  if(state==OUTPUT_GET)line_pixel<=line_buffer[sample_x];
 end
 always@(posedge clk)begin
  if(rst)begin
   state<=IDLE;done<=0;error<=0;write_req<=0;pixel_valid<=0;pixel<=0;sector_req<=0;sector_addr<=0;
   left_base<=0;right_base<=0;timeout_count<=0;sector_watch<=0;dual_l<=0;header_right<=0;right_segment<=0;
   header_bad<=0;line_valid<=0;divisor<=1;rx<=0;ry<=0;x_remainder<=0;byte_phase<=0;
   ox<=0;oy<=0;sample_x<=0;out_x<=0;line_write<=0;source_y<=0;line_y<=0;out_row<=0;native_row_l<=0;row_fifteen<=0;
   byte_position<=0;bytes_left<=0;sector_bytes<=0;buffer_index<=0;assembled<=0;pixel_wait<=0;
   wide_l<=0;hdr_size<=0;hdr_w<=0;hdr_h<=0;row_offset_l<=0;
  end else begin
   done<=0;pixel_valid<=0;
   if(!sector_req)sector_watch<=0;else if(sector_watch<TIMEOUT_CYCLES)sector_watch<=sector_watch+1'b1;
   if(pixel_wait!=0)pixel_wait<=pixel_wait-1'b1;
   if(!busy||sector_valid||sector_end||pixel_valid||state==BYTE_USE||state==OUTPUT_GET)timeout_count<=0;
   else if(timeout_count<TIMEOUT_CYCLES)timeout_count<=timeout_count+1'b1;
   if(busy&&state!=DRAIN&&(abort||!sd_init_done))begin
    error<=5;write_req<=0;
    if(sector_req&&!sector_end&&!sector_error)state<=DRAIN;
    else begin state<=IDLE;sector_req<=0;end
   end else if(busy&&sector_req&&sector_error)begin
    error<=state==DRAIN?4'd5:4'd3;state<=IDLE;write_req<=0;sector_req<=0;
   end else if(busy&&(timeout_count>=TIMEOUT_CYCLES||sector_watch>=TIMEOUT_CYCLES))begin
    error<=4;state<=FAILED;write_req<=0;sector_req<=0;
   end else case(state)
    IDLE:if(start&&sd_init_done&&!abort)begin
     left_base<=sector_left;right_base<=sector_right;dual_l<=dual;header_right<=0;
     divisor<=zoom==0?2'd1:zoom==1?2'd2:2'd3;
     ox<=new_origin[23:14];oy<=new_origin[12:4];rx<=new_origin[3:2];ry<=new_origin[1:0];
     error<=0;line_valid<=0;out_row<=0;state<=HREQ;
    end
    HREQ:begin sector_req<=1;sector_addr<=header_right?right_base:left_base;sector_bytes<=0;header_bad<=0;state<=HWAIT;end
    HWAIT:begin
     if(sector_valid)begin
      if(sector_bytes>=512)begin sector_bytes<=513;error<=2;state<=DRAIN;end
      else begin
       sector_bytes<=sector_bytes+1'b1;if(checked&&sector_data!=expected_byte)header_bad<=1;
       // Geometry fields arrive before HCHECK; the high halves and the exact
       // triples are decided once per header.
       case(sector_bytes)
        2:hdr_size[7:0]<=sector_data;3:hdr_size[15:8]<=sector_data;
        4:hdr_size[23:16]<=sector_data;5:hdr_size[31:24]<=sector_data;
        18:hdr_w[7:0]<=sector_data;
        19:begin hdr_w[9:8]<=sector_data[1:0];if(sector_data[7:2]!=0)header_bad<=1;end
        22:hdr_h[7:0]<=sector_data;
        23:begin hdr_h[9:8]<=sector_data[1:0];if(sector_data[7:2]!=0)header_bad<=1;end
       endcase
      end
     end
     if(sector_end)begin sector_req<=0;state<=HCHECK;end
    end
    HCHECK:if(header_bad||sector_bytes!=512)begin error<=sector_bytes!=512?4'd2:4'd1;state<=IDLE;end
     else if(!geometry_ok)begin error<=1;state<=IDLE;end
     else if(dual_l&&!header_right)begin header_right<=1;state<=HREQ;end
     else begin wide_l<=!dual_l&&hdr_w==10'd800;write_req<=1;state<=WREQ;end
    WREQ:if(write_req_ack)begin write_req<=0;state<=WRELEASE;end
    WRELEASE:if(!write_req_ack)state<=ROW;
    ROW:begin source_y<=oy+row_quotient;state<=POSITION;end
    POSITION:if(line_valid&&line_y==source_y)state<=OUTPUT_SETUP;
     else begin native_row_l<=row_last-{1'b0,source_y};state<=ROW_STRIDE;end
    ROW_STRIDE:begin
     row_fifteen<={native_row_l,4'b0}-{4'b0,native_row_l};state<=ROW_OFFSET;
    end
    // 15*n*(128 or 64), plus 15*n*(128+32) with the 240-byte window start for
    // the single 800x600 page. One extra registered load step keeps this adder
    // out of the existing address path.
    ROW_OFFSET:begin
     row_offset_l<=wide_l?(row_off_2400+22'd240):dual_l?{2'b0,row_fifteen,6'b0}:row_off_1920;
     state<=ROW_ADDRESS;
    end
    ROW_ADDRESS:begin
     right_segment<=0;byte_position<=21'd512+row_offset_l[20:0];bytes_left<=dual_l?12'd960:12'd1920;
     line_write<=0;byte_phase<=0;state<=RREQ;
    end
    RREQ:begin sector_req<=1;sector_addr<=(right_segment?right_base:left_base)+{20'd0,byte_position[20:9]};sector_bytes<=0;state<=RWAIT;end
    RWAIT:begin
     if(sector_valid)begin
      if(sector_bytes>=512)begin sector_bytes<=513;error<=2;state<=DRAIN;end
      else sector_bytes<=sector_bytes+1'b1;
     end
     if(sector_end)begin sector_req<=0;state<=RCHECK;end
    end
    RCHECK:if(sector_bytes!=512)begin error<=2;state<=IDLE;end
     else begin buffer_index<=byte_position[8:0];state<=BYTE_GET;end
    BYTE_GET:state<=BYTE_USE;
    BYTE_USE:begin
     case(byte_phase)
      0:begin assembled[7:0]<=buffer_byte;byte_phase<=1;end
      1:begin assembled[15:8]<=buffer_byte;byte_phase<=2;end
      2:begin line_write<=line_write+1'b1;byte_phase<=0;end
     endcase
     byte_position<=byte_position+1'b1;bytes_left<=bytes_left-1'b1;
     if(bytes_left==1)begin
      if(dual_l&&!right_segment)begin
       right_segment<=1;byte_position<=21'd512+row_offset_l[20:0];bytes_left<=960;line_write<=320;byte_phase<=0;state<=RREQ;
      end else begin line_valid<=1;line_y<=source_y;state<=OUTPUT_SETUP;end
     end else if(buffer_index==511)state<=RREQ;
     else begin buffer_index<=buffer_index+1'b1;state<=BYTE_GET;end
    end
    OUTPUT_SETUP:begin sample_x<=ox;x_remainder<=rx;out_x<=0;state<=OUTPUT_GET;end
    OUTPUT_GET:state<=OUTPUT_WAIT;
    OUTPUT_WAIT:if(pixel_wait==0)begin
     pixel<=line_pixel;pixel_valid<=1;pixel_wait<=PIXEL_PERIOD-1;
     if(out_x==639)begin
      if(out_row==479)begin done<=1;state<=IDLE;end
      else begin out_row<=out_row+1'b1;state<=ROW;end
     end else begin
      out_x<=out_x+1'b1;
      if(x_remainder+3'd1>=divisor)begin sample_x<=sample_x+1'b1;x_remainder<=0;end
      else x_remainder<=x_remainder+1'b1;
      state<=OUTPUT_GET;
     end
    end
    DRAIN:if(sector_end)begin sector_req<=0;state<=IDLE;end
    FAILED:;
    default:begin error<=4'hf;state<=FAILED;sector_req<=0;write_req<=0;end
   endcase
  end
 end
endmodule
