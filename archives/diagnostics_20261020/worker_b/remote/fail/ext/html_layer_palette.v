// Exact24bit palette, three8bit ROM planes. Address is page*512+index.
// Explicit9K selects keep remaining32K banks available for motion/joins.
module html_layer_palette_plane #(parameter INIT_FILE="NONE")(
 input clk,input enable,input[11:0]address,output[7:0]data);
`ifdef HTML_SIM
 reg[7:0]memory[0:3071];reg[7:0]q;initial $readmemh(INIT_FILE,memory);
 always@(posedge clk)if(enable)q<=memory[address];assign data=q;
`else
 EG_LOGIC_BRAM #(.DATA_WIDTH_A(8),.ADDR_WIDTH_A(12),.DATA_DEPTH_A(3072),.DATA_WIDTH_B(8),.ADDR_WIDTH_B(12),.DATA_DEPTH_B(3072),
 .MODE("SP"),.REGMODE_A("NOREG"),.REGMODE_B("NOREG"),.WRITEMODE_A("NORMAL"),.WRITEMODE_B("NORMAL"),.RESETMODE("SYNC"),.BYTE_ENABLE(0),.IMPLEMENT("9K"),.INIT_FILE({INIT_FILE,".bin"}))storage(
 .clka(clk),.addra(address),.dia(8'd0),.cea(enable),.ocea(1'b1),.wea(1'b0),.rsta(1'b0),.bea(1'b1),.doa(data),
 .clkb(clk),.addrb(12'd0),.dib(8'd0),.ceb(1'b0),.oceb(1'b0),.web(1'b0),.rstb(1'b0),.beb(1'b0),.dob());
`endif
endmodule
module html_layer_palette(input clk,input enable,input[11:0]address,output[23:0]data);
 html_layer_palette_plane #(.INIT_FILE("D:/FPGA/EG4S20-NoBot/output/html_fidelity/builds/no_bot_legacy_004/work/design/user_source/hdl_source/ext/html_assets/html_layer_palette_r.hex"))r(clk,enable,address,data[23:16]);
 html_layer_palette_plane #(.INIT_FILE("D:/FPGA/EG4S20-NoBot/output/html_fidelity/builds/no_bot_legacy_004/work/design/user_source/hdl_source/ext/html_assets/html_layer_palette_g.hex"))g(clk,enable,address,data[15:8]);
 html_layer_palette_plane #(.INIT_FILE("D:/FPGA/EG4S20-NoBot/output/html_fidelity/builds/no_bot_legacy_004/work/design/user_source/hdl_source/ext/html_assets/html_layer_palette_b.hex"))b(clk,enable,address,data[7:0]);
endmodule
