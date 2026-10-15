// Experimental finite scene row setup. A single shared multiply is used
// during line preparation, never one multiplier per component or per pixel.
// Descriptors arrive in CSS paint order. Renderer scans old and new scenes
// while the preceding output row is in flight; active spans remain ordered.
module html_layer_line_setup # (parameter TAG_BITS=5)(
 input clk,rst,flush,
 input component_valid,output component_ready,
 input [TAG_BITS-1:0] component_tag,
 input [20:0] texture_base,
 input signed [15:0] crop_x,crop_y,
 input [9:0] width,height,
 input signed [15:0] pivot_x_q4,pivot_y_q4,
 input [1:0] kind, // fixed0 / hero-family1 / giant2 / data-text3
 input signed [17:0] x_offset_q8,
 input signed [12:0] y_offset_q8,
 input [12:0] inv_scale_q12,input [7:0] opacity,
 input [8:0] canvas_y,input [9:0] canvas_start_x,
 output reg span_valid,input span_ready,
 output reg [TAG_BITS-1:0] span_tag,
 output reg [1:0] span_kind,
 output reg signed [31:0] span_x_origin_q16,
 output reg [16:0] span_x_step_q16,
 output reg signed [15:0] span_crop_x,
 output reg [9:0] span_width,
 output reg [20:0] span_row_base,
 output reg [7:0] span_opacity
);
 reg [2:0] state;
 reg [TAG_BITS-1:0] tag;
 reg [20:0] base;
 reg signed [15:0] cx,cy,px,py;
 reg [9:0] w,h,start_x;
 reg [8:0] dest_y;
 reg [1:0] role;
 reg signed [17:0] tx;
 reg signed [12:0] ty;
 reg [12:0] inv;
 reg [7:0] alpha;
 reg signed [17:0] row;
 reg row_active;
 wire signed [17:0] y_delta=$signed({2'b0,dest_y,7'b0})-($signed(py)<<<3)-($signed(ty)>>>1);
 wire signed [17:0] x_delta=$signed({1'b0,start_x,7'b0})-($signed(px)<<<3)-($signed(tx)>>>1);
 reg signed [17:0] mul_a,mul_b;
 reg signed [35:0] product;
 always @*begin
  mul_a=0;mul_b=0;
  if(state==1)begin mul_a=y_delta;mul_b=$signed({5'b0,inv});end
  if(state==3)begin mul_a=row;mul_b=$signed({8'b0,w});end
  if(state==4)begin mul_a=x_delta;mul_b=$signed({5'b0,inv});end
 end
 // One multiplication site is time shared by Y inverse, row stride and X
 // origin; the scheduler provides enough preparation clocks per scanline.
 always @(posedge clk)if(state==1||state==3||state==4)product<=mul_a*mul_b;
 wire signed [35:0] hero_y=($signed(py)<<<15)+product;
 wire signed [35:0] hero_x=($signed(px)<<<12)+(product>>>3);
 wire signed [17:0] fixed_y=($signed({1'b0,dest_y,8'b0})-$signed(ty))>>>8;
 wire signed [17:0] source_y=(role==1&&inv!=4096)?(hero_y>>>19):fixed_y;
 wire signed [17:0] relative_y=source_y-$signed(cy);
 assign component_ready=state==0&&!flush;
 always @(posedge clk)begin
  if(rst||flush)begin state<=0;span_valid<=0;end
  else begin
   case(state)
    0:if(component_valid)begin
     tag<=component_tag;base<=texture_base;cx<=crop_x;cy<=crop_y;w<=width;h<=height;
     px<=pivot_x_q4;py<=pivot_y_q4;role<=kind;tx<=x_offset_q8;ty<=y_offset_q8;
     inv<=inv_scale_q12;alpha<=opacity;dest_y<=canvas_y;start_x<=canvas_start_x;state<=1;
    end
    1:state<=2;
    2:begin
     row<=relative_y;
     row_active<=alpha!=0 && w!=0 && h!=0 && relative_y>=0 && relative_y<$signed({8'b0,h});state<=3;
    end
    3:state<=4;
    4:begin span_row_base<=base+product[20:0];state<=5;end
    5:begin
     if(row_active)begin
      span_x_origin_q16<=(role==1&&inv!=4096)?hero_x:($signed({6'b0,start_x,16'b0})-($signed(tx)<<<8));
      span_x_step_q16<=(role==1)?{inv,4'b0}:17'd65536;
      span_tag<=tag;span_kind<=role;span_crop_x<=cx;span_width<=w;span_opacity<=alpha;
      span_valid<=1;state<=6;
     end else state<=0;
    end
    6:if(span_ready)begin span_valid<=0;state<=0;end
    default:begin state<=0;span_valid<=0;end
   endcase
  end
 end
endmodule
