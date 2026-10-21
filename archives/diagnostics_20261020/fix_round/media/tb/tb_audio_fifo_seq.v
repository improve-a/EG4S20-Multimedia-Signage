`timescale 1ns/1ps
// Actual top-level common reset/flush sequence for audio_async_fifo.
// Models the real chain:
//   rst_all -> sd_rst (rst) and video_rst (audio_rst)
//   clear_count=32 after reset/restart -> fifo_clear = rst | clear_count!=0
//   clear_sync = 2FF(fifo_clear) in the audio clock
//   wr_rst = fifo_clear, rd_rst = audio_rst | clear_sync
// Checks exact data order across power-up and a WAV restart for several legal
// reset release offsets.  This is the reachable-reset test; the single-side
// reset case is a separate out-of-contract boundary test.
module tb_audio_fifo_seq;
 parameter integer AUDIO_REL_NS = 20; // audio_rst release after rst release
 reg sd_clk=0, audio_clk=0;
 always #5  sd_clk=~sd_clk;    // 100 MHz
 always #20 audio_clk=~audio_clk; // 25 MHz

 reg rst=1, audio_rst=1, restart=0;
 reg [5:0] clear_count;
 wire fifo_clear = rst || (clear_count!=0);
 always @(posedge sd_clk) begin
  if(rst) clear_count<=6'd32;
  else if(restart) clear_count<=6'd32;
  else if(clear_count!=0) clear_count<=clear_count-1'b1;
 end
 reg clear_meta=1, clear_sync=1;
 always @(posedge audio_clk) begin
  if(audio_rst) begin clear_meta<=1; clear_sync<=1; end
  else begin clear_meta<=fifo_clear; clear_sync<=clear_meta; end
 end
 wire wr_rst = fifo_clear;
 wire rd_rst = audio_rst || clear_sync;

 reg wr_en=0, rd_en=0; reg [31:0] wr_data=0;
 wire full, empty; wire [11:0] wr_level; wire [31:0] rd_data;
 audio_async_fifo #(.ADDRESS_BITS(11)) dut (
  .wr_clk(sd_clk),.wr_rst(wr_rst),.wr_en(wr_en),.wr_data(wr_data),
  .full(full),.wr_level(wr_level),.rd_clk(audio_clk),.rd_rst(rd_rst),
  .rd_en(rd_en),.rd_data(rd_data),.empty(empty));

 integer errors=0;
 // The FIFO must never be written while its write reset is active, and the
 // player must never pop while its read reset is active.
 always @(posedge sd_clk) if(wr_rst && wr_en) begin $display("FAIL write during wr_rst"); errors=errors+1; end
 always @(posedge audio_clk) if(rd_rst && rd_en) begin $display("FAIL read during rd_rst"); errors=errors+1; end

 task write_word;
  input [31:0] d;
  begin
   @(negedge sd_clk); wr_en=1; wr_data=d;
   @(negedge sd_clk); wr_en=0;
  end
  endtask
 // read one word, capture registered data on the following audio edge
 task read_word;
  output [31:0] value;
  integer g;
  begin
   g=0; while(empty && g<1000) begin @(posedge audio_clk); g=g+1; end
   @(negedge audio_clk); rd_en=1;
   @(posedge audio_clk); #1; rd_en=0;
   @(posedge audio_clk);
   value=rd_data;
  end
  endtask

 integer i, n; reg [31:0] v;
 task run_stream;
  input [31:0] base;
  input integer count;
  integer k;
  begin
   k=0; while(fifo_clear && k<10000) begin @(posedge sd_clk); k=k+1; end
   for(i=0;i<count;i=i+1) write_word(base+i);
   // wait for the read side to leave reset, then drain exactly count words
   k=0; while(rd_rst && k<10000) begin @(posedge audio_clk); k=k+1; end
   for(i=0;i<count;i=i+1) begin
    read_word(v);
    if(v!==base+i) begin $display("FAIL stream %h word %0d got %h",base,i,v); errors=errors+1; end
   end
   // quiescent level must be zero after both pointers have caught up
   repeat(4) @(posedge sd_clk);
   if(wr_level!==0) begin $display("FAIL level after drain = %0d",wr_level); errors=errors+1; end
  end
  endtask

 initial begin
  #100;
  rst=0;
  #(AUDIO_REL_NS) audio_rst=0;
  // power-up stream
  run_stream(32'h1000,32);
  $display("power-up: got 32 words, level=%0d, errors=%0d",wr_level,errors);
  // WAV restart: restart pulse in sd domain, audio_rst stays low
  @(negedge sd_clk); restart=1;
  @(negedge sd_clk); restart=0;
  run_stream(32'h2000,32);
  $display("restart: got 32 words, level=%0d, errors=%0d",wr_level,errors);
  // ensure no old data survives: the scoreboard above would fail on 0x10xx
  $display("SUMMARY AUDIO_REL_NS=%0d errors=%0d",AUDIO_REL_NS,errors);
  $finish;
 end
 initial begin #500000; $display("FAIL timeout"); $finish; end
endmodule
