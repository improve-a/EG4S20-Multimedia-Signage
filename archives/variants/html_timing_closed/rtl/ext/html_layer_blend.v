// Experimental shared straight-alpha compositor, one transaction per clock.
// Numeric input texture layout is RRGGBBAA; palette/background is RRGGBB.
// Four small multiplies total: intrinsic-alpha x motion-opacity, then RGB
// signed differences x effective-alpha. No per-component arithmetic copies.
module html_layer_blend #(parameter TAG_BITS=12)(
 input clk,rst,input i_valid,
 input [TAG_BITS-1:0] i_tag,input [23:0] back_rgb,
 input [31:0] front_rgba,input [7:0] opacity,
 output reg o_valid,output reg [TAG_BITS-1:0] o_tag,output reg [23:0] o_rgb
);
 reg [3:0] valid;
 reg [TAG_BITS-1:0] tag0,tag1,tag2,tag3;
 reg [15:0] alpha_product;
 reg [23:0] front0,back0,back1,back2;
 reg [7:0] alpha1;
 reg signed [8:0] red1,green1,blue1;
 reg signed [17:0] red2,green2,blue2;
 reg [16:0] red3,green3,blue3;
 wire [16:0] alpha_rounded={1'b0,alpha_product}+17'd128;
 wire [16:0] alpha_divided=alpha_rounded+(alpha_rounded>>8);
 wire signed [17:0] rb=$signed({2'b0,back2[23:16],8'b0})-$signed({10'b0,back2[23:16]});
 wire signed [17:0] gb=$signed({2'b0,back2[15:8],8'b0})-$signed({10'b0,back2[15:8]});
 wire signed [17:0] bb=$signed({2'b0,back2[7:0],8'b0})-$signed({10'b0,back2[7:0]});
 wire [17:0] rr={1'b0,red3}+({1'b0,red3}>>8);
 wire [17:0] gr={1'b0,green3}+({1'b0,green3}>>8);
 wire [17:0] br={1'b0,blue3}+({1'b0,blue3}>>8);
 always @(posedge clk)begin
  if(rst)begin valid<=0;o_valid<=0;o_rgb<=0;o_tag<=0;end
  else begin
   valid<={valid[2:0],i_valid};o_valid<=valid[3];
   if(i_valid)begin alpha_product<=front_rgba[7:0]*opacity;front0<=front_rgba[31:8];back0<=back_rgb;tag0<=i_tag;end
   if(valid[0])begin
    alpha1<=alpha_divided[15:8];
    red1<=$signed({1'b0,front0[23:16]})-$signed({1'b0,back0[23:16]});
    green1<=$signed({1'b0,front0[15:8]})-$signed({1'b0,back0[15:8]});
    blue1<=$signed({1'b0,front0[7:0]})-$signed({1'b0,back0[7:0]});back1<=back0;tag1<=tag0;
   end
   if(valid[1])begin red2<=red1*$signed({1'b0,alpha1});green2<=green1*$signed({1'b0,alpha1});blue2<=blue1*$signed({1'b0,alpha1});back2<=back1;tag2<=tag1;end
   if(valid[2])begin red3<=rb+red2+18'sd128;green3<=gb+green2+18'sd128;blue3<=bb+blue2+18'sd128;tag3<=tag2;end
   if(valid[3])begin o_rgb<={rr[15:8],gr[15:8],br[15:8]};o_tag<=tag3;end
  end
 end
endmodule
