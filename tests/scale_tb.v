`timescale 1ns/1ps
module scale_tb;
 parameter CASE=0, BYTE_GAP=2;
 localparam CARD_BYTES=(CASE==0)?230912:(CASE==1)?173568:(CASE==2)?692736:(CASE==3)?922112:(CASE==4)?230912:(CASE==5)?172544:(CASE==6)?172032:512;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,init=0,start=0,abort=0,ack=0;
 reg [1:0] mode;
 wire ready,request,done,wr;wire [31:0] address;wire [23:0] pixel;
 wire [3:0] error,state;
 reg [7:0] data=0;reg valid=0,ending=0,sd_error=0;
 reg [7:0] card [0:1048575];reg [23:0] golden [0:307199];
 reg [255:0] card_name,golden_name;
 integer cycle=0,count=0,requests=0,ack_wait=0;
 integer pending=0,index=0,gap=0,end_wait=0,last_wr=-999,last_request=-1,grant_wait=0;
 reg busy=0;reg [31:0] sector;
 bmp_read #(.ENABLE_SCALE(1),.TIMEOUT_CYCLES(1000000)) dut(
 .clk(clk),.rst(rst),.ready(ready),.scan_start(1'b0),.scan_start_sector(32'd0),
 .scan_max_sector(32'd0),.scan_target_count(3'd1),.scan_done(),.scan_found_valid(),
 .scan_found_sector(),.scan_found_total(),.load_start(start),.load_abort(abort),
 .load_sector(32'd17),.scale_mode(mode),.sd_init_done(init),.state_code(state),
 .bmp_width(16'd640),.bmp_height(16'd480),.write_req(request),.write_req_ack(ack),
 .sd_sec_read(pending_read),.sd_sec_read_addr(address),.sd_sec_read_data(data),
 .sd_sec_read_data_valid(valid),.sd_sec_read_end(ending),.sd_sec_read_error(sd_error),
 .load_done(done),.error_code(error),.bmp_data_wr_en(wr),.bmp_data(pixel));
 wire pending_read;
 initial begin
  $sformat(card_name,"tests/scale_card_%0d.hex",CASE);
  $sformat(golden_name,"tests/scale_golden_%0d.hex",CASE);
  $readmemh(card_name,card,0,CARD_BYTES-1);$readmemh(golden_name,golden);
  mode=(CASE==4||CASE==6)?1:0;
  repeat(5) @(negedge clk);rst=0;init=1;
  repeat(4) @(negedge clk);start=1;@(negedge clk);start=0;
 end
 // Model arbitrary SD gaps, including end concurrent with final valid byte.
 // Requests must retain an address until end; after a full sector the card can
 // return immediately, much faster than the real SPI bus (no per-byte ready).
 always @(negedge clk) begin
  valid=0;ending=0;ack=0;
  if(!rst) begin
   cycle=cycle+1;
   if(request) begin ack_wait=ack_wait+1;if(ack_wait==37)ack=1;end
   if(!busy && pending_read) grant_wait=grant_wait+1;
   if(!busy && pending_read && grant_wait>=12+(requests%23)) begin
    if(request) $fatal(1,"SD data request before SDRAM ack");
    if(requests==0 && address!=17) $fatal(1,"wrong header address");
    if(requests==1 && address!=17) $fatal(1,"wrong pixel restart address");
    if(requests>1 && address!=last_request+1) $fatal(1,"non-sequential address");
    sector=address;last_request=address;requests=requests+1;busy=1;index=0;gap=0;
    if(requests==2)mode=(mode==1)?0:1;
   end
   if(busy) begin
    if(address!=sector) $fatal(1,"sector address changed during receive");
    if(gap==0) begin
     data=card[(sector-17)*512+index];valid=1;
     if(index==511) begin ending=1;busy=0;gap=0;grant_wait=0;end
     else begin index=index+1;gap=BYTE_GAP+(index%7==0?3:0);end
    end else gap=gap-1;
   end
  end
 end
 always @(posedge clk) if(!rst) begin
  if(wr) begin
   if(count>=307200) $fatal(1,"canvas overflow");
   if(pixel!==golden[count]) $fatal(1,"pixel %0d got %h expected %h",count,pixel,golden[count]);
   if(cycle-last_wr<16) $fatal(1,"unsafe output rate");
   count=count+1;last_wr=cycle;
  end
  if(error) $fatal(1,"loader error %0d state %0d",error,state);
  if(done) begin
   if(count!=307200) $fatal(1,"premature done count %0d",count);
   if(busy||pending_read) $fatal(1,"load_done with pending SD transaction");
   $display("TEST_PASS SCALE case=%0d count=%0d requests=%0d cycles=%0d gap=%0d",CASE,count,requests,cycle,BYTE_GAP);
   $finish;
  end
  if(cycle>40000000) $fatal(1,"watchdog count=%0d state=%0d",count,state);
 end
endmodule
