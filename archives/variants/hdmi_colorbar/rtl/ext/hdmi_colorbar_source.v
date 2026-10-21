// Standalone diagnostic RGB; timing still comes from the existing video path.
// At each line's first active sample, px is zero before the AXIS capture edge.
module hdmi_colorbar_source(input clk,rst,i_de,output reg [23:0] o_rgb);
 reg previous_de;reg[9:0] x;
 wire[9:0] px=previous_de?x:10'd0;
 always@(posedge clk)begin
  if(rst)begin previous_de<=0;x<=0;end
  else begin previous_de<=i_de;if(i_de)x<=previous_de?x+10'd1:10'd1;else x<=0;end
 end
 always@*begin
  if(rst||!i_de)o_rgb=24'h000000;
  else if(px<80)o_rgb=24'hffffff;
  else if(px<160)o_rgb=24'hffff00;
  else if(px<240)o_rgb=24'h00ffff;
  else if(px<320)o_rgb=24'h00ff00;
  else if(px<400)o_rgb=24'hff00ff;
  else if(px<480)o_rgb=24'hff0000;
  else if(px<560)o_rgb=24'h0000ff;
  else o_rgb=24'h000000;
 end
endmodule
