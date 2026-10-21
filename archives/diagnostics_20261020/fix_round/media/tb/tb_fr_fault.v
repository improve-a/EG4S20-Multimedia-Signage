`timescale 1ns/1ps
// Short fault-latch test for the real SD/frame_read_write module.
// It shows that a single read-side underflow (display_valid_video=1, read_en=1,
// read FIFO empty) latches fifo_fault and that the latch does not clear while
// the clocks keep running.  No SDRAM data is supplied, so this is a fault-path
// test, not a normal-playback test.
module tb_fr_fault;
 reg mem_clk=0, read_clk=0, write_clk=0, rst=1;
 always #12.5 mem_clk=~mem_clk;   // 40 MHz
 always #20   read_clk=~read_clk; // 25 MHz
 always #10   write_clk=~write_clk; // 50 MHz (stand-in for sd 100 MHz)

 reg display_valid_video=0;
 reg Sdr_init_done=0, Sdr_init_ref_vld=0, Sdr_busy=0;
 wire App_rd_en; wire [20:0] App_rd_addr;
 reg Sdr_rd_en=0; reg [31:0] Sdr_rd_dout=0;
 reg read_req=0, read_en=0;
 wire read_req_ack, read_finish;
 wire [31:0] read_data;
 wire App_wr_en; wire [20:0] App_wr_addr; wire [31:0] App_wr_din; wire [3:0] App_wr_dm;
 reg write_req=0, write_en=0; reg [31:0] write_data=0;
 wire write_req_ack, write_finish;
 wire fifo_fault;

 frame_read_write #(.WRITE_V_FLIP(1),.FRAME_WIDTH(640),.FRAME_HEIGHT(480)) dut (
  .display_valid_video(display_valid_video),.fifo_fault(fifo_fault),.rst(rst),
  .mem_clk(mem_clk),.Sdr_init_done(Sdr_init_done),.Sdr_init_ref_vld(Sdr_init_ref_vld),.Sdr_busy(Sdr_busy),
  .App_rd_en(App_rd_en),.App_rd_addr(App_rd_addr),.Sdr_rd_en(Sdr_rd_en),.Sdr_rd_dout(Sdr_rd_dout),
  .read_clk(read_clk),.read_req(read_req),.read_req_ack(read_req_ack),.read_finish(read_finish),
  .read_addr_0(24'd0),.read_addr_1(24'd307200),.read_addr_2(24'd0),.read_addr_3(24'd0),
  .read_addr_index(2'd0),.read_len(24'd307200),.read_en(read_en),.read_data(read_data),
  .App_wr_en(App_wr_en),.App_wr_addr(App_wr_addr),.App_wr_din(App_wr_din),.App_wr_dm(App_wr_dm),
  .write_clk(write_clk),.write_req(write_req),.write_req_ack(write_req_ack),.write_finish(write_finish),
  .write_addr_0(24'd0),.write_addr_1(24'd307200),.write_addr_2(24'd0),.write_addr_3(24'd0),
  .write_addr_index(2'd0),.write_len(24'd307200),.write_en(write_en),.write_data(write_data));

 integer i, errors=0;
 reg fault_seen=0;
 initial begin
  #200 rst=0; Sdr_init_done=1;
  repeat(20) @(posedge read_clk);
  // A legal-looking scanout read with no data available in the read FIFO.
  display_valid_video=1;
  read_en=1;
  repeat(8) @(posedge read_clk);
  read_en=0;
  if(fifo_fault!==1'b1) begin $display("FAIL fifo_fault did not latch"); errors=errors+1; end
  else $display("PASS fifo_fault latched after one underflow at %0t",$time);
  fault_seen=fifo_fault;
  // Keep clocks running for many cycles; the latch must not clear.
  repeat(2000) @(posedge read_clk);
  if(fifo_fault!==1'b1) begin $display("FAIL fifo_fault cleared spontaneously"); errors=errors+1; end
  else $display("PASS fifo_fault still latched after 2000 read clocks");
  // The fault output is the only recovery status; no input can clear it.
  $display("SUMMARY errors=%0d fault=%b",errors,fifo_fault);
  $finish;
 end
 initial begin #2000000; $display("FAIL timeout"); $finish; end
endmodule
