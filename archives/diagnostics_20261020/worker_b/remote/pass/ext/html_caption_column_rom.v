// Synchronous fixed-layout glyph-column metadata. One-cycle ROM read.
module html_caption_column_rom #(
 parameter WORDS=8338,ADDR_BITS=14,
 parameter INIT_FILE="D:/FPGA/EG4S20-NoBot-HDMIProbe/output/html_fidelity/builds/hdmi_probe_001/work/design/user_source/hdl_source/ext/html_assets/html_caption_columns.hex"
)(input clk,input [ADDR_BITS-1:0] address,output [17:0] data);
`ifdef HTML_SIM
 reg [17:0] memory[0:WORDS-1];reg [17:0] q;
 initial $readmemh(INIT_FILE,memory);
 always @(posedge clk)q<=address<WORDS ? memory[address] : 18'h3fc00;
 assign data=q;
`else
 EG_LOGIC_BRAM #(.DATA_WIDTH_A(18),.ADDR_WIDTH_A(ADDR_BITS),.DATA_DEPTH_A(WORDS),
  .DATA_WIDTH_B(18),.ADDR_WIDTH_B(ADDR_BITS),.DATA_DEPTH_B(WORDS),.MODE("SP"),
  .REGMODE_A("NOREG"),.REGMODE_B("NOREG"),.RESETMODE("SYNC"),.BYTE_ENABLE(0),
  .IMPLEMENT("9K"),.INIT_FILE({INIT_FILE,".bin"})) storage(
  .clka(clk),.addra(address),.dia(18'd0),.cea(1'b1),.ocea(1'b1),.wea(1'b0),.rsta(1'b0),.bea(1'b1),.doa(data),
  .clkb(clk),.addrb({ADDR_BITS{1'b0}}),.dib(18'd0),.ceb(1'b0),.oceb(1'b0),.web(1'b0),.rstb(1'b0),.beb(1'b0),.dob());
`endif
endmodule
