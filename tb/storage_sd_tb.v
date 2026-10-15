`timescale 1ns/1ps
module storage_sd_tb;
reg clk=0;always #5 clk=~clk;reg rst=1,req=0;
wire cs,sck,mosi,init_done,init_error,valid,done,read_error;wire[7:0] data;wire[3:0] error;
integer count,checks=0;
sd_card_top #(.SPI_LOW_SPEED_DIV(1),.INIT_TIMEOUT_CYCLES(5000),.RESPONSE_TIMEOUT_BYTES(16),.TOKEN_TIMEOUT_BYTES(8)) dut(
.clk(clk),.rst(rst),.SD_nCS(cs),.SD_DCLK(sck),.SD_MOSI(mosi),.SD_MISO(1'b1),.sd_init_done(init_done),.sd_init_error(init_error),.sd_sec_read_error(read_error),.sd_error_code(error),.sd_sec_read(req),.sd_sec_read_addr(32'h12345),.sd_sec_read_data(data),.sd_sec_read_data_valid(valid),.sd_sec_read_end(done),.sd_sec_write(1'b0),.sd_sec_write_addr(32'd0),.sd_sec_write_data(8'd0),.sd_sec_write_data_req(),.sd_sec_write_end());
always @(posedge clk) if(valid) begin
 if(data !== (count & 255)) $fatal(1,"SD payload wrong index=%0d data=%02x",count,data);
 count=count+1;
end
task reset_case;input integer m;
 begin rst=1;req=0;dut.spi_master_m0.mode=m;count=0;repeat(5) @(negedge clk);rst=0;end
endtask
task read_case;input integer m;input integer expected_error;
 begin
  reset_case(m);wait(init_done);@(negedge clk);req=1;wait(done);@(negedge clk);req=0;
  if(read_error !== (expected_error!=0) || error!=expected_error) $fatal(1,"SD error expected=%0d got=%0d pulse=%b",expected_error,error,read_error);
  if(count != ((m==4)?0:512))$fatal(1,"SD length %0d",count);
  if(dut.spi_master_m0.last_addr!=32'h12345)$fatal(1,"block addressing corrupted");
  if(dut.spi_master_m0.acmd41_count<2)$fatal(1,"ACMD41 retry not exercised");
  checks=checks+1;$display("PASS sd_read mode=%0d bytes=%0d err=%0d",m,count,error);repeat(5)@(negedge clk);
 end
endtask
initial begin
 read_case(0,0);read_case(3,6);read_case(4,5);
 reset_case(1);wait(init_error);if(error!=1||init_done)$fatal(1,"missing-card timeout failed");checks=checks+1;
 reset_case(2);wait(init_error);if(error!=2||init_done)$fatal(1,"CMD8 echo not checked");checks=checks+1;
 reset_case(5);wait(init_error);if(error!=3||init_done)$fatal(1,"SDSC accepted as block addressed");checks=checks+1;
 $display("TEST_PASS storage_sd checks=%0d (byte-boundary SD protocol model)",checks);$finish;
end
initial begin #2000000;$fatal(1,"storage_sd timeout state=%0d",dut.sd_card_sec_read_write_m0.state);end
endmodule

// Behavioral byte transport deliberately replaces spi_master for this test only.
// It interprets real command bytes and emits realistic delayed response/payload bytes.
module spi_master(input sys_clk,rst,output nCS,DCLK,MOSI,input MISO,CPOL,CPHA,nCS_ctrl,input[15:0]clk_div,input wr_req,output reg wr_ack,input[7:0]data_in,output reg[7:0]data_out);
integer mode=0,stage=0,cmd_pos=0,qread=0,qwrite=0,acmd41_count=0;
reg[7:0] cmdbytes[0:5];reg[7:0]q[0:1023];reg[31:0]last_addr;reg[15:0] crc;integer j,b;
assign nCS=nCS_ctrl;assign DCLK=CPOL;assign MOSI=1;
task push;input[7:0] v;begin q[qwrite]=v;qwrite=qwrite+1;end endtask
task response;
 begin
  qread=0;qwrite=0;
  case(cmdbytes[0]&8'h3f)
  0:push(1);
  8:begin push(1);push(0);push(0);push(1);push(mode==2?8'hab:8'haa);end
  55:push(1);
  41:begin acmd41_count=acmd41_count+1;push(acmd41_count<2?1:0);if(cmdbytes[1]!=8'h40)$fatal(1,"HCS not set");end
  58:begin push(0);push(mode==5?8'h80:8'hc0);push(8'hff);push(8'h80);push(0);end
  17:begin
   last_addr={cmdbytes[1],cmdbytes[2],cmdbytes[3],cmdbytes[4]};push(0);
   if(mode!=4)begin
    push(8'hff);push(8'hfe);crc=0;
    for(j=0;j<512;j=j+1) begin
     push(j&255);crc=crc^((j&255)<<8);
     for(b=0;b<8;b=b+1)if(crc[15])crc=(crc<<1)^16'h1021;else crc=crc<<1;
    end
    push(crc[15:8]);push(crc[7:0]^(mode==3?8'h1:8'h0));
   end
  end
  16,24,25:$fatal(1,"Forbidden/unneeded command %0d",cmdbytes[0]&63);
  default:$fatal(1,"Unexpected command %0d",cmdbytes[0]&63);
  endcase
 end
endtask
always @(posedge sys_clk)begin
 if(rst)begin wr_ack<=0;data_out<=255;stage=0;cmd_pos=0;qread=0;qwrite=0;acmd41_count=0;last_addr=0;end
 else case(stage)
 0:if(wr_req)begin
  data_out<=255;
  if(!nCS_ctrl && mode!=1)begin
   if(qread<qwrite)begin data_out<=q[qread];qread=qread+1;end
   else if(cmd_pos>0)begin
    cmdbytes[cmd_pos]=data_in;
    if(cmd_pos==5)begin cmd_pos=0;response;end else cmd_pos=cmd_pos+1;
   end else if(data_in[7:6]==2'b01)begin cmdbytes[0]=data_in;cmd_pos=1;end
  end
  wr_ack<=1;stage=1;
 end
 1:begin wr_ack<=0;stage=2;end
 2:stage=0;
 endcase
end
endmodule
