`timescale 1ns/1ps
module scale_reject_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,init=1,start=0,abort=0,ack=0,valid=0,ending=0,sd_error=0;
 reg [31:0] base=0;reg [7:0] data=0;
 wire ready,request,read_req,done,wr;wire [31:0] address;wire [3:0] error;
 reg [7:0] invalid [0:6143],good[0:511];
 integer c,i,j,writes;
 bmp_read #(.ENABLE_SCALE(1),.TIMEOUT_CYCLES(2000)) dut(
 .clk(clk),.rst(rst),.ready(ready),.scan_start(1'b0),.scan_start_sector(32'd0),
 .scan_max_sector(32'd0),.scan_target_count(3'd1),.scan_done(),.scan_found_valid(),
 .scan_found_sector(),.scan_found_total(),.load_start(start),.load_abort(abort),
 .load_sector(base),.scale_mode(2'd0),.sd_init_done(init),.state_code(),
 .bmp_width(16'd640),.bmp_height(16'd480),.write_req(request),.write_req_ack(ack),
 .sd_sec_read(read_req),.sd_sec_read_addr(address),.sd_sec_read_data(data),
 .sd_sec_read_data_valid(valid),.sd_sec_read_end(ending),.sd_sec_read_error(sd_error),
 .load_done(done),.error_code(error),.bmp_data_wr_en(wr),.bmp_data());
 always @(posedge clk) begin
  if(wr)writes=writes+1;
  if(done)$fatal(1,"invalid/aborted load reported done case=%0d",c);
 end
 task launch;begin
  @(negedge clk);rst=1;start=0;abort=0;ack=0;valid=0;ending=0;sd_error=0;writes=0;
  repeat(4)@(negedge clk);rst=0;start=1;@(negedge clk);start=0;
  wait(read_req);@(negedge clk);
 end endtask
 task header(input integer n,input integer bytes);begin
  for(i=0;i<bytes;i=i+1) begin
   data=n<12?invalid[n*512+(i%512)]:good[i%512];valid=1;ending=(i==bytes-1);
   @(negedge clk);valid=0;ending=0;@(negedge clk);
  end
 end endtask
 task expect_error(input integer value);begin
  repeat(8)@(negedge clk);
  if(!ready||error!=value||writes||request||read_req)
   $fatal(1,"reject case %0d ready=%b error=%d writes=%d req=%b read=%b",c,ready,error,writes,request,read_req);
 end endtask
 initial begin
  $readmemh("tests/scale_invalid.hex",invalid);$readmemh("tests/scale_header.hex",good,0,511);
  for(c=0;c<12;c=c+1)begin base=17;launch;header(c,512);expect_error(1);end
  c=12;base=32'hfffffff0;launch;header(12,512);expect_error(1);
  c=13;base=17;launch;header(12,511);expect_error(2);
  c=14;launch;header(12,513);expect_error(2);
  c=15;launch;repeat(2010)@(negedge clk);expect_error(4);
  c=16;launch;header(12,512);wait(request);@(negedge clk);abort=1;
  repeat(3)@(negedge clk);abort=0;repeat(5)@(negedge clk);
  if(!ready||wr||request||read_req)$fatal(1,"abort did not stop loader");
  c=17;launch;sd_error=1;@(negedge clk);sd_error=0;expect_error(3);
  c=18;launch;header(12,512);wait(request);repeat(2010)@(negedge clk);expect_error(4);
  c=19;launch;header(12,512);wait(request);@(negedge clk);ack=1;@(negedge clk);ack=0;
  for(j=0;j<4;j=j+1)begin wait(read_req);@(negedge clk);header(12,512);wait(!read_req);end
  wait(wr);@(negedge clk);abort=1;repeat(3)@(negedge clk);abort=0;repeat(5)@(negedge clk);
  if(!ready||wr||request||read_req)$fatal(1,"active canvas abort did not stop loader");
  $display("TEST_PASS SCALE_REJECT invalid_headers=12 wrap=1 short=1 extra=1 timeout_sd=1 timeout_ack=1 abort_ack=1 abort_canvas=1 transport=1");$finish;
 end
 initial begin #10000000;$fatal(1,"watchdog");end
endmodule
