`timescale 1ns/1ps
module storage_spi_tb;
reg clk=0;always #5 clk=~clk;reg rst=1,req=0,miso=1;reg[7:0]tx=8'hA6;
wire cs,sck,mosi,ack;wire[7:0]rx;reg[7:0] observed=0;integer edges=0;
spi_master dut(.sys_clk(clk),.rst(rst),.nCS(cs),.DCLK(sck),.MOSI(mosi),.MISO(miso),.CPOL(1'b1),.CPHA(1'b1),.nCS_ctrl(1'b0),.clk_div(16'd1),.wr_req(req),.wr_ack(ack),.data_in(tx),.data_out(rx));
always @(negedge sck) if(!rst) begin miso=(8'h3c>>(7-edges))&1;end
always @(posedge sck) if(!rst && req)begin observed={observed[6:0],mosi};edges=edges+1;end
initial begin repeat(5)@(negedge clk);rst=0;repeat(3)@(negedge clk);req=1;wait(ack);#1;
 if(rx!=8'h3c||observed!=tx||edges!=8)$fatal(1,"SPI transfer rx=%h tx=%h edges=%d",rx,observed,edges);
 @(negedge clk);req=0;$display("TEST_PASS storage_spi mode3 MISO and MOSI 8 bits");$finish;end
initial begin #100000;$fatal(1,"SPI timeout");end
endmodule
