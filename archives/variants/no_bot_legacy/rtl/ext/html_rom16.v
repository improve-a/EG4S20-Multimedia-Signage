// One-cycle initialized ROM. Explicit 32K implementation avoids consuming the
// 9K memories used by the existing video/audio FIFOs. No pixel data is altered.
// EG_LOGIC_BRAM interface/IMPLEMENT are from the installed TD 6.2.168116 macro
// declaration and Anlogic TN308 v1.2 section 4.2. Functional tests define HTML_SIM.
module html_rom16 #(
 parameter WORDS=2048, ADDR_BITS=11,
 parameter INIT_FILE="NONE"
)(input clk,input [ADDR_BITS-1:0] address,output [15:0] data);
`ifdef HTML_SIM
 reg [15:0] memory[0:WORDS-1];
 reg [15:0] q;
 initial $readmemh(INIT_FILE,memory);
 always @(posedge clk)q <= address<WORDS ? memory[address] : 16'd0;
 assign data=q;
`else
 EG_LOGIC_BRAM #(
  .DATA_WIDTH_A(16),.ADDR_WIDTH_A(ADDR_BITS),.DATA_DEPTH_A(WORDS),
  .DATA_WIDTH_B(16),.ADDR_WIDTH_B(ADDR_BITS),.DATA_DEPTH_B(WORDS),
  .MODE("SP"),.REGMODE_A("NOREG"),.REGMODE_B("NOREG"),
  .WRITEMODE_A("NORMAL"),.WRITEMODE_B("NORMAL"),.RESETMODE("SYNC"),
  .BYTE_ENABLE(0),.IMPLEMENT("32K"),.INIT_FILE({INIT_FILE,".bin"})
 ) storage(
  .clka(clk),.addra(address),.dia(16'd0),.cea(1'b1),.ocea(1'b1),
  .wea(1'b0),.rsta(1'b0),.bea(1'b1),.doa(data),
  .clkb(clk),.addrb({ADDR_BITS{1'b0}}),.dib(16'd0),.ceb(1'b0),.oceb(1'b0),
  .web(1'b0),.rstb(1'b0),.beb(1'b0),.dob()
 );
`endif
endmodule
