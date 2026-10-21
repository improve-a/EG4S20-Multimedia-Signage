// Six finite HFXL scene atlases. Loads sector-aligned BMP trailers through the
// existing SD/audio arbiter and existing write FIFO; no PC runtime dependency.
module html_scene_loader #(
 parameter TIMEOUT_CYCLES=1_000_000_000,
 parameter [31:0] SET_ID=32'h003adc1b,
 parameter [125:0] BASE_WORDS={21'd1514240,21'd1202688,21'd890880,21'd586240,21'd275200,21'd0},
 parameter [125:0] LENGTH_WORDS={21'd289536,21'd311552,21'd311808,21'd304640,21'd311040,21'd275200}
)(
 input clk,rst,enable,input [31:0] sector0,sector1,sector2,sector3,sector4,sector5,
 output reg active,ready,error,output reg [5:0] page_ready,
 output reg mode_valid,layer_mode,
 output reg sector_req,output reg [31:0] sector_addr,
 input [7:0] sector_data,input sector_valid,sector_end,sector_error,
 output reg write_req,input write_req_ack,
 output reg write_en,output reg [31:0] write_data,
 output reg [20:0] write_base,write_len,input write_finish_toggle
);
 localparam IDLE=0,HREQ=1,HWAIT=2,WREQ=3,DREQ=4,DWAIT=5,FINISH=6,NEXT=7,DONE=8,FAIL=9,WRELEASE=10;
 reg [3:0] state;
 reg [2:0] page;
 reg [9:0] byte_index;
 reg [12:0] sector_index,sector_count;
 reg [31:0] origin,payload_sector,timeout_count;
 reg timeout_expired;
 reg [23:0] assembled;
 reg [31:0] file_len,pixel_offset;
 reg [15:0] signature;
 reg bmp_constants_ok;
 reg bmp_check_constant;reg [7:0] bmp_expected_constant;
 always @*begin
  bmp_check_constant=1;bmp_expected_constant=0;
  case(byte_index)
   14:bmp_expected_constant=40;
   18:bmp_expected_constant=128;
   19:bmp_expected_constant=2;
   22:bmp_expected_constant=224;
   23:bmp_expected_constant=1;
   26:bmp_expected_constant=1;
   28:bmp_expected_constant=24;
   15,16,17,20,21,24,25,27,29,30,31,32,33:bmp_expected_constant=0;
   default:bmp_check_constant=0;
  endcase
 end
 wire [31:0] scene_offset,payload_bytes,locator_base,set_id;
 wire [15:0] page_index;
 wire locator_valid,locator_present;
 reg [31:0] pixel_end;
 wire [20:0] expected_base=BASE_WORDS[page*21+:21];
 wire [20:0] expected_words=LENGTH_WORDS[page*21+:21];
 // Validate each required header word as it arrives. The sticky result
 // avoids retaining twelve words after their single comparison.
 reg body_ok,body_checked;
 reg [31:0] expected_body_word;
 reg body_checked_q;reg [31:0] expected_body_word_q;
 reg header_ok_q,resource_range_ok;
 always @*begin
  body_checked=1;expected_body_word=0;
  case(byte_index[8:2])
   0:expected_body_word=32'h4c584648;
   1:expected_body_word=1;
   2:expected_body_word={11'd0,expected_words};
   3:expected_body_word=page==0?9:page==5?10:12;
   4:expected_body_word=64;
   5:expected_body_word=8;
   7:expected_body_word=214;
   10:expected_body_word=640;
   11:expected_body_word=480;
   13:expected_body_word=SET_ID;
   14:expected_body_word={11'd0,expected_base};
   15:expected_body_word={29'd0,page};
   default:body_checked=0;
  endcase
 end
 (* async_reg="true" *) reg [2:0] finish_sync;
 reg finish_seen;
 wire finish_pulse=finish_sync[2]^finish_sync[1];
 wire [31:0] assembled_word={sector_data,assembled};
 wire [32:0] resource_last_sector={1'b0,origin}+{10'd0,file_len[31:9]}-1'b1;
 wire header_ok=locator_valid && signature==16'h4d42 && bmp_constants_ok &&
  page_index=={13'd0,page} && set_id==SET_ID && locator_base=={11'd0,expected_base} &&
  payload_bytes=={9'd0,expected_words,2'b00};
 html_resource_locator locator(.clk(clk),.rst(rst),.header_start(state==HREQ),
  .byte_valid(state==HWAIT&&sector_valid),.byte_index(byte_index),.byte_data(sector_data),
  .file_len(file_len),.pixel_offset(pixel_offset),.pixel_end(pixel_end),.dib_size(32'd40),.width(32'd640),.height(32'd480),
  .valid(locator_valid),.present(locator_present),.scene_offset(scene_offset),.payload_bytes(payload_bytes),.word_base(locator_base),.set_id(set_id),.page_index(page_index));
 always @(posedge clk)begin
  if(rst)pixel_end<=0;
  else pixel_end<=pixel_offset+32'd921600;
 end
 // Header fields settle long before the 512-byte decision. Keep their
 // enables local; transport abort/timeout only controls the transaction FSM.
 always @(posedge clk)begin
  if(rst)begin
   file_len<=0;pixel_offset<=0;signature<=0;bmp_constants_ok<=0;
  end else if(state==HREQ)begin
   file_len<=0;pixel_offset<=0;signature<=0;bmp_constants_ok<=1;
  end else if(state==HWAIT&&sector_valid)begin
      if(bmp_check_constant && sector_data!=bmp_expected_constant)bmp_constants_ok<=0;
      case(byte_index)
       0:signature[7:0]<=sector_data;1:signature[15:8]<=sector_data;
       2:file_len[7:0]<=sector_data;3:file_len[15:8]<=sector_data;4:file_len[23:16]<=sector_data;5:file_len[31:24]<=sector_data;
       10:pixel_offset[7:0]<=sector_data;11:pixel_offset[15:8]<=sector_data;12:pixel_offset[23:16]<=sector_data;13:pixel_offset[31:24]<=sector_data;
      endcase
  end
 end
 // Four byte clocks separate successive body words. Register the expected
 // word before its fourth byte, cutting the selector out of the comparison.
 always @(posedge clk)begin
  if(rst)begin
   header_ok_q<=0;resource_range_ok<=0;body_checked_q<=0;expected_body_word_q<=0;body_ok<=0;
  end else begin
   header_ok_q<=header_ok;resource_range_ok<=!resource_last_sector[32];
   body_checked_q<=body_checked;expected_body_word_q<=expected_body_word;
   if(state==HREQ)body_ok<=1;
   else if(state==DWAIT&&sector_valid&&byte_index[1:0]==3&&sector_index==0&&
           body_checked_q&&assembled_word!=expected_body_word_q)body_ok<=0;
  end
 end
 always @(posedge clk)begin
  if(rst)begin
   state<=IDLE;page<=0;active<=0;ready<=0;error<=0;page_ready<=0;mode_valid<=0;layer_mode<=0;
   sector_req<=0;sector_addr<=0;write_req<=0;write_en<=0;write_data<=0;write_base<=0;write_len<=0;
   byte_index<=0;sector_index<=0;sector_count<=0;origin<=0;payload_sector<=0;timeout_count<=0;timeout_expired<=(TIMEOUT_CYCLES==0);assembled<=0;

   finish_sync<=0;finish_seen<=0;
  end else begin
   finish_sync<={finish_sync[1:0],write_finish_toggle};write_en<=0;
   if(sector_valid||sector_end||write_req_ack||finish_pulse||!active)begin
    timeout_count<=0;timeout_expired<=(TIMEOUT_CYCLES==0);
   end else if(timeout_count<TIMEOUT_CYCLES)begin
    timeout_count<=timeout_count+1'b1;timeout_expired<=(timeout_count==TIMEOUT_CYCLES-1);
   end else timeout_expired<=1;
   if(finish_pulse&&(state==WREQ||state==DREQ||state==DWAIT||state==FINISH))finish_seen<=1;
   if(active&&(sector_error||timeout_expired))begin
    error<=1;active<=0;state<=FAIL;write_req<=0;sector_req<=0;
   end else case(state)
    IDLE:if(enable)begin active<=1;page<=0;origin<=sector0;state<=HREQ;end
    HREQ:begin
     sector_req<=1;sector_addr<=origin;byte_index<=0;state<=HWAIT;
    end
    HWAIT:begin
     if(sector_valid)begin
      if(byte_index<513)byte_index<=byte_index+1'b1;
     end
     if(sector_end)begin
      sector_req<=0;
      if(header_ok_q && byte_index+sector_valid==512 && resource_range_ok)begin
       mode_valid<=1;layer_mode<=1;
       write_base<=expected_base;write_len<=expected_words;write_req<=1;finish_seen<=0;
       payload_sector<=origin+(scene_offset>>9);sector_count<=payload_bytes[21:9];sector_index<=0;
       state<=WREQ;
      end else if(page==0 && !locator_present && signature==16'h4d42 && byte_index+sector_valid==512)begin
       // An ordinary first BMP selects the existing adaptive-BMP pipeline.
       // That parser still performs all original dimensions/extent checks.
       // A recognized but malformed HFXL locator cannot select this fallback.
       mode_valid<=1;layer_mode<=0;active<=0;state<=DONE;
      end else begin error<=1;state<=FAIL;end
     end
    end
    WREQ:if(write_req_ack)begin write_req<=0;state<=WRELEASE;end
    // ACK low confirms the memory side released FIFO clear before any payload.
    WRELEASE:if(!write_req_ack)state<=DREQ;
    DREQ:begin sector_req<=1;sector_addr<=payload_sector+sector_index;byte_index<=0;state<=DWAIT;end
    DWAIT:begin
     if(sector_valid)begin
      if(byte_index<513)byte_index<=byte_index+1'b1;
      case(byte_index[1:0])
       0:assembled[7:0]<=sector_data;1:assembled[15:8]<=sector_data;2:assembled[23:16]<=sector_data;
       3:begin
        write_data<=assembled_word;write_en<=1;

       end
      endcase
     end
     if(sector_end)begin
      sector_req<=0;
      if(byte_index+sector_valid!=512 || (sector_index==0&&!body_ok))begin error<=1;state<=FAIL;end
      else if(sector_index+1==sector_count)state<=FINISH;
      else begin sector_index<=sector_index+1'b1;state<=DREQ;end
     end
    end
    FINISH:if(finish_seen||finish_pulse)begin page_ready[page]<=1;state<=NEXT;end
    NEXT:if(page==5)begin active<=0;ready<=1;state<=DONE;end
     else begin
      page<=page+1'b1;
      case(page)0:origin<=sector1;1:origin<=sector2;2:origin<=sector3;3:origin<=sector4;default:origin<=sector5;endcase
      state<=HREQ;
     end
    DONE:;
    FAIL:begin active<=0;write_req<=0;sector_req<=0;end
    default:state<=FAIL;
   endcase
  end
 end
endmodule
