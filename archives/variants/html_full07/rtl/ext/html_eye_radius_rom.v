// Two synchronous final-Q4-radius reads in one1024x9 true-dual-port9K.
// All padding entries are explicitly zero. No reset or whole-array clear.
module html_eye_radius_rom #(parameter INIT_FILE="rtl/ext/html_assets/html_eye_radius.hex")(
 input clk,input[9:0]address0,address1,output[6:0]radius0,radius1);
`ifdef HTML_SIM
 reg[8:0]memory[0:1023];reg[8:0]q0,q1;
 initial $readmemh(INIT_FILE,memory);
 always@(posedge clk)begin q0<=memory[address0];q1<=memory[address1];end
 assign radius0=q0[6:0];assign radius1=q1[6:0];
`else
 wire[8:0]q0,q1;
 EG_LOGIC_BRAM #(.DATA_WIDTH_A(9),.ADDR_WIDTH_A(10),.DATA_DEPTH_A(1024),
 .DATA_WIDTH_B(9),.ADDR_WIDTH_B(10),.DATA_DEPTH_B(1024),.MODE("DP"),
 .REGMODE_A("NOREG"),.REGMODE_B("NOREG"),.WRITEMODE_A("NORMAL"),.WRITEMODE_B("NORMAL"),
 .RESETMODE("SYNC"),.BYTE_ENABLE(0),.IMPLEMENT("9K"),.INIT_FILE({INIT_FILE,".bin"}))storage(
 .clka(clk),.addra(address0),.dia(9'd0),.cea(1'b1),.ocea(1'b1),.wea(1'b0),.rsta(1'b0),.bea(1'b1),.doa(q0),
 .clkb(clk),.addrb(address1),.dib(9'd0),.ceb(1'b1),.oceb(1'b1),.web(1'b0),.rstb(1'b0),.beb(1'b1),.dob(q1));
 assign radius0=q0[6:0];assign radius1=q1[6:0];
`endif
endmodule
