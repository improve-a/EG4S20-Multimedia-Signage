// Real TF sector client, physical-header scan and contiguous-file WAV playback.
// No FAT traversal: WAV must start on a sector and occupy consecutive sectors.
// sector_* and controls: sys_clk. HDMI/status/wave_peak/flags: audio_clk.
module audio_media #(
 parameter SYS_CLK_HZ=100000000,AUDIO_CLK_HZ=25000000,
 parameter FIFO_ADDRESS_BITS=11,PREFILL_FRAMES=512,
 parameter [31:0] SCAN_START_SECTOR=0,SCAN_MAX_SECTOR=131071
)(
 input sys_clk,rst,audio_clk,audio_rst,
 input enable,paused,muted,restart,input [3:0] volume,
 input sd_ready,sector_grant,input [7:0] sector_data,
 input sector_valid,sector_end,sector_error,
 output sector_req,output [31:0] sector_addr,output sector_urgent,
 output audio_valid,output [23:0] audio_left,audio_right,
 output reg [3:0] status,output [15:0] wave_peak,
 output underflow,output overflow,output eof,output error,
 output [FIFO_ADDRESS_BITS:0] fifo_level
);
localparam IDLE=0,SCAN_REQ=1,SCAN_WAIT=2,SCAN_EVAL=3,PLAY_RESET=4,
 PLAY_REQ=5,PLAY_WAIT=6,PLAY_EVAL=7,FINISHED=8,FAILED=9,PLAY_HOLD=10,SCAN_DRAIN=11,PLAY_DRAIN=12;
reg [3:0] state;
reg [31:0] candidate,current_sector,wait_count;
reg [9:0] sector_bytes;
reg parser_start,play_ready,source_eof,overflow_sys,file_found;
reg parser_byte_valid;
reg [7:0] parser_byte_data;
reg [3:0] fault_sys;
reg [5:0] clear_count;
wire fifo_clear=rst||(clear_count!=0);
wire recognized,header_valid,parser_done,parser_stereo,pcm_valid;
wire [3:0] parser_error;
wire [31:0] data_offset,data_length,file_length;
wire [15:0] pcm_left,pcm_right;
wire fifo_full,fifo_empty,fifo_pop;
wire [31:0] fifo_data;
wire playing=(state==PLAY_REQ||state==PLAY_WAIT||state==PLAY_EVAL||state==PLAY_HOLD||state==PLAY_DRAIN);
assign sector_req=(state==SCAN_REQ)||(state==PLAY_REQ);
assign sector_addr=current_sector;
// Register the Gray-decode/subtract/watermark chain before SD arbitration.
// Urgency may trail the level by one sys_clk cycle. At the production 100 MHz,
// the 512-frame threshold provides 10.67 ms of 48 kHz audio buffering.
reg fifo_below_prefill;
always @(posedge sys_clk)
 if(fifo_clear)fifo_below_prefill<=1'b1;
 else fifo_below_prefill<=fifo_level<PREFILL_FRAMES;
assign sector_urgent=playing&&fifo_below_prefill;
wire fifo_push=playing&&pcm_valid;
wav_stream_parser parser(.clk(sys_clk),.rst(fifo_clear),.start(parser_start),
 .byte_data(parser_byte_data),.byte_valid(parser_byte_valid),
 .recognized(recognized),.header_valid(header_valid),.done(parser_done),.error_code(parser_error),
 .stereo(parser_stereo),.data_offset(data_offset),.data_length(data_length),.file_length(file_length),
 .pcm_valid(pcm_valid),.pcm_left(pcm_left),.pcm_right(pcm_right));
(* async_reg="true" *) reg clear_meta,clear_sync;
(* async_reg="true" *) reg [4:0] ctrl_meta,ctrl_sync;
(* async_reg="true" *) reg [3:0] volume_meta,volume_sync,fault_meta,fault_sync;
(* async_reg="true" *) reg overflow_meta,overflow_sync;
(* async_reg="true" *) reg found_meta,found_sync;
wire player_rst=audio_rst||clear_sync;
wire drained;
assign overflow=overflow_sync;
assign eof=drained;
assign error=fault_sync!=0;
audio_async_fifo #(.ADDRESS_BITS(FIFO_ADDRESS_BITS)) fifo(
 .wr_clk(sys_clk),.wr_rst(fifo_clear),.wr_en(fifo_push),.wr_data({pcm_left,pcm_right}),
 .full(fifo_full),.wr_level(fifo_level),.rd_clk(audio_clk),.rd_rst(player_rst),
 .rd_en(fifo_pop),.rd_data(fifo_data),.empty(fifo_empty));
audio_pcm_player #(.CLK_HZ(AUDIO_CLK_HZ)) player(
 .clk(audio_clk),.rst(player_rst),.enabled(ctrl_sync[4]),.paused(ctrl_sync[3]),
 .muted(ctrl_sync[2]),.ready(ctrl_sync[1]),.eof(ctrl_sync[0]),.volume(volume_sync),
 .fifo_empty(fifo_empty),.fifo_data(fifo_data),.fifo_pop(fifo_pop),
 .audio_valid(audio_valid),.audio_left(audio_left),.audio_right(audio_right),
 .underflow(underflow),.drained(drained),.wave_peak(wave_peak));
