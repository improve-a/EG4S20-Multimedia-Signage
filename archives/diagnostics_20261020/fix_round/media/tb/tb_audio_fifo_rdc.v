`timescale 1ns/1ps
// Out-of-contract boundary: single-side read reset on the real audio_async_fifo.
// The production top never asserts rd_rst alone (see tb_audio_fifo_seq), so this
// only characterises the module contract.  It does NOT claim a production bug.
module tb_audio_fifo_rdc;
 reg wr_clk=0, rd_clk=0;
 always #5 wr_clk=~wr_clk;   // 100 MHz
 always #20 rd_clk=~rd_clk;  // 25 MHz
 reg wr_rst=1, rd_rst=1, wr_en=0, rd_en=0;
 reg [31:0] wr_data=0;
 wire full, empty;
 wire [11:0] wr_level;
 wire [31:0] rd_data;
 audio_async_fifo #(.ADDRESS_BITS(11)) dut (
  .wr_clk(wr_clk),.wr_rst(wr_rst),.wr_en(wr_en),.wr_data(wr_data),
  .full(full),.wr_level(wr_level),.rd_clk(rd_clk),.rd_rst(rd_rst),
  .rd_en(rd_en),.rd_data(rd_data),.empty(empty));

 integer i, got=0, errors=0;
 reg [31:0] seen[0:31];
 reg [31:0] post[0:7];

 // One read: assert at negedge, deassert just after the sampling edge, capture
 // the registered data on the following edge.
 task read_one;
  output [31:0] value;
  integer g;
  begin
   g=0; while(empty && g<200) begin @(posedge rd_clk); g=g+1; end
   @(negedge rd_clk); rd_en=1;
   @(posedge rd_clk); #1; rd_en=0;
   @(posedge rd_clk);
   value=rd_data;
   seen[got]=rd_data; got=got+1;
  end
  endtask

 initial begin
  #102; wr_rst=0; rd_rst=0;
  repeat(4) @(posedge rd_clk);
  // 16 words, one per write clock; data changes only on the negedge.
  for(i=0;i<16;i=i+1) begin
   @(negedge wr_clk); wr_en=1; wr_data=32'h1000+i;
  end
  @(negedge wr_clk); wr_en=0;
  repeat(5) @(posedge rd_clk);
  $display("before reset: level=%0d empty=%b",wr_level,empty);
  // consume 4 words 1000..1003
  for(i=0;i<4;i=i+1) begin
   reg [31:0] v;
   read_one(v);
   if(v!==32'h1000+i) begin $display("FAIL consume %0d got %h",i,v); errors=errors+1; end
  end
  $display("after consuming 4: level=%0d empty=%b",wr_level,empty);
  // Out-of-contract: read side reset alone; write side continues with 2 words.
  rd_rst=1; repeat(3) @(posedge rd_clk); rd_rst=0;
  @(negedge wr_clk); wr_en=1; wr_data=32'h2000;
  @(negedge wr_clk); wr_data=32'h2001;
  @(negedge wr_clk); wr_en=0;
  repeat(5) @(posedge rd_clk);
  $display("after rd_rst: level=%0d empty=%b (level is not used as a fault claim)",wr_level,empty);
  for(i=0;i<4;i=i+1) post[i]=32'hdeadbeef;
  for(i=0;i<4;i=i+1) read_one(post[i]);
  $display("first word after single-side reset = %h (expected in-contract would be 1004)",post[0]);
  if(post[0]===32'h1000) $display("OUT_OF_CONTRACT: read pointer reset replayed old word 1000");
  else $display("no replay observed in this run");
  $display("SUMMARY errors=%0d got=%0d",errors,got);
  $finish;
 end
 initial begin #200000; $display("FAIL timeout"); $finish; end
endmodule
