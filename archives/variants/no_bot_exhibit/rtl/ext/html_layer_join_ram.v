// One write and one synchronous read; no payload reset or collision reliance.
// This matches the verified cache-data inference pattern (simple dual-port).
module html_layer_join_ram(input clk,input write_en,input[5:0]write_addr,input[31:0]write_data,
 input read_en,input[5:0]read_addr,output reg[31:0]read_data);
 reg[31:0]memory[0:63];
 always@(posedge clk)begin
  if(write_en)memory[write_addr]<=write_data;
  if(read_en)read_data<=memory[read_addr];
 end
endmodule
