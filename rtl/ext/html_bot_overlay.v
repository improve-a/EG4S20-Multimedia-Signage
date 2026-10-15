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
 reg [15:0] body [0:10399];
 initial $readmemh(BODY_FILE,body);
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
 reg signed [15:0] gaze_x,gaze_y,gaze_vx,gaze_vy;
 reg signed [15:0] tilt,tilt_v,shape,shape_v,hop,hop_v;
 reg signed [15:0] gx_target,gy_target,tilt_target,shape_target,hop_target;
 reg signed [15:0] gx_acc,gy_acc,tilt_acc,shape_acc,hop_acc;
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
  if(frame_count[8:7]==1)begin gx_target=0;gy_target=0;end
  if(frame_count[8:7]==2)begin gx_target=16'sd64;gy_target=-16'sd32;end
  if(reaction_age<6)begin gx_target=dir*16'sd144;gy_target=-16'sd16;shape_target=-16'sd32;end
  else if(reaction_age<25)begin gx_target=dir*16'sd144;gy_target=-16'sd16;
   tilt_target=dir*16'sd288;shape_target=-16'sd64;hop_target=-16'sd64;end
  else if(reaction_age<66)begin gx_target=-dir*16'sd80;gy_target=-16'sd48;
   tilt_target=-dir*16'sd112;shape_target=16'sd16;hop_target=-16'sd16;end
  else if(reaction_age<92)begin gx_target=-16'sd112;gy_target=-16'sd64;shape_target=16'sd32;end
  else if(reaction_age<114)begin gx_target=0;gy_target=0;end
  if(speaking && reaction_age>=114)begin gx_target=0;gy_target=-16'sd16;end
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
 reg [2:0] sync0,sync1,sync2,sync3;
 reg [23:0] bg0,bg1,bg2;
 reg signed [10:0] lx0,ly0,ux1,uy1;
 reg en0,en1;
 reg [15:0] tex2;
 reg [1:0] eye2;
 reg [3:0] alpha2;
 reg [7:0] red2,green2,blue2;
 function [12:0] blend_product;
 input [7:0] foreground,background;input [3:0] alpha;
 reg signed [8:0] delta;reg signed [13:0] value;
 begin
  delta=$signed({1'b0,foreground})-$signed({1'b0,background});
  value=delta*$signed({1'b0,alpha})+$signed({1'b0,background,4'b0});
  blend_product=value[12:0];
 end endfunction
 reg [12:0] red3,green3,blue3;
 reg [7:0] bg3r,bg3g,bg3b,fg3r,fg3g,fg3b;
 reg [3:0] alpha3;
 reg signed [21:0] tx_calc,ty_calc;
 reg signed [10:0] dx_calc,dy_calc;
 reg signed [7:0] shape_int,tilt_int,hop_int;
 reg [1:0] eye_left,eye_right;
 reg signed [10:0] eye_cx,eye_cy;
 reg [3:0] left_width,right_width;
 integer addr;
 always @*begin
  shape_int=(shape>>>4)+(breath_phase<104?($signed({1'b0,breath_phase})>>>5):((16'sd274-$signed({1'b0,breath_phase}))>>>6));
  tilt_int=tilt>>>4;hop_int=hop>>>4;
  dx_calc=lx0-11'sd52;dy_calc=ly0-11'sd56-float_y-hop_int;
  // Inverse affine mapping keeps eyes attached to the textured body.
  tx_calc=dx_calc-((dx_calc*shape_int)>>>6)+(((dy_calc-11'sd33)*tilt_int)>>>7)+11'sd52;
  ty_calc=dy_calc+((dy_calc*shape_int)>>>6)-((dx_calc*tilt_int)>>>7)+11'sd56;
  // Shadow is anchored to the floor, independently from body float/hop.
  if(ly0>=90)begin tx_calc=lx0;ty_calc=ly0;end
  eye_cx=11'sd52+(gaze_x>>>4);eye_cy=11'sd51+(gaze_y>>>4);
  left_width=eye_width-((gaze_x< -48)?1'b1:1'b0);
  right_width=eye_width-((gaze_x>48)?1'b1:1'b0);
  eye_left=eye_coverage(ux1-eye_cx+11'sd10,uy1-eye_cy,left_width,eye_height);
  eye_right=eye_coverage(ux1-eye_cx-11'sd10,uy1-eye_cy,right_width,eye_height);
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
  green2=texture_channel(tex2[7:4]);blue2=texture_channel(tex2[3:0]);
  if(eye2!=0)begin
   // Eye coverage includes its own soft edge over the opaque face.
   alpha2=15;
   case(eye2)
    1:begin red2=red2-red2/4+8'd61;green2=green2-green2/4+8'd60;blue2=blue2-blue2/4+8'd58;end
    2:begin red2=red2/4+8'd183;green2=green2/4+8'd180;blue2=blue2/4+8'd175;end
    default:begin red2=244;green2=241;blue2=234;end
   endcase
  end
 end
 always @(posedge clk)begin
  if(rst)begin
   sync0<=0;sync1<=0;sync2<=0;sync3<=0;bg0<=0;bg1<=0;bg2<=0;
   lx0<=0;ly0<=0;ux1<=0;uy1<=0;en0<=0;en1<=0;tex2<=0;eye2<=0;
   red3<=0;green3<=0;blue3<=0;alpha3<=0;bg3r<=0;bg3g<=0;bg3b<=0;fg3r<=0;fg3g<=0;fg3b<=0;
   o_hs<=0;o_vs<=0;o_de<=0;o_rgb<=0;
  end else begin
   sync0<={i_hs,i_vs,i_de};bg0<=i_rgb;en0<=enabled&&i_de;
   lx0<=$signed({1'b0,px})-11'sd520;ly0<=$signed({1'b0,y})-11'sd368;
   sync1<=sync0;bg1<=bg0;en1<=en0;
   ux1<=tx_calc[10:0];uy1<=ty_calc[10:0];
   sync2<=sync1;bg2<=bg1;
   if(en1 && ux1>=0 && ux1<104 && uy1>=0 && uy1<100)begin
    tex2<=body[addr];eye2<=eye_left>eye_right?eye_left:eye_right;
   end else begin tex2<=0;eye2<=0;end
   sync3<=sync2;alpha3<=alpha2;fg3r<=red2;fg3g<=green2;fg3b<=blue2;bg3r<=bg2[23:16];bg3g<=bg2[15:8];bg3b<=bg2[7:0];
   red3<=blend_product(red2,bg2[23:16],alpha2);
   green3<=blend_product(green2,bg2[15:8],alpha2);
   blue3<=blend_product(blue2,bg2[7:0],alpha2);
   {o_hs,o_vs,o_de}<=sync3;
   // alpha15 is exactly opaque (the multiply uses denominator16 for all else).
   if(alpha3==15)o_rgb<={fg3r,fg3g,fg3b};
   else if(alpha3==0)o_rgb<={bg3r,bg3g,bg3b};
   else o_rgb<={red3[11:4],green3[11:4],blue3[11:4]};
  end
 end
endmodule
