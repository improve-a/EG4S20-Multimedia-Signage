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
 localparam IDLE=0,HREQ=1,HWAIT=2,WREQ=3,DREQ=4,DWAIT=5,FINISH=6,NEXT=7,DONE=8,FAIL=9;
 reg [3:0] state;
 reg [1:0] panel;
 reg [9:0] byte_index;
 reg [9:0] sector_index;
 reg [31:0] origin,timeout_count;
 reg [23:0] assembled;
 reg [31:0] magic,resource_bytes,resource_offset;
 reg [15:0] signature,version,texture_width,texture_height,low_width,low_height;
 (* async_reg="true" *) reg [2:0] finish_sync;
 reg finish_seen;
 assign write_len=PANEL_WORDS;
 wire finish_pulse=finish_sync[2]^finish_sync[1];
 wire header_ok=(signature==16'h4d42)&&(magic==32'h43584648)&&
   version==1&&texture_width==320&&texture_height==384&&low_width==80&&low_height==24&&
   resource_bytes==PANEL_SECTORS*512&&resource_offset==512;
 always @(posedge clk)begin
  if(rst)begin
   state<=IDLE;panel<=0;active<=0;ready<=0;error<=0;sector_req<=0;sector_addr<=0;
   write_req<=0;write_en<=0;write_data<=0;write_base<=BASE_WORD;
   byte_index<=0;sector_index<=0;origin<=0;timeout_count<=0;assembled<=0;
   magic<=0;resource_bytes<=0;resource_offset<=0;signature<=0;version<=0;
   texture_width<=0;texture_height<=0;low_width<=0;low_height<=0;
   finish_sync<=0;finish_seen<=0;
  end else begin
   finish_sync<={finish_sync[1:0],write_finish_toggle};
   sector_req<=0;write_en<=0;
   if(sector_valid||sector_end||write_req_ack||finish_pulse||!active)timeout_count<=0;
   else if(timeout_count<TIMEOUT_CYCLES)timeout_count<=timeout_count+1'b1;
   if(finish_pulse&&state>=WREQ&&state<=FINISH)finish_seen<=1;
   if(active&&(sector_error||timeout_count==TIMEOUT_CYCLES))begin
    error<=1;state<=FAIL;write_req<=0;
   end else case(state)
    IDLE:if(enable)begin active<=1;panel<=0;origin<=sector1;write_base<=BASE_WORD;state<=HREQ;end
    HREQ:begin sector_req<=1;sector_addr<=origin;byte_index<=0;signature<=0;magic<=0;state<=HWAIT;end
    HWAIT:begin
     if(sector_valid)begin
      byte_index<=byte_index+1'b1;
      case(byte_index)
       0:signature[7:0]<=sector_data;1:signature[15:8]<=sector_data;
       54:magic[7:0]<=sector_data;55:magic[15:8]<=sector_data;56:magic[23:16]<=sector_data;57:magic[31:24]<=sector_data;
       58:version[7:0]<=sector_data;59:version[15:8]<=sector_data;
       60:texture_width[7:0]<=sector_data;61:texture_width[15:8]<=sector_data;
       62:texture_height[7:0]<=sector_data;63:texture_height[15:8]<=sector_data;
       64:low_width[7:0]<=sector_data;65:low_width[15:8]<=sector_data;
       66:low_height[7:0]<=sector_data;67:low_height[15:8]<=sector_data;
       68:resource_bytes[7:0]<=sector_data;69:resource_bytes[15:8]<=sector_data;70:resource_bytes[23:16]<=sector_data;71:resource_bytes[31:24]<=sector_data;
       72:resource_offset[7:0]<=sector_data;73:resource_offset[15:8]<=sector_data;74:resource_offset[23:16]<=sector_data;75:resource_offset[31:24]<=sector_data;
      endcase
     end
     if(sector_end)begin
      if(header_ok&&(byte_index+sector_valid==512))begin write_req<=1;finish_seen<=0;state<=WREQ;end
      else begin error<=1;state<=FAIL;end
     end
    end
    WREQ:if(write_req_ack)begin write_req<=0;sector_index<=1;state<=DREQ;end
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
    FAIL:begin active<=0;write_req<=0;end
    default:state<=FAIL;
   endcase
  end
 end
endmodule
