`timescale 1ns/1ps
module storage_bmp_tb;
reg clk=0;always #5 clk=~clk;
reg rst=1,scan_start=0,load_start=0,load_abort=0,init_done=1;
reg[31:0] scan_first=0,scan_last=0,load_sector=7;
reg[2:0] target=1;
wire ready,scan_done,found_valid,write_req,sec_req,pixel_valid;
wire[31:0] found_sector,sec_addr;wire[2:0] found_total;
wire[3:0] state_code;wire[23:0] pixel;
reg ack=0,sec_valid=0,sec_end=0,sec_error=0;reg[7:0] sec_data=0;
wire load_done;wire[3:0] error_code;
reg[7:0] bytes[0:923135];reg[23:0] golden[0:307199];
integer pixels,found,done_count,checks,requests;
integer media_base=7,media_len=922112,offset_mode=0,fault=0;
reg compare_pixels=0;
bmp_read dut(.clk(clk),.rst(rst),.ready(ready),.scan_start(scan_start),.scan_start_sector(scan_first),.scan_max_sector(scan_last),.scan_target_count(target),.scan_done(scan_done),.scan_found_valid(found_valid),.scan_found_sector(found_sector),.scan_found_total(found_total),.load_start(load_start),.load_abort(load_abort),.load_sector(load_sector),.sd_init_done(init_done),.state_code(state_code),.bmp_width(16'd640),.bmp_height(16'd480),.write_req(write_req),.write_req_ack(ack),.sd_sec_read(sec_req),.sd_sec_read_addr(sec_addr),.sd_sec_read_data(sec_data),.sd_sec_read_data_valid(sec_valid),.sd_sec_read_end(sec_end),.bmp_data_wr_en(pixel_valid),.bmp_data(pixel),.sd_sec_read_error(sec_error),.load_done(load_done),.error_code(error_code));
// Sector-level media model: requested addresses, not a prearranged stream.
integer a,i,k,n;
initial begin
 forever begin
   wait(sec_req && !rst);a=sec_addr;requests=requests+1;
   for(i=0;i<512;i=i+1) begin
     @(negedge clk);
     if(fault==1 && a>media_base && i==20) begin sec_error=1;sec_valid=0; end
     else begin
       sec_valid=1;k=(a-media_base)*512+i;
       if(k>=0 && k<media_len) sec_data=bytes[k];else sec_data=0;
     end
     if(fault==2 && i==127) i=512;
   end
   @(negedge clk);sec_valid=0;sec_end=1;
   @(negedge clk);sec_end=0;sec_error=0;
   wait(!sec_req || rst);repeat(3) @(negedge clk);
 end
end
always @(posedge clk) begin
 ack<=write_req;
 if(pixel_valid) begin
   if(!compare_pixels) $fatal(1,"unexpected pixel");
   if(pixels>=307200 || pixel !== golden[pixels]) $fatal(1,"pixel mismatch index=%0d got=%06x expected=%06x",pixels,pixel,golden[pixels]);
   pixels=pixels+1;
 end
 if(found_valid) begin
   if(found_sector!=media_base) $fatal(1,"scan discovered wrong sector %0d",found_sector);
   found=found+1;
 end
 if(load_done) done_count=done_count+1;
end
task reset_dut;
 begin rst=1;repeat(5) @(negedge clk);rst=0;repeat(3) @(negedge clk);pixels=0;found=0;done_count=0; end
endtask
task scan_one;
 begin scan_first=0;scan_last=media_base+1802;target=1;scan_start=1;@(negedge clk);scan_start=0;wait(!ready);wait(ready);repeat(2) @(negedge clk);if(!scan_done||found!=1) $fatal(1,"scan failed found=%0d",found);end
endtask
task load_one;
 begin load_sector=media_base;load_start=1;@(negedge clk);load_start=0;wait(!ready);wait(ready);repeat(3) @(negedge clk);end
endtask
task expect_reject;
 begin
   compare_pixels=0;reset_dut;load_one;
   if(error_code==0 || done_count!=0 || pixels!=0) $fatal(1,"malformed image accepted code=%0d",error_code);
   checks=checks+1;
 end
endtask
initial begin
 pixels=0;found=0;done_count=0;checks=0;requests=0;
 for(n=1;n<=3;n=n+1) begin
   case(n)
   1:begin $readmemh("tb/storage_data/bmp1.hex",bytes,0,922111);$readmemh("tb/storage_data/pixels1.hex",golden);end
   2:begin $readmemh("tb/storage_data/bmp2.hex",bytes,0,922111);$readmemh("tb/storage_data/pixels2.hex",golden);end
   3:begin $readmemh("tb/storage_data/bmp3.hex",bytes,0,922111);$readmemh("tb/storage_data/pixels3.hex",golden);end
   endcase
   compare_pixels=1;reset_dut;media_base=n*7;scan_one;load_one;
   if(pixels!=307200 || done_count!=1 || error_code!=0) $fatal(1,"load failed img=%0d px=%0d done=%0d err=%0d",n,pixels,done_count,error_code);
   $display("PASS BMP%0d scan + %0d pixel comparisons",n,pixels);checks=checks+1;
 end
 // Non-54 pixel offset crosses sector boundary, still 640*480 pixels.
 for(k=921653;k>=54;k=k-1) bytes[k+970]=bytes[k];
 for(k=54;k<1024;k=k+1) bytes[k]=8'h5a;
 bytes[10]=0;bytes[11]=4;bytes[12]=0;bytes[13]=0;
 {bytes[5],bytes[4],bytes[3],bytes[2]}=922624;
 media_len=923136;reset_dut;load_one;
 if(pixels!=307200||done_count!=1) $fatal(1,"offset handling failed");checks=checks+1;
 // Independent malformed fields (restore source before each case).
 $readmemh("tb/storage_data/bmp1.hex",bytes,0,922111);media_len=922112;
 bytes[20]=1;expect_reject;bytes[20]=0;
 bytes[26]=2;expect_reject;bytes[26]=1;
 bytes[28]=32;expect_reject;bytes[28]=24;
 bytes[30]=1;expect_reject;bytes[30]=0;
 bytes[14]=12;expect_reject;bytes[14]=40;
 bytes[10]=20;expect_reject;bytes[10]=54;
 {bytes[25],bytes[24],bytes[23],bytes[22]}=-480;expect_reject;
 $readmemh("tb/storage_data/bmp1.hex",bytes,0,922111);
 {bytes[5],bytes[4],bytes[3],bytes[2]}=54;expect_reject;
 // Short header sector and transport error must not succeed.
 $readmemh("tb/storage_data/bmp1.hex",bytes,0,922111);fault=2;expect_reject;fault=0;
 $readmemh("tb/storage_data/pixels1.hex",golden);compare_pixels=1;fault=1;reset_dut;load_one;
 if(error_code==0||done_count!=0) $fatal(1,"read error not propagated");checks=checks+1;fault=0;
 $display("TEST_PASS storage_bmp checks=%0d sector_requests=%0d",checks,requests);$finish;
end
initial begin #200000000;$fatal(1,"storage_bmp timeout state=%0d",state_code);end
endmodule
