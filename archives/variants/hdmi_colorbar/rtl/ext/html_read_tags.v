// Carry format metadata across the unchanged SDRAM IP's variable read latency.
// One tag per accepted request; response ordering is the controller contract.
module html_read_tags(
 input clk,rst,request,input packed_pixel,half_pixel,black_pixel,
 input response,input [31:0] memory_data,
 output [31:0] pixel_data,output reg fault
);
 reg [2:0] tags[0:511];
 reg [8:0] wp,rp;
 reg [9:0] count;
 wire [2:0] tag=tags[rp];
 wire [15:0] pix=tag[1]?memory_data[31:16]:memory_data[15:0];
 wire [23:0] rgb={{pix[15:11],pix[15:13]},{pix[10:5],pix[10:9]},{pix[4:0],pix[4:2]}};
 assign pixel_data=tag[2]?32'd0:(tag[0]?{rgb,8'd0}:memory_data);
 always @(posedge clk)begin
  if(rst)begin wp<=0;rp<=0;count<=0;fault<=0;end
  else begin
   if(request)begin tags[wp]<={black_pixel,half_pixel,packed_pixel};wp<=wp+1'b1;end
   if(response)rp<=rp+1'b1;
   case({request,response})2'b10:count<=count+1'b1;2'b01:count<=count-1'b1;endcase
   if((request&&count==512&&!response)||(response&&count==0))fault<=1;
  end
 end
endmodule
