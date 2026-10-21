`timescale 1ns/1ps
module html_hfxl_header_tb;
 parameter ENABLE_HFXL=1;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,start=0,valid=0,ending=0;
 reg [7:0] data=0;
 wire req,done,found,write_req,ready;
 wire [31:0] address,found_sector;
 wire [3:0] found_total,error;
 reg [3:0] target=1;
 reg [31:0] scan_max=17;
 reg [7:0] header[0:511];
 integer i,c,n=0,observed=0,requests=0,page=0,cycles=0;
 integer sent=0,wait_gap=0,grant=0;reg busy=0;
 reg [31:0] expected_sector=17,locked_addr=17;
 integer offset,scene_offset,length,expected_found,header_count=512;
 bmp_scale_read #(.ENABLE_HFXL(ENABLE_HFXL),.TIMEOUT_CYCLES(10000)) dut(
 .clk(clk),.rst(rst),.ready(ready),.scan_start(start),.scan_start_sector(32'd17),.scan_max_sector(scan_max),
 .scan_target_count(target),.scan_done(done),.scan_found_valid(found),.scan_found_sector(found_sector),.scan_found_total(found_total),
 .load_start(1'b0),.load_abort(1'b0),.load_sector(32'd0),.scale_mode(2'd0),.sd_init_done(1'b1),.state_code(),
 .write_req(write_req),.write_req_ack(1'b0),.sd_sec_read(req),.sd_sec_read_addr(address),
 .sd_sec_read_data(data),.sd_sec_read_data_valid(valid),.sd_sec_read_end(ending),.sd_sec_read_error(1'b0),
 .load_done(),.error_code(error),.bmp_data_wr_en(),.bmp_data());
 task put32;input integer a;input [31:0] v;begin
  header[a]=v[7:0];header[a+1]=v[15:8];header[a+2]=v[23:16];header[a+3]=v[31:24];
 end endtask
 task make_header;input integer which;input integer p;begin
  for(i=0;i<512;i=i+1)header[i]=0;
  offset=(which==1)?250368:512;scene_offset=offset+921600;length=scene_offset+1200128;
  header[0]=8'h42;header[1]=8'h4d;put32(2,length);put32(10,offset);put32(14,40);
  put32(18,640);put32(22,480);header[26]=1;header[28]=24;
  put32(80,32'h4c584648);header[84]=1;header[86]=32;
  put32(88,scene_offset);put32(92,1200128);put32(96,p*300032);header[100]=p;header[102]=6;
  put32(104,32'h26c01015);
  case(which)
   2:header[80]=0;
   3:header[84]=2;
   4:header[86]=31;
   5:put32(88,scene_offset+512);
   6:put32(92,1200127);
   7:put32(92,2098176);
   8:put32(96,1);
   9:put32(96,1843200);
   10:header[100]=6;
   11:header[102]=8;
   12:header[108]=1;
   13:put32(2,length+1);
   14:put32(18,639);
   15:put32(14,108);
   16:put32(88,32'hfffffe00);
   17:put32(96,32'hfffffe00);
   18:begin put32(92,0);put32(2,scene_offset);end
   19:begin put32(92,1024);put32(2,scene_offset+1024);end
   20:begin put32(10,54);put32(2,921654);put32(80,0);end
   21:begin put32(10,54);put32(2,921654+65537);put32(80,0);end
   22:begin put32(10,1048577);put32(2,1048577+921600);put32(80,0);end
   23:put32(22,32'hfffffe20);
   24:put32(2,32'hffffffff);
   25:put32(30,1);
  endcase
 end endtask
 always @(negedge clk)begin
  valid=0;ending=0;
  if(!rst)begin
   cycles=cycles+1;
   if(!busy&&req)begin
    grant=grant+1;
    if(grant==9)begin
     if(address!==expected_sector)$fatal(1,"case %0d addr %0d expected %0d",c,address,expected_sector);
     locked_addr=address;busy=1;sent=0;wait_gap=0;requests=requests+1;
    end
   end
   if(busy)begin
    if(address!==locked_addr)$fatal(1,"address changed in sector");
    if(wait_gap==0)begin
     data=header[sent];valid=1;sent=sent+1;wait_gap=sent%4;
     if(sent==header_count)begin ending=1;busy=0;grant=0;end
    end else wait_gap=wait_gap-1;
   end
   if(cycles>100000)$fatal(1,"watchdog");
  end
 end
 always @(posedge clk)if(!rst)begin
  if(write_req)$fatal(1,"scan issued a write");
  if(found)begin
   if(found_sector!==expected_sector)$fatal(1,"catalog address");
   observed=observed+1;
   expected_sector=expected_sector+(length+511)/512;
   if(target==6)make_header(0,observed);
  end
 end
 initial begin
  for(c=0;c<28;c=c+1)begin
   @(posedge clk);#1;rst=1;start=0;busy=0;grant=0;observed=0;requests=0;cycles=0;expected_sector=17;
   target=(c==26&&ENABLE_HFXL)?6:1;scan_max=(target==6)?100000:17;header_count=(c==27)?511:512;
   make_header(c>=26?0:c,0);
   expected_found=((c==0||c==1||c==26)&&ENABLE_HFXL)?target:0;
   // A small trailer within the original 64KiB bound is still an ordinary BMP.
   if(c==18||c==19||c==20)expected_found=1;
   repeat(6)@(posedge clk);#1;rst=0;start=1;@(posedge clk);#1;start=0;
   wait(done);repeat(8)@(posedge clk);#1;
   if(observed!=expected_found)$fatal(1,"case %0d HFXL%0d got %0d expected %0d",c,ENABLE_HFXL,observed,expected_found);
   if(c==27&&error!=2)$fatal(1,"short header accepted");
   if(c!=27&&error!=0)$fatal(1,"unexpected scan error");
   n=n+1;
  end
  $display("TEST_PASS HFXL%0d %0d headers, exact catalog file jumps, ordinary limits retained",ENABLE_HFXL,n);$finish;
 end
endmodule
