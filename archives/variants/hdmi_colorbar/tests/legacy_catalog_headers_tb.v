`timescale 1ns/1ps
// Actual ordinary-BMP scanner reads real delivery headers via bounded byteport.
// File bodies are skipped by declared bfSize; no SD PHY/physical card claim.
module legacy_catalog_headers_tb #(parameter FIXTURE_ROOT=".");
 reg clk=0;always#5 clk=~clk;reg rst=1,start=0,valid=0,ending=0;reg[7:0]data=0;
 wire ready,done,found,req;wire[31:0]addr,foundaddr;wire[3:0]total,error,state;
 reg[7:0]headers[0:5119];reg[31:0]positions[0:9];integer requests=0,count=0,index,k,n;reg[31:0]held;
 bmp_scale_read #(.ENABLE_HFXL(0))dut(.clk(clk),.rst(rst),.ready(ready),.scan_start(start),.scan_start_sector(positions[0]),.scan_max_sector(positions[9]+900),.scan_target_count(4'd10),.scan_done(done),.scan_found_valid(found),.scan_found_sector(foundaddr),.scan_found_total(total),.load_start(1'b0),.load_abort(1'b0),.load_sector(32'd0),.scale_mode(2'd0),.sd_init_done(1'b1),.state_code(state),.write_req(),.write_req_ack(1'b0),.sd_sec_read(req),.sd_sec_read_addr(addr),.sd_sec_read_data(data),.sd_sec_read_data_valid(valid),.sd_sec_read_end(ending),.sd_sec_read_error(1'b0),.load_done(),.error_code(error),.bmp_data_wr_en(),.bmp_data());
 always@(posedge clk)if(!rst&&found)begin
  if(count>=10||foundaddr!==positions[count])$fatal(1,"realheader scanfound%0d addr%0d expected%0d",count,foundaddr,positions[count]);count=count+1;
 end
 initial begin
  $readmemh({FIXTURE_ROOT,"/headers.hex"},headers);$readmemh({FIXTURE_ROOT,"/positions.hex"},positions);
  repeat(6)@(negedge clk);rst=0;wait(ready);@(negedge clk);start=1;@(negedge clk);start=0;
  wait(done);repeat(4)@(negedge clk);
  if(!ready||total!=10||count!=10||requests!=10||error!=0)$fatal(1,"realheader final counts%0d total%0d req%0d error%0d",count,total,requests,error);
  $display("TEST_PASS actualordinaryBMPscanner deliveryUI6_PN4 target10,640/320x480 offset512,bfSizecontiguousskip,exactLBAsfromFATmanifest,4bitcount10,lastfoundcompletion byteportmodeled");$finish;
 end
 initial forever begin
  wait(req&&!rst);held=addr;index=-1;for(n=0;n<10;n=n+1)if(addr==positions[n])index=n;
  if(index<0)$fatal(1,"unexpectedrealheader sector%0d",addr);requests=requests+1;
  for(k=0;k<512;k=k+1)begin
   repeat(3)@(negedge clk);if(addr!==held||!req)$fatal(1,"headerrequest changed beforeend");valid=1;data=headers[index*512+k];
   @(negedge clk);valid=0;
  end
  ending=1;@(negedge clk);ending=0;wait(!req);repeat(3)@(negedge clk);
 end
 initial begin #2000000;$fatal(1,"header scannerwatchdog");end
endmodule
