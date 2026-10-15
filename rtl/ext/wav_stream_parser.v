// Streaming RIFF/WAVE parser. Continuous sector bytes, little endian PCM16 only.
// Unknown chunks and odd padding are skipped; headers are bounded to 4096 bytes.
module wav_stream_parser #(parameter integer MAX_HEADER_BYTES=4096)(
 input clk,rst,start,input [7:0] byte_data,input byte_valid,
 output reg recognized,header_valid,done,output reg [3:0] error_code,
 output reg stereo,output reg [31:0] data_offset,data_length,file_length,
 output reg pcm_valid,output reg [15:0] pcm_left,pcm_right
);
localparam RIFF=0,CHUNK=1,PAYLOAD=2,PAD=3,PCM=4,STOP=5;
reg [2:0] state;
reg [31:0] pos,chunk_id,chunk_size,remain,payload_index;
reg [3:0] idx;
reg [31:0] signature,wave_id,rate,byte_rate;
reg [15:0] encoding,channels,align_bytes,bits;
reg fmt_valid,pad_needed;
reg [31:0] chunk_space;
reg chunk_outside;
reg [1:0] pcm_index;
reg [7:0] low_byte;
reg [15:0] left_hold;
wire [31:0] incoming_size={byte_data,chunk_size[23:0]};
wire [31:0] payload_start=pos+1;
wire [31:0] payload_start_next=pos+32'd2;
always @(posedge clk) begin
 if(rst||start) begin
  state<=RIFF;pos<=0;idx<=0;signature<=0;wave_id<=0;file_length<=0;
  chunk_id<=0;chunk_size<=0;remain<=0;payload_index<=0;
  encoding<=0;channels<=0;rate<=0;byte_rate<=0;align_bytes<=0;bits<=0;
  fmt_valid<=0;pad_needed<=0;recognized<=0;header_valid<=0;done<=0;error_code<=0;
  stereo<=0;data_offset<=0;data_length<=0;pcm_valid<=0;pcm_left<=0;pcm_right<=0;
  pcm_index<=0;low_byte<=0;left_hold<=0;chunk_space<=0;chunk_outside<=0;
 end else begin
  pcm_valid<=0;
  if(byte_valid&&state!=STOP) begin
   pos<=pos+1;
   if(state!=PCM && pos>=MAX_HEADER_BYTES) begin error_code<=4'd2;state<=STOP;end
   else case(state)
    RIFF:begin
     case(pos)
      0:signature[7:0]<=byte_data;1:signature[15:8]<=byte_data;
      2:signature[23:16]<=byte_data;3:signature[31:24]<=byte_data;
      4:file_length[7:0]<=byte_data;5:file_length[15:8]<=byte_data;
      6:file_length[23:16]<=byte_data;7:file_length<= {byte_data,file_length[23:0]}+32'd8;
      8:wave_id[7:0]<=byte_data;9:wave_id[15:8]<=byte_data;10:wave_id[23:16]<=byte_data;
      11:begin
       if(signature==32'h46464952 && {byte_data,wave_id[23:0]}==32'h45564157 && file_length>=44)begin
        recognized<=1;state<=CHUNK;idx<=0;
       end else begin error_code<=1;state<=STOP;end
      end
      default:;
     endcase
    end
    CHUNK:begin
     idx<=idx+1;
     case(idx)
      0:chunk_id[7:0]<=byte_data;1:chunk_id[15:8]<=byte_data;
      2:chunk_id[23:16]<=byte_data;3:chunk_id[31:24]<=byte_data;
      4:chunk_size[7:0]<=byte_data;5:chunk_size[15:8]<=byte_data;
      6:begin
       chunk_size[23:16]<=byte_data;
       // One accepted byte before the decision: retain byte/state latency while
       // removing payload-start/subtract/size-compare from one timing path.
       chunk_space<=file_length-payload_start_next;
       chunk_outside<=payload_start_next>file_length;
      end
      7:begin
       chunk_size<=incoming_size;idx<=0;remain<=incoming_size;payload_index<=0;
       pad_needed<=incoming_size[0];
       if(chunk_outside || incoming_size>chunk_space)begin error_code<=2;state<=STOP;end
       else if(chunk_id==32'h61746164)begin
        if(!fmt_valid || incoming_size==0 || (stereo?incoming_size[1:0]!=0:incoming_size[0]!=0))begin error_code<=3;state<=STOP;end
        else begin header_valid<=1;data_offset<=payload_start;data_length<=incoming_size;state<=PCM;pcm_index<=0;end
       end else if(chunk_id==32'h20746d66 && incoming_size<16)begin error_code<=3;state<=STOP;end
       else if(incoming_size==0) state<=CHUNK;
       else state<=PAYLOAD;
      end
      default:;
     endcase
    end
    PAYLOAD:begin
     remain<=remain-1;payload_index<=payload_index+1;
     if(chunk_id==32'h20746d66)begin
      case(payload_index)
       0:encoding[7:0]<=byte_data;1:encoding[15:8]<=byte_data;
       2:channels[7:0]<=byte_data;3:channels[15:8]<=byte_data;
       4:rate[7:0]<=byte_data;5:rate[15:8]<=byte_data;6:rate[23:16]<=byte_data;7:rate[31:24]<=byte_data;
       8:byte_rate[7:0]<=byte_data;9:byte_rate[15:8]<=byte_data;10:byte_rate[23:16]<=byte_data;11:byte_rate[31:24]<=byte_data;
       12:align_bytes[7:0]<=byte_data;13:align_bytes[15:8]<=byte_data;
       14:bits[7:0]<=byte_data;
       15:begin
        bits[15:8]<=byte_data;
        if(encoding==1 && (channels==1||channels==2) && rate==48000 &&
          {byte_data,bits[7:0]}==16 && align_bytes==(channels==2?4:2) && byte_rate==(channels==2?192000:96000))begin
          fmt_valid<=1;stereo<=channels==2;
        end else begin error_code<=3;state<=STOP;end
       end
       default:;
      endcase
     end
     if(remain==1)begin
      // Invalid fmt on its final byte must retain STOP priority.
      if(chunk_id==32'h20746d66 && payload_index==15 && !(encoding==1 && (channels==1||channels==2) && rate==48000 && {byte_data,bits[7:0]}==16 && align_bytes==(channels==2?4:2) && byte_rate==(channels==2?192000:96000)))state<=STOP;
      else state<=pad_needed?PAD:CHUNK;
      idx<=0;
     end
    end
    PAD:begin state<=CHUNK;idx<=0;end
    PCM:begin
     remain<=remain-1;
     case(pcm_index)
      0:begin low_byte<=byte_data;pcm_index<=1;end
      1:begin
       if(stereo)begin left_hold<={byte_data,low_byte};pcm_index<=2;end
       else begin pcm_left<={byte_data,low_byte};pcm_right<={byte_data,low_byte};pcm_valid<=1;pcm_index<=0;end
      end
      2:begin low_byte<=byte_data;pcm_index<=3;end
      3:begin pcm_left<=left_hold;pcm_right<={byte_data,low_byte};pcm_valid<=1;pcm_index<=0;end
     endcase
     if(remain==1)begin done<=1;state<=STOP;end
    end
    default:;
   endcase
  end
 end
end
endmodule
