`timescale 1ns/1ps
// Sticky scan_done is an interface contract: discovery survives complete loads
// so the parent can select another image without repeating discovery.
module scale_scan_load_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,scan_start=0,load_start=0,ack=0,valid=0,ending=0;
 reg[7:0]data=0;wire ready,scan_done,found,req,write_req,wr,load_done;
 wire[31:0]address,found_sector;wire[2:0]total;wire[23:0]pixel;wire[3:0]error;
 reg[7:0]card[0:511];reg[23:0]golden[0:307199];
 integer n=0,busy=0,index=0,pixels=0,frames=0,requests=0;reg armed=0;
 bmp_read #(.ENABLE_SCALE(1),.TIMEOUT_CYCLES(1000000)) dut(
 .clk(clk),.rst(rst),.ready(ready),.scan_start(scan_start),.scan_start_sector(32'd17),
 .scan_max_sector(32'd17),.scan_target_count(3'd1),.scan_done(scan_done),.scan_found_valid(found),
 .scan_found_sector(found_sector),.scan_found_total(total),.load_start(load_start),.load_abort(1'b0),
 .load_sector(32'd17),.scale_mode(2'd0),.sd_init_done(1'b1),.state_code(),
 .bmp_width(16'd640),.bmp_height(16'd480),.write_req(write_req),.write_req_ack(ack),
 .sd_sec_read(req),.sd_sec_read_addr(address),.sd_sec_read_data(data),
 .sd_sec_read_data_valid(valid),.sd_sec_read_end(ending),.sd_sec_read_error(1'b0),
 .load_done(load_done),.error_code(error),.bmp_data_wr_en(wr),.bmp_data(pixel));
 initial begin
  $readmemh("tests/scale_card_7.hex",card);$readmemh("tests/scale_golden_7.hex",golden);
  repeat(5)@(negedge clk);rst=0;scan_start=1;@(negedge clk);scan_start=0;
  wait(scan_done);armed=1;
  for(n=0;n<2;n=n+1)begin
   @(negedge clk);load_start=1;@(negedge clk);load_start=0;
   wait(load_done);repeat(3)@(negedge clk);
  end
  if(frames!=2||requests!=5||total!=1||!scan_done)$fatal(1,"bad final contract");
  $display("TEST_PASS SCALE_SCAN_LOAD scan_done_sticky=1 scan_found_total=1 loads=2 pixels=614400 requests=%0d",requests);$finish;
 end
 always @(negedge clk)begin
  valid=0;ending=0;ack=write_req;
  if(!rst)begin
   if(busy==0&&req)begin busy=1;index=0;requests=requests+1;if(address!=17)$fatal(1,"wrong LBA");end
   else if(busy==1)begin
    valid=1;data=card[index];
    if(index==511)begin ending=1;busy=2;end else index=index+1;
   end else if(busy==2&&!req)busy=0;
  end
 end
 always @(posedge clk)if(!rst)begin
  if(error)$fatal(1,"unexpected loader error %0d",error);
  if(armed&&(!scan_done||total!=1))$fatal(1,"load cleared discovery status");
  if(found&&found_sector!=17)$fatal(1,"wrong discovered sector");
  if(wr)begin
   if(pixels>=307200||pixel!==golden[pixels])$fatal(1,"frame=%0d pixel=%0d mismatch",frames,pixels);
   pixels=pixels+1;
  end
  if(load_done)begin
   if(pixels!=307200||!scan_done||!ready)$fatal(1,"bad completed load contract");
   frames=frames+1;pixels=0;
  end
 end
 initial begin #150000000;$fatal(1,"watchdog");end
endmodule
