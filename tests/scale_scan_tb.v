`timescale 1ns/1ps
module scale_scan_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,start=0,valid=0,ending=0;reg[7:0]data=0;
 wire ready,req,done,found,wr,write_req;wire[31:0]addr,found_addr;wire[2:0]total;wire[3:0]error;
 reg[7:0]headers[0:1535];integer requests=0,count=0,i;reg[31:0]held_addr;
 bmp_read #(.ENABLE_SCALE(1),.TIMEOUT_CYCLES(20000)) dut(
 .clk(clk),.rst(rst),.ready(ready),.scan_start(start),.scan_start_sector(32'd0),
 .scan_max_sector(32'd5000),.scan_target_count(3'd2),.scan_done(done),.scan_found_valid(found),
 .scan_found_sector(found_addr),.scan_found_total(total),.load_start(1'b0),.load_abort(1'b0),
 .load_sector(32'd0),.scale_mode(2'd0),.sd_init_done(1'b1),.state_code(),
 .bmp_width(16'd640),.bmp_height(16'd480),.write_req(write_req),.write_req_ack(1'b0),
 .sd_sec_read(req),.sd_sec_read_addr(addr),.sd_sec_read_data(data),
 .sd_sec_read_data_valid(valid),.sd_sec_read_end(ending),.sd_sec_read_error(1'b0),
 .load_done(),.error_code(error),.bmp_data_wr_en(wr),.bmp_data());
 initial begin $readmemh("tests/scale_scan.hex",headers);repeat(5)@(negedge clk);rst=0;start=1;@(negedge clk);start=0;end
 initial forever begin
  wait(req&&!rst);repeat(17)@(negedge clk);held_addr=addr;
  if((requests==0&&addr!=0)||(requests==1&&addr!=1)||(requests==2&&addr!=340)||requests>2)
   $fatal(1,"incorrect discovery skip addr=%0d requests=%0d",addr,requests);
  for(i=0;i<512;i=i+1)begin
   @(negedge clk);valid=1;data=headers[requests*512+i];ending=(i==511);
   @(negedge clk);valid=0;ending=0;
   if(addr!=held_addr && i!=511)$fatal(1,"address changed midsector");
  end
  requests=requests+1;wait(!req);repeat(3)@(negedge clk);
 end
 always @(posedge clk)if(!rst)begin
  if(error||wr||write_req)$fatal(1,"scan touched pixel writer or error");
  if(found)begin
   if((count==0&&found_addr!=1)||(count==1&&found_addr!=340))$fatal(1,"incorrect found order");
   count=count+1;
  end
  if(done)begin
   if(count!=2||total!=2||!ready)$fatal(1,"incomplete scan");
   $display("TEST_PASS SCALE_SCAN rejected_width0=1 found=2 variable_file_skip=1 requests=%0d",requests);$finish;
  end
 end
 initial begin #1000000;$fatal(1,"watchdog");end
endmodule
