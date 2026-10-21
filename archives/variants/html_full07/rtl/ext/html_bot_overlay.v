// Source-faithful 104x100 textured character; eyes remain independent geometry.
// Five registered pixel stages. Motion/config change only at VS rising edges.
// 25MHz / (800*525) = 59.5238095Hz; keyframes below use that actual rate.
module html_bot_overlay #(
 parameter BODY_FILE="rtl/ext/html_assets/bot_body_argb4444.hex"
)(
 input wire clk,rst,i_hs,i_vs,i_de,
 input wire [23:0] i_rgb,
 input wire enable,page_event,
 input wire signed [1:0] page_direction,
 input wire speaking,syllable,
 input wire [7:0] audio_level,
 output reg o_hs,o_vs,o_de,
 output reg [23:0] o_rgb
);
 reg [9:0] x,y; reg prev_de,prev_vs;
 wire [9:0] px=prev_de?x:10'd0;
 wire frame_start=i_vs&&!prev_vs;
 reg event_pending,syllable_pending;
 reg signed [1:0] event_direction,dir;
 reg enabled;
 reg [15:0] frame_count;
 reg [8:0] breath_phase;
 reg [7:0] reaction_age;
 reg [8:0] blink_wait;
 reg [3:0] blink_phase;
 reg signed [9:0] gaze_x;reg signed[7:0]gaze_vx,gaze_y;reg signed[4:0]gaze_vy;
 reg signed[10:0]tilt;reg signed[7:0]tilt_v,hop;reg signed[4:0]hop_v;
 reg signed [15:0] shape,shape_v;
 // Targets belong to the frame now being committed, before spring integration.
 // Pixel geometry still uses the registered age/state of the rendered frame.
 wire [7:0] target_age=(page_event||event_pending) ? 8'd0 :
  (reaction_age==255 ? 8'd255 : reaction_age+1'b1);
 wire signed [1:0] target_direction=page_event ? page_direction : (event_pending ? event_direction : dir);
 wire [15:0] target_frame=frame_count+1'b1;
 reg signed[9:0]gx_target;reg signed[7:0]gy_target,hop_target;reg signed[10:0]tilt_target;reg signed[15:0]shape_target;
 reg signed[7:0]gx_acc;reg signed[4:0]gy_acc;reg signed[6:0]tilt_acc;reg signed[3:0]hop_acc;reg signed[15:0]shape_acc;
 reg signed [7:0] float_y;
 reg [3:0] eye_height,eye_width;
 function signed [7:0] sine32;
 input [4:0] phase;
 begin
 case(phase)
 0,16:sine32=0;1,15:sine32=1;2,3,13,14:sine32=2;
 4,5,11,12:sine32=3;6,7,8,9,10:sine32=4;
 17,31:sine32=-1;18,19,29,30:sine32=-2;
 20,21,27,28:sine32=-3;default:sine32=-4;
 endcase
 end
 endfunction
 always @* begin
  gx_target=-16'sd64;gy_target=-16'sd16;tilt_target=0;shape_target=0;hop_target=0;
  if(target_frame[8:7]==1)begin gx_target=0;gy_target=0;end
  if(target_frame[8:7]==2)begin gx_target=16'sd64;gy_target=-16'sd32;end
  if(target_age<6)begin gx_target=target_direction*16'sd144;gy_target=-16'sd16;shape_target=-16'sd32;end
  else if(target_age<25)begin gx_target=target_direction*16'sd144;gy_target=-16'sd16;
   tilt_target=target_direction*16'sd288;shape_target=-16'sd64;hop_target=-16'sd64;end
  else if(target_age<66)begin gx_target=-target_direction*16'sd80;gy_target=-16'sd48;
   tilt_target=-target_direction*16'sd112;shape_target=16'sd16;hop_target=-16'sd16;end
  else if(target_age<93)begin gx_target=-16'sd112;gy_target=-16'sd64;shape_target=16'sd32;end
  else if(target_age<114)begin gx_target=0;gy_target=0;end
  if(speaking && target_age>=114)begin gx_target=0;gy_target=-16'sd16;end
  gx_acc=((gx_target-gaze_x)>>>3)-(gaze_vx>>>1);
  gy_acc=((gy_target-gaze_y)>>>3)-(gaze_vy>>>1);
  tilt_acc=((tilt_target-tilt)>>>5)-(tilt_v>>>2);
  shape_acc=((shape_target-shape)>>>3)-(shape_v>>>2);
  hop_acc=((hop_target-hop)>>>4)-(hop_v>>>2);
  float_y=(sine32(frame_count[7:3])>>>1)+(sine32(frame_count[9:5]+5'd7)>>>2);
  eye_width=(reaction_age<25)?4'd8:4'd7;
  case(blink_phase)
   1:eye_height=5;2:eye_height=3;3,4,5:eye_height=1;
   6:eye_height=2;7:eye_height=3;8:eye_height=4;9:eye_height=5;
   10:eye_height=6;default:eye_height=speaking?4'd6:4'd7;
  endcase
 end
 always @(posedge clk)begin
  if(rst)begin
   x<=0;y<=0;prev_de<=0;prev_vs<=0;event_pending<=0;syllable_pending<=0;
   event_direction<=1;dir<=1;enabled<=0;frame_count<=0;breath_phase<=0;
   reaction_age<=255;blink_wait<=84;blink_phase<=0;
   gaze_x<=0;gaze_y<=0;gaze_vx<=0;gaze_vy<=0;
   tilt<=0;tilt_v<=0;shape<=0;shape_v<=0;hop<=0;hop_v<=0;
  end else begin
   prev_de<=i_de;prev_vs<=i_vs;
   if(i_de)x<=prev_de?x+1'b1:10'd1;else x<=0;
   if(frame_start)y<=0;else if(prev_de&&!i_de && y<1023)y<=y+1'b1;
   if(page_event)begin event_pending<=1;event_direction<=page_direction;end
   if(syllable)syllable_pending<=1;
   if(frame_start)begin
    enabled<=enable;frame_count<=frame_count+1'b1;
    breath_phase<=breath_phase==273?9'd0:breath_phase+1'b1;
    if(page_event||event_pending)begin
     event_pending<=0;reaction_age<=0;dir<=page_event?page_direction:event_direction;
    end else if(reaction_age!=255)reaction_age<=reaction_age+1'b1;
    gaze_vx<=gaze_vx+gx_acc;gaze_x<=gaze_x+gaze_vx+gx_acc;
    gaze_vy<=gaze_vy+gy_acc;gaze_y<=gaze_y+gaze_vy+gy_acc;
    tilt_v<=tilt_v+tilt_acc;tilt<=tilt+tilt_v+tilt_acc;
    shape_v<=shape_v+shape_acc;shape<=shape+shape_v+shape_acc;
    hop_v<=hop_v+hop_acc;hop<=hop+hop_v+hop_acc;
    if(syllable||syllable_pending)begin shape_v<=shape_v+16'sd8;syllable_pending<=0;end
    if(blink_phase!=0)begin
     blink_phase<=blink_phase==11?4'd0:blink_phase+1'b1;
     if(blink_phase==11)blink_wait<=9'd107+{2'b0,frame_count[6:0]};
    end else if(blink_wait==0)blink_phase<=1;
    else blink_wait<=blink_wait-1'b1;
   end
  end
 end
 // Coverage follows a circular baseline, compressed vertically only during
 // blink/smile. The far eye is a little narrower when turning.
 function [1:0] eye_coverage;
 input signed [10:0] dx,dy;
 input [3:0] rx,ry;
 reg [10:0] ax,ay;
 reg [4:0] row;
 reg [3:0] radius;
 begin
  ax=dx<0?-dx:dx;ay=dy<0?-dy:dy;row=15;radius=0;
  if(ay<ry)begin
   // ry is at most 7. Constant comparisons avoid divider/multiplier pixels.
   if(ay==0)row=0;
   else if(ay*7<ry*2)row=1;
   else if(ay*7<ry*3)row=2;
   else if(ay*7<ry*4)row=3;
   else if(ay*7<ry*5)row=4;
   else if(ay*7<ry*6)row=5;
   else row=6;
  end
  case(row)
   0,1:radius=rx;2:radius=rx-1'b1;3:radius=rx-1'b1;
   4:radius=rx-2;5:radius=rx-3;6:radius=rx-5;default:radius=0;
  endcase
  if(row==15||radius==0||ax>radius)eye_coverage=0;
  else if(ax==radius)eye_coverage=1;
  else if(ax+1==radius)eye_coverage=2;
  else eye_coverage=3;
 end
 endfunction
 // Subpixel ellipse coverage uses two vertical samples and quarter-pixel
 // analytic edge radii. Radius and color tables are distributed logic, not BRAM.
 // Source t0 centers41.4/62.6,52.06 and radius6.5 are retained inQ4.
 // BEGIN GENERATED EYE TABLES
 function [12:0] eye_unit;input[7:0] code;begin case(code)
   8'd32:eye_unit=13'd3966;
   8'd33:eye_unit=13'd2709;
   8'd64:eye_unit=13'd4082;
   8'd65:eye_unit=13'd3966;
   8'd66:eye_unit=13'd3724;
   8'd67:eye_unit=13'd3327;
   8'd68:eye_unit=13'd2709;
   8'd69:eye_unit=13'd1637;
   8'd96:eye_unit=13'd4091;
   8'd97:eye_unit=13'd4050;
   8'd98:eye_unit=13'd3966;
   8'd99:eye_unit=13'd3837;
   8'd100:eye_unit=13'd3658;
   8'd101:eye_unit=13'd3421;
   8'd102:eye_unit=13'd3113;
   8'd103:eye_unit=13'd2709;
   8'd104:eye_unit=13'd2158;
   8'd105:eye_unit=13'd1279;
   8'd128:eye_unit=13'd4093;
   8'd129:eye_unit=13'd4072;
   8'd130:eye_unit=13'd4030;
   8'd131:eye_unit=13'd3966;
   8'd132:eye_unit=13'd3879;
   8'd133:eye_unit=13'd3767;
   8'd134:eye_unit=13'd3628;
   8'd135:eye_unit=13'd3459;
   8'd136:eye_unit=13'd3255;
   8'd137:eye_unit=13'd3009;
   8'd138:eye_unit=13'd2709;
   8'd139:eye_unit=13'd2336;
   8'd140:eye_unit=13'd1845;
   8'd141:eye_unit=13'd1085;
   8'd160:eye_unit=13'd4094;
   8'd161:eye_unit=13'd4082;
   8'd162:eye_unit=13'd4056;
   8'd163:eye_unit=13'd4018;
   8'd164:eye_unit=13'd3966;
   8'd165:eye_unit=13'd3900;
   8'd166:eye_unit=13'd3820;
   8'd167:eye_unit=13'd3724;
   8'd168:eye_unit=13'd3611;
   8'd169:eye_unit=13'd3479;
   8'd170:eye_unit=13'd3327;
   8'd171:eye_unit=13'd3151;
   8'd172:eye_unit=13'd2947;
   8'd173:eye_unit=13'd2709;
   8'd174:eye_unit=13'd2427;
   8'd175:eye_unit=13'd2082;
   8'd176:eye_unit=13'd1637;
   8'd177:eye_unit=13'd959;
   8'd192:eye_unit=13'd4095;
   8'd193:eye_unit=13'd4086;
   8'd194:eye_unit=13'd4069;
   8'd195:eye_unit=13'd4044;
   8'd196:eye_unit=13'd4009;
   8'd197:eye_unit=13'd3966;
   8'd198:eye_unit=13'd3913;
   8'd199:eye_unit=13'd3851;
   8'd200:eye_unit=13'd3778;
   8'd201:eye_unit=13'd3694;
   8'd202:eye_unit=13'd3599;
   8'd203:eye_unit=13'd3492;
   8'd204:eye_unit=13'd3371;
   8'd205:eye_unit=13'd3234;
   8'd206:eye_unit=13'd3080;
   8'd207:eye_unit=13'd2907;
   8'd208:eye_unit=13'd2709;
   8'd209:eye_unit=13'd2482;
   8'd210:eye_unit=13'd2217;
   8'd211:eye_unit=13'd1896;
   8'd212:eye_unit=13'd1487;
   8'd213:eye_unit=13'd868;
   8'd224:eye_unit=13'd4095;
   8'd225:eye_unit=13'd4089;
   8'd226:eye_unit=13'd4077;
   8'd227:eye_unit=13'd4059;
   8'd228:eye_unit=13'd4034;
   8'd229:eye_unit=13'd4003;
   8'd230:eye_unit=13'd3966;
   8'd231:eye_unit=13'd3922;
   8'd232:eye_unit=13'd3871;
   8'd233:eye_unit=13'd3813;
   8'd234:eye_unit=13'd3747;
   8'd235:eye_unit=13'd3674;
   8'd236:eye_unit=13'd3592;
   8'd237:eye_unit=13'd3501;
   8'd238:eye_unit=13'd3400;
   8'd239:eye_unit=13'd3288;
   8'd240:eye_unit=13'd3166;
   8'd241:eye_unit=13'd3029;
   8'd242:eye_unit=13'd2878;
   8'd243:eye_unit=13'd2709;
   8'd244:eye_unit=13'd2519;
   8'd245:eye_unit=13'd2303;
   8'd246:eye_unit=13'd2053;
   8'd247:eye_unit=13'd1752;
   8'd248:eye_unit=13'd1371;
   8'd249:eye_unit=13'd799;
   default:eye_unit=0;endcase end endfunction
 function [6:0] eye_edge;input[12:0] code;
 reg[12:0] unit;reg[7:0] radius;reg[20:0] product;begin
  unit=eye_unit(code[7:0]);radius={code[12:9],4'b0}-8'd8;
  product=unit*radius+21'd2048;eye_edge=product[18:12];
 end endfunction
 // END GENERATED EYE TABLES
 function [4:0] eye_line_coverage;
 input [6:0] radius;input[7:0] ax;
 reg [8:0] left_edge,right_edge;
 begin
  left_edge={1'b0,ax}+9'd8;right_edge={2'b0,radius}+9'd8;
  if(radius==0)eye_line_coverage=0;
  else if(left_edge<=radius)eye_line_coverage=16;
  else if(ax>=right_edge)eye_line_coverage=0;
  else if(ax<8&&radius<8-ax)eye_line_coverage={radius,1'b0};
  else eye_line_coverage=right_edge-ax;
 end endfunction
 function [3:0] eye_coverage_q4;
 input signed [11:0] dx,dy;input[3:0] rx,ry;
 reg [11:0] ax,ay0,ay1;
 reg signed [11:0] y0,y1;
 reg [6:0] r0,r1;
 reg [5:0] sum;
 reg [9:0] scaled;
 begin
  ax=dx<0 ? -dx : dx;y0=dy-12'sd4;y1=dy+12'sd4;
  ay0=y0<0 ? -y0 : y0;ay1=y1<0 ? -y1 : y1;
  r0=0;r1=0;sum=0;scaled=0;eye_coverage_q4=0;
  if(ax<136&&ay0<128&&ay1<128)begin
   r0=eye_edge({rx,ry,ay0[6:2]});r1=eye_edge({rx,ry,ay1[6:2]});
   sum={1'b0,eye_line_coverage(r0,ax[7:0])}+{1'b0,eye_line_coverage(r1,ax[7:0])};
   scaled={sum,4'b0}-{4'b0,sum}+10'd16;
   eye_coverage_q4=scaled[8:5];
  end
 end endfunction
 reg [2:0] sync0,sync1,sync2,sync3;
 reg [23:0] bg0,bg1,bg2;
 reg signed [10:0] lx0,ly0,ux1,uy1;
 reg en0,en1;
 wire [15:0] body_rom_data;
 reg texvalid2;
 wire [15:0] tex2=texvalid2 ? body_rom_data : 16'd0;
 wire[3:0]eye2;
 reg[7:0]eye_ax2;reg eye_valid2;
 reg[11:0]eye_ax_calc,eye_ay0_calc,eye_ay1_calc;
 reg signed[11:0]eye_dy_calc,eye_y0_calc,eye_y1_calc;
 wire[1:0]eye_width_bank=selected_eye_width-4'd6;
 wire[9:0]eye_radius_address0={eye_width_bank,eye_height[2:0],eye_ay0_calc[6:2]};
 wire[9:0]eye_radius_address1={eye_width_bank,eye_height[2:0],eye_ay1_calc[6:2]};
 wire[6:0]eye_radius0,eye_radius1;
 html_eye_radius_rom eye_rom(clk,eye_radius_address0,eye_radius_address1,eye_radius0,eye_radius1);
 wire[5:0]eye_sum={1'b0,eye_line_coverage(eye_radius0,eye_ax2)}+{1'b0,eye_line_coverage(eye_radius1,eye_ax2)};
 wire[9:0]eye_scaled={eye_sum,4'b0}-{4'd0,eye_sum}+10'd16;
 assign eye2=eye_valid2 ? eye_scaled[8:5] : 4'd0;
 reg [3:0] alpha2;
 reg [7:0] red2,green2,blue2;
 reg [23:0] bot_background;
 function [12:0] blend_product;
 input [7:0] foreground,background;input [3:0] alpha;
 reg signed [8:0] delta;reg signed [13:0] value;
 begin
  delta=$signed({1'b0,foreground})-$signed({1'b0,background});
  value=delta*$signed({1'b0,alpha})+$signed({1'b0,background,4'b0})-$signed({5'b0,background});
  blend_product=value[12:0];
 end endfunction
 function [7:0] alpha15_result;
 input [12:0] product;
 reg [11:0] rounded;reg [7:0] folded;reg[4:0] remainder;reg[8:0] quotient;
 begin rounded=product[11:0]+12'd7;
  folded=rounded[11:4]+{4'd0,rounded[3:0]};
  remainder={1'b0,folded[7:4]}+{1'b0,folded[3:0]};
  quotient={1'b0,rounded[11:4]}+{5'd0,folded[7:4]}+(remainder>=15)+(remainder>=30);
  alpha15_result=quotient[7:0];
 end
 endfunction
 reg [12:0] red3,green3,blue3;
 reg [7:0] bg3r,bg3g,bg3b,fg3r,fg3g,fg3b;
 reg [3:0] alpha3;
 reg signed [21:0] tx_calc,ty_calc;
 reg signed [10:0] dx_calc,dy_calc;
 reg signed [7:0] shape_int,tilt_int,hop_int;
 reg [3:0] eye_coverage_calc,selected_eye_width;
 reg signed [11:0] eye_dx_q4;
 reg signed [11:0] eye_cx_q4,eye_cy_q4,sample_x_q4,sample_y_q4;
 reg [3:0] left_width,right_width;
 integer addr;
 html_rom16 #(.WORDS(10400),.ADDR_BITS(14),.INIT_FILE(BODY_FILE)) body_rom(
  .clk(clk),.address(addr[13:0]),.data(body_rom_data));
 always @*begin
  shape_int=(shape>>>4)+(breath_phase<104?($signed({1'b0,breath_phase})>>>5):((16'sd274-$signed({1'b0,breath_phase}))>>>6));
  tilt_int=tilt>>>4;hop_int=hop>>>4;
  dx_calc=lx0-11'sd52;dy_calc=ly0-11'sd56-float_y-hop_int;
  // Inverse affine mapping keeps eyes attached to the textured body.
  tx_calc=dx_calc-((dx_calc*shape_int)>>>6)+(((dy_calc-11'sd33)*tilt_int)>>>7)+11'sd52;
  ty_calc=dy_calc+((dy_calc*shape_int)>>>6)-((dx_calc*tilt_int)>>>7)+11'sd56;
  // Shadow is anchored to the floor, independently from body float/hop.
  if(ly0>=90)begin tx_calc=lx0;ty_calc=ly0;end
  eye_cx_q4=16'sd832+gaze_x;eye_cy_q4=16'sd833+gaze_y;
  sample_x_q4=$signed({ux1,4'b1000});sample_y_q4=$signed({uy1,4'b1000});
  left_width=eye_width-((gaze_x< -48)?1'b1:1'b0);
  right_width=eye_width-((gaze_x>48)?1'b1:1'b0);
  // The eye discs never overlap: select spatially before the shared AA unit.
  if(sample_x_q4<eye_cx_q4)begin eye_dx_q4=sample_x_q4-eye_cx_q4+16'sd170;selected_eye_width=left_width;end
  else begin eye_dx_q4=sample_x_q4-eye_cx_q4-16'sd170;selected_eye_width=right_width;end
  eye_coverage_calc=0;
  eye_dy_calc=sample_y_q4-eye_cy_q4;
  eye_y0_calc=eye_dy_calc-12'sd4;eye_y1_calc=eye_dy_calc+12'sd4;
  eye_ax_calc=eye_dx_q4<0 ? -eye_dx_q4 : eye_dx_q4;
  eye_ay0_calc=eye_y0_calc<0 ? -eye_y0_calc : eye_y0_calc;
  eye_ay1_calc=eye_y1_calc<0 ? -eye_y1_calc : eye_y1_calc;
  addr=uy1*104+ux1;
 end
 // Perceptual RGB444 codebook retains near-black gradient detail at16bits/texel.
 function [7:0] texture_channel;
 input [3:0] code;
 begin case(code)
 0:texture_channel=0;1:texture_channel=2;2:texture_channel=4;3:texture_channel=7;
 4:texture_channel=11;5:texture_channel=16;6:texture_channel=22;7:texture_channel=29;
 8:texture_channel=37;9:texture_channel=46;10:texture_channel=58;11:texture_channel=74;
 12:texture_channel=96;13:texture_channel=128;14:texture_channel=176;15:texture_channel=255;
 endcase end
 endfunction
 // Stage 2 texel and stage 2 eye coverage are resolved together before blending.
 always @*begin
  alpha2=tex2[15:12];red2=texture_channel(tex2[11:8]);
  green2=texture_channel(tex2[7:4]);blue2=texture_channel(tex2[3:0]);bot_background=bg2;
  if(eye2!=0)begin
   // Eye coverage includes its own soft edge over the opaque face.
   // Reuse the existing three pixel blend multipliers for eye-over-face.
   // Eye coverage is inside the opaque body, so its background is the texel.
   bot_background={red2,green2,blue2};alpha2=eye2;red2=244;green2=241;blue2=234;
  end
 end
 reg[3:0]pipe_valid;
 always @(posedge clk)begin

bg0<=i_rgb;en0<=enabled&&i_de;
   lx0<=$signed({1'b0,px})-11'sd520;ly0<=$signed({1'b0,y})-11'sd368;
bg1<=bg0;en1<=en0;
   ux1<=tx_calc[10:0];uy1<=ty_calc[10:0];
bg2<=bg1;
   texvalid2<=en1 && ux1>=0 && ux1<104 && uy1>=0 && uy1<100;
   eye_ax2<=eye_ax_calc[7:0];
   eye_valid2<=en1 && ux1>=0 && ux1<104 && uy1>=0 && uy1<100 &&
    eye_ax_calc<136 && eye_ay0_calc<128 && eye_ay1_calc<128 &&
    selected_eye_width>=6 && selected_eye_width<=8 && eye_height>=1 && eye_height<=7;
alpha3<=alpha2;fg3r<=red2;fg3g<=green2;fg3b<=blue2;bg3r<=bot_background[23:16];bg3g<=bot_background[15:8];bg3b<=bot_background[7:0];
   red3<=blend_product(red2,bot_background[23:16],alpha2);
   green3<=blend_product(green2,bot_background[15:8],alpha2);
   blue3<=blend_product(blue2,bot_background[7:0],alpha2);

   // Linear alpha4 is encoded0..15, so partial coverage also divides by15.


  if(rst)begin
   pipe_valid<=0;sync0<=0;sync1<=0;sync2<=0;sync3<=0;o_hs<=0;o_vs<=0;o_de<=0;o_rgb<=0;
  end else begin
   pipe_valid<={pipe_valid[2:0],1'b1};
   sync0<={i_hs,i_vs,i_de};
   sync1<=sync0;
   sync2<=sync1;
   sync3<=sync2;
   {o_hs,o_vs,o_de}<=sync3;
   if(!pipe_valid[3])o_rgb<=0;
   else o_rgb<={alpha15_result(red3),alpha15_result(green3),alpha15_result(blue3)};
  end
 end
endmodule
