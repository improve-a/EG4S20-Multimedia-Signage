// One-cycle8-bit ROM for serial frame-palette preparation; one BRAM9K.
module html_osd_swap_rom #(
 parameter INIT_FILE="D:/FPGA/EG4S20-NoBot-HDMIProbe/output/html_fidelity/builds/hdmi_probe_001/work/design/user_source/hdl_source/ext/html_assets/html_osd_swap_font.hex"
)(input wire clk,input wire [9:0] address,output wire [7:0] data);
`ifdef HTML_SIM
 reg [7:0] memory[0:1023];reg [7:0] q;
 initial $readmemh(INIT_FILE,memory);
 always @(posedge clk)q<=memory[address];
 assign data=q;
`else
 EG_LOGIC_BRAM #(.DATA_WIDTH_A(8),.ADDR_WIDTH_A(10),.DATA_DEPTH_A(1024),
  .DATA_WIDTH_B(8),.ADDR_WIDTH_B(10),.DATA_DEPTH_B(1024),.MODE("SP"),
  .REGMODE_A("NOREG"),.REGMODE_B("NOREG"),.RESETMODE("SYNC"),.BYTE_ENABLE(0),
  .IMPLEMENT("9K"),.INIT_FILE({INIT_FILE,".bin"})) storage(
  .clka(clk),.addra(address),.dia(8'd0),.cea(1'b1),.ocea(1'b1),.wea(1'b0),.rsta(1'b0),.bea(1'b1),.doa(data),
  .clkb(clk),.addrb(10'd0),.dib(8'd0),.ceb(1'b0),.oceb(1'b0),.web(1'b0),.rstb(1'b0),.beb(1'b0),.dob());
`endif
endmodule
