`timescale 1ns/1ps
// Catalogue probe for the ordinary-BMP scanner with one real 800x600 page.
// MODE 0: 10 authored BMPs (5 x 640x480, 1 x 800x600, 4 x 320x480) must be
//         found in order by the unchanged bfSize skip rule.
// MODE 1..4: the 800x600 header is mutated (width 801, height 601, negative
//         height, wrong bfSize); only 9 pages may be catalogued and the
//         mutated page must never be reported.
// MODE 5: the ordinary load path (scanning=0) is offered the 800x600 page and
//         must refuse it with error_code 1 and no write_req, so no scaler and
//         no loader can be started from an 800x600 file.
// Sectors outside an authored file start are blank, exactly like a card whose
// next file begins later; the bench makes no card or PHY claim.
module probe_bmp_scan_tb;
 parameter MODE=0,BAD_INDEX=5;
 parameter FIX_ROOT=".";
 reg clk=0;always#5 clk=~clk;
 reg rst=1,start=0,load=0,valid=0,ending=0;reg[7:0]data=0;
 wire ready,done,found,req,wr,load_done;wire[31:0]addr,foundaddr;
 wire[3:0]total,error,state;
 reg[7:0]headers[0:5119];
 reg[31:0]positions[0:9];
 integer count=0,requests=0,k,n,index,zeroes;
 reg[31:0]held;reg wr_seen=0;
 bmp_scale_read #(.ENABLE_HFXL(0),.TIMEOUT_CYCLES(20000)) dut(
  .clk(clk),.rst(rst),.ready(ready),.scan_start(start),.scan_start_sector(positions[0]),
  .scan_max_sector(32'd17504),.scan_target_count(4'd10),.scan_done(done),
  .scan_found_valid(found),.scan_found_sector(foundaddr),.scan_found_total(total),
  .load_start(load),.load_abort(1'b0),.load_sector(positions[BAD_INDEX]),.scale_mode(2'd0),
  .sd_init_done(1'b1),.state_code(state),.write_req(wr),.write_req_ack(1'b1),
  .sd_sec_read(req),.sd_sec_read_addr(addr),.sd_sec_read_data(data),
  .sd_sec_read_data_valid(valid),.sd_sec_read_end(ending),.sd_sec_read_error(1'b0),
  .load_done(load_done),.error_code(error),.bmp_data_wr_en(),.bmp_data());

 always@(posedge clk)begin
  if(wr)wr_seen<=1;
  if(!rst&&found)begin
   if(MODE==0)begin
    if(count>=10||foundaddr!==positions[count])$fatal(1,"scan found%0d addr%0d expected%0d",count,foundaddr,positions[count]);
   end else if(foundaddr==positions[BAD_INDEX])$fatal(1,"mutated 800x600 header was catalogued");
   count=count+1;
  end
 end

 initial begin
  $readmemh({FIX_ROOT,"/headers.hex"},headers);
  $readmemh({FIX_ROOT,"/positions.hex"},positions);
  case(MODE)
   1:headers[BAD_INDEX*512+18]=headers[BAD_INDEX*512+18]^8'h01; // 800 -> 801
   2:headers[BAD_INDEX*512+22]=headers[BAD_INDEX*512+22]^8'h01; // 600 -> 601
   3:headers[BAD_INDEX*512+25]=8'h80;                           // signed32 height is negative
   4:headers[BAD_INDEX*512+3]=headers[BAD_INDEX*512+3]^8'h01;   // bfSize below payload
  endcase
  repeat(6)@(negedge clk);rst=0;wait(ready);
  if(MODE==5)begin @(negedge clk);load=1;@(negedge clk);load=0;wait(error!=0);@(negedge clk);
   if(error!=1)$fatal(1,"load path accepted 800x600 with code%0d",error);
   if(wr_seen)$fatal(1,"load path asserted write_req for 800x600");
   $display("TEST_PASS probe_bmp_scan mode5 ordinary_load_refused error%0d requests%0d",error,requests);$finish;
  end
  @(negedge clk);start=1;@(negedge clk);start=0;
  wait(done);repeat(4)@(negedge clk);
  if(!ready||error!=0)$fatal(1,"scan end ready%0d error%0d",ready,error);
  if(MODE==0)begin
   if(total!=10||count!=10)$fatal(1,"scan total%0d count%0d expected10",total,count);
   if(requests!=10)$fatal(1,"scan requests%0d expected10 header reads",requests);
   $display("TEST_PASS probe_bmp_scan mode0 catalog10 requests%0d total%0d include800x600_at%0d",requests,total,positions[5]);
  end else begin
   if(total!=9||count!=9)$fatal(1,"scan total%0d count%0d expected9",total,count);
   if(requests<10)$fatal(1,"mutated scan requests%0d",requests);
   $display("TEST_PASS probe_bmp_scan mode%0d rejected800x600 total%0d count%0d requests%0d",MODE,total,count,requests);
  end
  $finish;
 end

 initial forever begin
  wait(req&&!rst);held=addr;index=-1;
  for(n=0;n<10;n=n+1)if(addr==positions[n])index=n;
  requests=requests+1;
  for(k=0;k<512;k=k+1)begin
   repeat(2)@(negedge clk);
   if(addr!==held||!req)$fatal(1,"sector request changed before end");
   valid=1;data=(index<0)?8'h00:headers[index*512+k];
   @(negedge clk);valid=0;
  end
  ending=1;@(negedge clk);ending=0;wait(!req);repeat(2)@(negedge clk);
 end
 initial begin #200000000;$fatal(1,"scan watchdog total%0d state%0d",total,state);end
endmodule
