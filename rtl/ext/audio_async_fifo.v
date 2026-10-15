// Dual-clock PCM frame FIFO, synchronous read, binary/Gray pointers.
module audio_async_fifo #(parameter ADDRESS_BITS=11)(
 input wr_clk,wr_rst,wr_en,input [31:0] wr_data,
 output full,output [ADDRESS_BITS:0] wr_level,
 input rd_clk,rd_rst,rd_en,output reg [31:0] rd_data,output empty
);
localparam PW=ADDRESS_BITS+1;
reg [31:0] memory[0:(1<<ADDRESS_BITS)-1]; /* fehdl force_ram=1, ram_style="bram" */
reg [PW-1:0] wp,rp,wg,rg;
(* async_reg="true" *) reg [PW-1:0] rg_meta,rg_sync,wg_meta,wg_sync;
function [PW-1:0] ungray;
 input [PW-1:0] g;integer i;
 begin ungray[PW-1]=g[PW-1];for(i=PW-2;i>=0;i=i-1)ungray[i]=ungray[i+1]^g[i];end
endfunction
wire [PW-1:0] wp_next=wp+1'b1,rp_next=rp+1'b1;
assign full=wg=={~rg_sync[PW-1:PW-2],rg_sync[PW-3:0]};
assign empty=rg==wg_sync;
assign wr_level=wp-ungray(rg_sync);
// RAM ports have enables only. Pointer reset does not reset RAM/data registers.
always @(posedge wr_clk)begin
 if(wr_en&&!full&&!wr_rst)memory[wp[ADDRESS_BITS-1:0]]<=wr_data;
end
always @(posedge rd_clk)begin
 if(rd_en&&!empty&&!rd_rst)rd_data<=memory[rp[ADDRESS_BITS-1:0]];
end
always @(posedge wr_clk)begin
 if(wr_rst)begin wp<=0;wg<=0;rg_meta<=0;rg_sync<=0;end
 else begin
  rg_meta<=rg;rg_sync<=rg_meta;
  if(wr_en&&!full)begin wp<=wp_next;wg<=(wp_next>>1)^wp_next;end
 end
end
always @(posedge rd_clk)begin
 if(rd_rst)begin rp<=0;rg<=0;wg_meta<=0;wg_sync<=0;end
 else begin
  wg_meta<=wg;wg_sync<=wg_meta;
  if(rd_en&&!empty)begin rp<=rp_next;rg<=(rp_next>>1)^rp_next;end
 end
end
endmodule
