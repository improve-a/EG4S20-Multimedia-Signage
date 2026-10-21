// One physical SD reader, transaction-level arbitration. BMP holds its request
// through end; audio holds through grant. No transaction is preempted. Two idle
// cycles after completion let clients consume end and change their next LBA.
module media_sector_arbiter(
 input clk,rst,sd_ready,
 input bmp_req,input [31:0] bmp_addr,
 output [7:0] bmp_data,output bmp_valid,bmp_end,bmp_error,
 input audio_req,input [31:0] audio_addr,input audio_urgent,
 output reg audio_grant,output [7:0] audio_data,
 output audio_valid,audio_end,audio_error,
 output reg sd_req,output reg [31:0] sd_addr,
 input [7:0] sd_data,input sd_valid,sd_end,sd_error
);
 localparam IDLE=0,ACTIVE=1,DRAIN=2;
 reg [1:0] state,drain_count,audio_streak;
 reg owner_audio,prefer_audio;
 wire select_audio=audio_req && (!bmp_req ||
     (audio_urgent ? audio_streak<2 : prefer_audio));
 assign bmp_data=sd_data;assign audio_data=sd_data;
 assign bmp_valid=(state==ACTIVE)&&!owner_audio&&sd_valid;
 assign bmp_end=(state==ACTIVE)&&!owner_audio&&sd_end;
 assign bmp_error=(state==ACTIVE)&&!owner_audio&&sd_error;
 assign audio_valid=(state==ACTIVE)&&owner_audio&&sd_valid;
 assign audio_end=(state==ACTIVE)&&owner_audio&&sd_end;
 assign audio_error=(state==ACTIVE)&&owner_audio&&sd_error;
 always @(posedge clk)begin
  if(rst)begin
   state<=IDLE;drain_count<=0;audio_streak<=0;owner_audio<=0;
   prefer_audio<=0;audio_grant<=0;sd_req<=0;sd_addr<=0;
  end else begin
   audio_grant<=0;
   case(state)
    IDLE:if(sd_ready&&(bmp_req||audio_req))begin
     owner_audio<=select_audio;sd_req<=1;state<=ACTIVE;
     if(select_audio)begin
      sd_addr<=audio_addr;audio_grant<=1;prefer_audio<=0;
      if(audio_streak<2)audio_streak<=audio_streak+1'b1;
     end else begin sd_addr<=bmp_addr;prefer_audio<=1;audio_streak<=0;end
    end
    ACTIVE:if(sd_end||sd_error)begin sd_req<=0;drain_count<=2;state<=DRAIN;end
    DRAIN:if(drain_count!=0)drain_count<=drain_count-1'b1;else state<=IDLE;
    default:begin state<=IDLE;sd_req<=0;end
   endcase
  end
 end
endmodule
