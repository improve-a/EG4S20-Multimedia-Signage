// Fixed finite scene descriptor ROM,32-bit words, one-cycle read.
module html_layer_descriptor_rom #(parameter INIT_FILE="D:/FPGA/EG4S20-NoBot-RCA-20261020/builds/rca_locked_only_001/work/design/user_source/hdl_source/ext/html_assets/html_layer_descriptors.hex")(
 input clk,input[9:0]address,output[31:0]data);
`ifdef HTML_SIM
 reg[31:0]memory[0:767];reg[31:0]q;initial $readmemh(INIT_FILE,memory);
 always@(posedge clk)q<=address<768?memory[address]:32'h000000ff;
 assign data=q;
`else
 // Both read ports address adjacent16-bit halves of the same1536word
 // ROM; this fits one true-dual-port32K instead of two32-bit banks.
 EG_LOGIC_BRAM #(.DATA_WIDTH_A(16),.ADDR_WIDTH_A(11),.DATA_DEPTH_A(1536),.DATA_WIDTH_B(16),.ADDR_WIDTH_B(11),.DATA_DEPTH_B(1536),
 .MODE("DP"),.REGMODE_A("NOREG"),.REGMODE_B("NOREG"),.WRITEMODE_A("NORMAL"),.WRITEMODE_B("NORMAL"),.RESETMODE("SYNC"),.BYTE_ENABLE(0),.IMPLEMENT("32K"),.INIT_FILE("D:/FPGA/EG4S20-NoBot-RCA-20261020/builds/rca_locked_only_001/work/design/user_source/hdl_source/ext/html_assets/html_layer_descriptors16.hex.bin"))storage(
 .clka(clk),.addra({address,1'b0}),.dia(16'd0),.cea(1'b1),.ocea(1'b1),.wea(1'b0),.rsta(1'b0),.bea(1'b1),.doa(data[15:0]),
 .clkb(clk),.addrb({address,1'b1}),.dib(16'd0),.ceb(1'b1),.oceb(1'b1),.web(1'b0),.rstb(1'b0),.beb(1'b1),.dob(data[31:16]));
`endif
endmodule
