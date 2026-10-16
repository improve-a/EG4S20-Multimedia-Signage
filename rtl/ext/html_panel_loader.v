// Four independently addressed comparison textures live in the BMP metadata gap.
// Uses the existing BMP side of the SD/audio sector arbiter, never a second SD bus.
module html_panel_loader #(
 parameter TIMEOUT_CYCLES=1_000_000_000,
 parameter PANEL_WORDS=62464, PANEL_SECTORS=488, BASE_WORD=1843200
)(
 input clk,rst,enable,
 input [31:0] sector1,sector2,sector3,sector4,
 output reg active,ready,error,
 output reg sector_req,output reg [31:0] sector_addr,
 input [7:0] sector_data,input sector_valid,sector_end,sector_error,
 output reg write_req,input write_req_ack,
 output reg write_en,output reg [31:0] write_data,
 output reg [20:0] write_base,output [20:0] write_len,
 input write_finish_toggle
);
 localparam IDLE=0,HREQ=1,HWAIT=2,WREQ=3,DREQ=4,DWAIT=5,FINISH=6,NEXT=7,DONE=8,FAIL=9,WRELEASE=10;
 reg [3:0] state;
 reg [1:0] panel;
 reg [9:0] byte_index;
 reg [9:0] sector_index;
 reg [31:0] origin,timeout_count;
 reg [23:0] assembled;
 reg header_ok;
 reg checked_header_byte;reg [7:0] expected_header_byte;
 localparam [31:0] RESOURCE_BYTES=PANEL_SECTORS*512;
 (* async_reg="true" *) reg [2:0] finish_sync;
 reg finish_seen;
 assign write_len=PANEL_WORDS;
 wire finish_pulse=finish_sync[2]^finish_sync[1];
 // All accepted header fields are fixed constants. Compare each arriving
 // byte once; the sticky result replaces 192 stored field bits. Last checked
 // byte75 precedes the complete 512-byte sector decision by436 clocks.
 always @*begin
  checked_header_byte=1;expected_header_byte=0;
  case(byte_index)
   10'd0:expected_header_byte=8'h42;
   10'd1:expected_header_byte=8'h4d;
   10'd54:expected_header_byte=8'h48;
   10'd55:expected_header_byte=8'h46;
   10'd56:expected_header_byte=8'h58;
   10'd57:expected_header_byte=8'h43;
   10'd58:expected_header_byte=8'h01;
   10'd59:expected_header_byte=8'h00;
   10'd60:expected_header_byte=8'h40;
   10'd61:expected_header_byte=8'h01;
   10'd62:expected_header_byte=8'h80;
   10'd63:expected_header_byte=8'h01;
   10'd64:expected_header_byte=8'h50;
   10'd65:expected_header_byte=8'h00;
   10'd66:expected_header_byte=8'h18;
   10'd67:expected_header_byte=8'h00;
   10'd68:expected_header_byte=RESOURCE_BYTES[7:0];
   10'd69:expected_header_byte=RESOURCE_BYTES[15:8];
   10'd70:expected_header_byte=RESOURCE_BYTES[23:16];
   10'd71:expected_header_byte=RESOURCE_BYTES[31:24];
   10'd72:expected_header_byte=8'h00;
   10'd73:expected_header_byte=8'h02;
   10'd74:expected_header_byte=8'h00;
   10'd75:expected_header_byte=8'h00;
   default:checked_header_byte=0;
  endcase
 end
 always @(posedge clk)begin
  if(rst)begin
   state<=IDLE;panel<=0;active<=0;ready<=0;error<=0;sector_req<=0;sector_addr<=0;
   write_req<=0;write_en<=0;write_data<=0;write_base<=BASE_WORD;
   byte_index<=0;sector_index<=0;origin<=0;timeout_count<=0;assembled<=0;
   header_ok<=0;
   finish_sync<=0;finish_seen<=0;
  end else begin
   finish_sync<={finish_sync[1:0],write_finish_toggle};
   write_en<=0;
   if(sector_valid||sector_end||write_req_ack||finish_pulse||!active)timeout_count<=0;
   else if(timeout_count<TIMEOUT_CYCLES)timeout_count<=timeout_count+1'b1;
   if(finish_pulse&&state>=WREQ&&state<=FINISH)finish_seen<=1;
   if(active&&(sector_error||timeout_count==TIMEOUT_CYCLES))begin
    error<=1;active<=0;state<=FAIL;write_req<=0;sector_req<=0;
   end else case(state)
    IDLE:if(enable)begin active<=1;panel<=0;origin<=sector1;write_base<=BASE_WORD;state<=HREQ;end
    HREQ:begin sector_req<=1;sector_addr<=origin;byte_index<=0;header_ok<=1;state<=HWAIT;end
    HWAIT:begin
     if(sector_valid)begin
      byte_index<=byte_index+1'b1;
      if(checked_header_byte&&sector_data!=expected_header_byte)header_ok<=0;
     end
     if(sector_end)begin
      sector_req<=0;
      if(header_ok&&(byte_index+sector_valid==512))begin write_req<=1;finish_seen<=0;state<=WREQ;end
      else begin error<=1;state<=FAIL;end
     end
    end
    WREQ:if(write_req_ack)begin write_req<=0;sector_index<=1;state<=WRELEASE;end
    WRELEASE:if(!write_req_ack)state<=DREQ;
    DREQ:begin sector_req<=1;sector_addr<=origin+sector_index;byte_index<=0;state<=DWAIT;end
    DWAIT:begin
     if(sector_valid)begin
      byte_index<=byte_index+1'b1;
      case(byte_index[1:0])
       0:assembled[7:0]<=sector_data;
       1:assembled[15:8]<=sector_data;
       2:assembled[23:16]<=sector_data;
       3:begin write_data<={sector_data,assembled};write_en<=1;end
      endcase
     end
     if(sector_end)begin
      sector_req<=0;
      if(byte_index+sector_valid!=512)begin error<=1;state<=FAIL;end
      else if(sector_index==PANEL_SECTORS)state<=FINISH;
      else begin sector_index<=sector_index+1'b1;state<=DREQ;end
     end
    end
    FINISH:if(finish_seen||finish_pulse)state<=NEXT;
    NEXT:if(panel==3)begin active<=0;ready<=1;state<=DONE;end
     else begin
      panel<=panel+1'b1;write_base<=write_base+PANEL_WORDS;
      case(panel)0:origin<=sector2;1:origin<=sector3;default:origin<=sector4;endcase
      state<=HREQ;
     end
    DONE:;
    FAIL:begin active<=0;write_req<=0;sector_req<=0;end
    default:state<=FAIL;
   endcase
  end
 end
endmodule