always @(posedge audio_clk)begin
 if(audio_rst)begin clear_meta<=1;clear_sync<=1;ctrl_meta<=0;ctrl_sync<=0;
 volume_meta<=8;volume_sync<=8;fault_meta<=0;fault_sync<=0;
 overflow_meta<=0;overflow_sync<=0;found_meta<=0;found_sync<=0;status<=0;end
 else begin
  clear_meta<=fifo_clear;clear_sync<=clear_meta;
  ctrl_meta<={enable,paused,muted,play_ready,source_eof};ctrl_sync<=ctrl_meta;
  volume_meta<=volume;volume_sync<=volume_meta;
  fault_meta<=fault_sys;fault_sync<=fault_meta;
  overflow_meta<=overflow_sys;overflow_sync<=overflow_meta;
  found_meta<=file_found;found_sync<=found_meta;
  if(!ctrl_sync[4])status<=0;
  else if(error)status <= (fault_sync == 4'd11) ? 4'hb : 4'he;
  else if(overflow_sync)status<=4'hc;
  else if(underflow)status<=4'hd;
  else if(drained)status<=5;
  else if(ctrl_sync[3])status<=4;
  else if(ctrl_sync[1])status<=3;
  else if(found_sync)status<=2;
  else status<=1;
 end
end
// Isolate the global sector-owner state decode from parser register enables.
// The DRAIN states below settle this extra byte stage before header/EOF decisions.
always @(posedge sys_clk)begin
 if(fifo_clear||restart||!enable)begin parser_byte_valid<=0;parser_byte_data<=0;end
 else begin
  parser_byte_valid<=sector_valid&&(state==SCAN_WAIT||state==PLAY_WAIT);
  parser_byte_data<=sector_data;
 end
end
always @(posedge sys_clk)begin
 if(rst)clear_count<=32;
 else if(restart||!enable)clear_count<=32;
 else if(clear_count!=0)clear_count<=clear_count-1'b1;
 if(fifo_clear||restart||!enable)begin
  state<=IDLE;candidate<=SCAN_START_SECTOR;current_sector<=SCAN_START_SECTOR;
  wait_count<=0;sector_bytes<=0;parser_start<=0;play_ready<=0;source_eof<=0;overflow_sys<=0;file_found<=0;fault_sys<=0;
 end else begin
  parser_start<=0;
  if(sector_grant)sector_bytes<=0;
  else if(sector_valid&&(state==SCAN_WAIT||state==PLAY_WAIT))sector_bytes<=sector_bytes+1'b1;
  if(fifo_push&&fifo_full)begin overflow_sys<=1;fault_sys<=4'd12;state<=FAILED;end
  else if(sector_error&&(state==SCAN_WAIT||state==PLAY_WAIT))begin fault_sys<=4'd13;state<=FAILED;end
  else if((state==SCAN_WAIT||state==PLAY_WAIT)&&wait_count>=SYS_CLK_HZ*2-1)begin fault_sys<=4'd14;state<=FAILED;end
  else begin
   if(state==SCAN_WAIT||state==PLAY_WAIT)begin
    if(sector_valid)wait_count<=0;else wait_count<=wait_count+1'b1;
   end else wait_count<=0;
   if(playing&&fifo_level>=PREFILL_FRAMES)play_ready<=1;
   case(state)
    IDLE:if(sd_ready)begin parser_start<=1;state<=SCAN_REQ;end
    SCAN_REQ:if(sector_grant)state<=SCAN_WAIT;
    SCAN_WAIT:if(sector_end)state<=SCAN_DRAIN;
    SCAN_DRAIN:state<=SCAN_EVAL;
    SCAN_EVAL:begin
     if(sector_bytes!=512)begin fault_sys<=4'd15;state<=FAILED;end
     else if(header_valid&&parser_error==0)begin current_sector<=candidate;file_found<=1;state<=PLAY_RESET;end
     else if(recognized&&parser_error==0&&current_sector<SCAN_MAX_SECTOR)begin current_sector<=current_sector+1'b1;state<=SCAN_REQ;end
     else if(candidate==SCAN_MAX_SECTOR)begin fault_sys<=4'd11;state<=FAILED;end
     else begin candidate<=candidate+1'b1;current_sector<=candidate+1'b1;parser_start<=1;state<=SCAN_REQ;end
    end
    PLAY_RESET:begin parser_start<=1;state<=PLAY_HOLD;end
    PLAY_HOLD:if(!paused&&fifo_level<=((1<<FIFO_ADDRESS_BITS)-256))state<=PLAY_REQ;
    PLAY_REQ:if(sector_grant)state<=PLAY_WAIT;
    PLAY_WAIT:if(sector_end)state<=PLAY_DRAIN;
    PLAY_DRAIN:state<=PLAY_EVAL;
    PLAY_EVAL:begin
     if(sector_bytes!=512)begin fault_sys<=4'd15;state<=FAILED;end
     else if(parser_error!=0)begin fault_sys<=parser_error;state<=FAILED;end
     else if(parser_done)begin source_eof<=1;play_ready<=1;state<=FINISHED;end
     else if(current_sector==32'hffffffff)begin fault_sys<=2;state<=FAILED;end
     else begin current_sector<=current_sector+1'b1;state<=PLAY_HOLD;end
    end
    default:;
   endcase
  end
 end
end
endmodule
