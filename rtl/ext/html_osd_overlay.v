// Independent prototype OSD plate, proportional anti-aliased text and typewriter.
// Five registered pixel stages, including synchronous glyph ROM lookup.
// All config and text progress commit only on VS rising edges.
module html_osd_overlay #(
 parameter GLYPH_FILE="rtl/ext/html_assets/html_glyph_coverage.hex",
 parameter GLYPH_WORDS=9120
)(
 input wire clk,rst,i_hs,i_vs,i_de,
 input wire [23:0] i_rgb,
 input wire osd_enable,page_event,
 input wire [2:0] page_index,
 input wire dual_enable,zoom_enable,
 input wire [7:0] progress,
 input wire signed [8:0] brightness,
 input wire [2:0] contrast,mode,
 input wire [3:0] volume,
 input wire mute,paused,auto_mode,
 input wire [7:0] interval,
 input wire [15:0] audio_peak,
 input wire [3:0] audio_status,
 output reg speaking,syllable,
 output reg o_hs,o_vs,o_de,
 output reg [23:0] o_rgb
);
 reg [15:0] glyph_rom[0:GLYPH_WORDS-1];
 initial $readmemh(GLYPH_FILE,glyph_rom);
 reg [9:0] x,y;reg prev_de,prev_vs;
 wire [9:0] px=prev_de?x:10'd0;
 wire frame_start=i_vs&&!prev_vs;
 reg enabled,dual,zoom,muted,stopped,auto_flag;
 reg [2:0] page,ccontrast,cmode;
 reg signed [8:0] bright;
 reg [3:0] vol;
 reg [7:0] prog,seconds;
 reg event_pending;
 reg [6:0] typed_count;
 reg [5:0] typing_delay;
 reg [10:0] typing_phase;
 reg [6:0] cursor_frame;
 reg [4:0] audio_history[0:8];
 reg [3:0] pcm_status;integer ah;
 wire [7:0] glyph_id;
 wire [3:0] glyph_x;wire [4:0] glyph_y;
 wire [6:0] char_index,total_chars;
 wire is_caption,is_text,punctuation_pause;
 html_caption_map text_map(.page_index(page),.dual_enable(dual),.x(px),.y(y),
  .glyph_id(glyph_id),.glyph_x(glyph_x),.glyph_y(glyph_y),.char_index(char_index),
  .is_caption(is_caption),.is_text(is_text),.total_chars(total_chars),
  .typing_index(typed_count),.punctuation_pause(punctuation_pause));
 wire text_visible=enabled&&is_text&&(!is_caption||char_index<typed_count);
 always @(posedge clk)begin
  if(rst)begin
   x<=0;y<=0;prev_de<=0;prev_vs<=0;enabled<=0;dual<=0;zoom<=0;
   muted<=0;stopped<=0;auto_flag<=0;page<=0;ccontrast<=2;cmode<=0;
   bright<=0;vol<=8;prog<=0;seconds<=5;event_pending<=0;
   typed_count<=0;typing_delay<=6;typing_phase<=0;cursor_frame<=0;speaking<=0;syllable<=0;
   for(ah=0;ah<9;ah=ah+1)audio_history[ah]<=0;pcm_status<=0;
  end else begin
   prev_de<=i_de;prev_vs<=i_vs;syllable<=0;
   if(i_de)x<=prev_de?x+1'b1:10'd1;else x<=0;
   if(frame_start)y<=0;else if(prev_de&&!i_de&&y<1023)y<=y+1'b1;
   if(page_event)event_pending<=1;
   if(frame_start)begin
    enabled<=osd_enable;page<=page_index;dual<=dual_enable;zoom<=zoom_enable;
    bright<=brightness;ccontrast<=contrast;cmode<=mode;vol<=volume;
    muted<=mute;stopped<=paused;auto_flag<=auto_mode;prog<=progress;seconds<=interval;
    cursor_frame<=cursor_frame+1'b1;pcm_status<=audio_status;
    for(ah=8;ah>0;ah=ah-1)audio_history[ah]<=audio_history[ah-1];
    audio_history[0]<=(mute||paused)?5'd0:(audio_peak>=16'd32768?5'd29:audio_peak[14:10]);
    if(page_event||event_pending||page_index!=page||dual_enable!=dual)begin
     event_pending<=0;typed_count<=0;typing_delay<=(page_event||event_pending||page_index!=page)?6'd33:6'd6;
     typing_phase<=0;speaking<=0;
    end else if(typing_delay!=0)begin typing_delay<=typing_delay-1'b1;speaking<=0;end
    else if(typed_count<total_chars)begin
     speaking<=1;
     // 19 characters/second / 59.5238095frames/second =399/1250.
     if(typing_phase+11'd399>=1250)begin
      typed_count<=typed_count+1'b1;typing_phase<=typing_phase+11'd399-11'd1250;
      syllable<=1;
      if(punctuation_pause)typing_delay<=13; // .2184 sec punctuation breath
      if(typed_count+1'b1>=total_chars)speaking<=0;
     end else typing_phase<=typing_phase+11'd399;
    end else speaking<=0;
   end
  end
 end
 function [23:0] page_accent;
 input [2:0] p;
 begin case(p)
  1:page_accent=24'hd1a85e;2:page_accent=24'he0603f;
  3:page_accent=24'h7fc3a2;4:page_accent=24'ha9a2e6;
  5:page_accent=24'hc9c3b6;default:page_accent=24'hd8d4cc;
 endcase end
 endfunction
 // Live values use a small legible 5x7 font; Chinese caption uses source glyphs.
 function [34:0] digit;
 input [7:0] c;
 begin case(c)
  "0":digit=35'b01110100011001110101110011000101110;
  "1":digit=35'b00100011000010000100001000010001110;
  "2":digit=35'b01110100010000100010001000100011111;
  "3":digit=35'b11110000010000101110000010000111110;
  "4":digit=35'b00010001100101010010111110001000010;
  "5":digit=35'b11111100001000011110000010000111110;
  "6":digit=35'b01110100001000011110100011000101110;
  "7":digit=35'b11111000010001000100010000100001000;
  "8":digit=35'b01110100011000101110100011000101110;
  "9":digit=35'b01110100011000101111000010000101110;
  "B":digit=35'b11110100011000111110100011000111110;
  "C":digit=35'b01111100001000010000100001000001111;
  "V":digit=35'b10001100011000110001100010101000100;
  "T":digit=35'b11111001000010000100001000010000100;
  "Z":digit=35'b11111000010001000100010001000011111;
  "P":digit=35'b11110100011000111110100001000010000;
  "A":digit=35'b01110100011000111111100011000110001;
  "M":digit=35'b10001110111010110101100011000110001;
  ":":digit=35'b00000001000010000000001000010000000;
  "+":digit=35'b00000001000010011111001000010000000;
  "-":digit=35'b00000000000000011111000000000000000;
  ".":digit=35'b00000000000000000000000000010000100;
  default:digit=0;
 endcase end
 endfunction
 function [7:0] live_char;
 input [5:0] n;
 reg [8:0] mag;
 reg [31:0] ratio;
 begin
  mag=bright[8]?-bright:bright;live_char=" ";
  case(ccontrast)
   0:ratio="0.50";1:ratio="0.75";3:ratio="1.25";4:ratio="1.50";
   5:ratio="1.75";6:ratio="2.00";default:ratio="1.00";
  endcase
  case(n)
   0:live_char="B";1:live_char=":";2:live_char=bright[8]?"-":"+";
   3:live_char="0"+mag/100;4:live_char="0"+(mag/10)%10;5:live_char="0"+mag%10;
   7:live_char="C";8:live_char=":";9:live_char=ratio[31:24];10:live_char=ratio[23:16];11:live_char=ratio[15:8];12:live_char=ratio[7:0];
   14:live_char="V";15:live_char=":";16:live_char="0"+vol/10;17:live_char="0"+vol%10;
   19:live_char="T";20:live_char=":";21:live_char="0"+seconds/100;
   22:live_char="0"+(seconds/10)%10;23:live_char="0"+seconds%10;
   25:live_char="Z";26:live_char=":";27:live_char=zoom?"2":"1";
   29:live_char=auto_flag?"A":"M";31:live_char=stopped?"P":" ";33:live_char=muted?"M":" ";
  endcase
 end
 endfunction
 reg [23:0] plate_rgb,text_rgb;
 reg [3:0] plate_alpha;
 reg [34:0] live_bits;
 reg live_ink;
 integer tick,tx,ty,live_x,live_y;
 reg [3:0] bar_index;reg [2:0] bar_col;reg [4:0] bar_height;reg [9:0] bar_top,bar_bottom;
 reg [15:0] live_word;
 always @*begin
  plate_rgb=0;plate_alpha=0;text_rgb=24'h1a1916;
  tick=0;tx=0;ty=0;live_x=0;live_y=0;live_bits=0;live_ink=0;live_word=0;bar_index=0;bar_col=0;bar_height=0;bar_top=0;bar_bottom=0;
  if(enabled&&i_de)begin
   // Rounded paper plate and directional tail.
   if(px>=24&&px<510&&y>=386&&y<458)begin
    tx=px-24;ty=y-386;
    if(!((tx<2||tx>=484)&&(ty<2||ty>=70)))begin
     plate_rgb=(tx<3)?page_accent(page):24'hede9e2;plate_alpha=15;
    end
   end
   if(px>=510&&px<516&&y>=416&&y<429)begin
    ty=y>422?y-422:422-y;
    if(ty<516-px)begin plate_rgb=24'hede9e2;plate_alpha=15;end
   end
   // Soft floor shadow under the card stays alpha blended.
   if(px>=30&&px<506&&y>=458&&y<466)begin plate_rgb=0;plate_alpha=(466-y)>>1;end
   // Audio panel divider; waveform itself remains real-audio driven elsewhere.
   if(px==443&&y>=386&&y<458)begin plate_rgb=24'hd7d3cc;plate_alpha=15;end
   // Nine temporal PCM-peak samples, not frequency bins or simulated bars.
   if(px>=455&&px<500&&y>=399&&y<429)begin
    bar_index=(px-455)/5;bar_col=(px-455)%5;
    bar_height=audio_history[bar_index];
    if(bar_height>29)bar_height=29;
    bar_top=414-(bar_height>>1);bar_bottom=414+((bar_height+1'b1)>>1);
    if(bar_col<3&&bar_height!=0&&y>=bar_top&&y<bar_bottom&&
       (bar_col==1||(y>bar_top&&y+1<bar_bottom)))begin
     plate_rgb=24'h1a1916;plate_alpha=15;
    end
   end
   // Native six-page ticks, selected tick fills from the actual page progress.
   if(y>=42&&y<44&&px>=504&&px<608)begin
    tick=(px-504)/18;tx=(px-504)%18;
    if(tick<6&&tx<14)begin
     plate_rgb=24'hede9e2;plate_alpha=tick==page?5:3;
     if(tick==page&&tx*255<prog*14)begin plate_rgb=page_accent(page);plate_alpha=15;end
    end
   end
   // Live adjustment strip appears while a parameter mode is selected.
   if(cmode!=0&&px>=24&&px<238&&y>=467&&y<478)begin
    plate_rgb=24'h141311;plate_alpha=13;
    live_x=px-28;live_y=y-469;
    if(live_x>=0&&live_x<204&&live_y>=0&&live_y<7)begin
     live_bits=digit(live_char(live_x/6));
     if(live_x%6<5)live_ink=live_bits[34-live_y*5-live_x%6];
     if(live_ink)begin plate_rgb=24'hede9e2;plate_alpha=15;end
    end
   end
  end
  // Blinking dot after the visible prefix, independent of glyph opacity.
  if(enabled&&i_de&&typed_count<total_chars&&is_caption&&char_index==typed_count&&
     glyph_x>=1&&glyph_x<5&&glyph_y>=11&&glyph_y<15&&!cursor_frame[5]&&
     !((glyph_x==1||glyph_x==4)&&(glyph_y==11||glyph_y==14)))begin
   plate_rgb=24'h1a1916;plate_alpha=15;
  end
  if(y<62)text_rgb=24'hede9e2;
  else if(y<411&&px>=72)text_rgb=24'h77736b;
 end
 reg [2:0] sync0,sync1,sync2,sync3;
 reg [23:0] bg0,bg1,bg2,plate0,plate1,plate2,text0,text1,text2;
 reg [3:0] pa0,pa1,pa2;
 reg [13:0] glyph_addr0;
 reg [2:0] glyph_col0,glyph_col1;
 reg text_en0,text_en1;
 reg [15:0] glyph_word1;
 reg [1:0] coverage2;
 reg [23:0] fg_calc,bg_calc;
 reg [3:0] alpha_calc;
 function [12:0] blend_product;
 input [7:0] foreground,background;input [3:0] alpha;
 reg signed [8:0] delta;reg signed [13:0] value;
 begin
  delta=$signed({1'b0,foreground})-$signed({1'b0,background});
  value=delta*$signed({1'b0,alpha})+$signed({1'b0,background,4'b0});
  blend_product=value[12:0];
 end endfunction
 reg [12:0] r3,g3,b3;
 reg [23:0] fg3,bg3;
 reg [3:0] alpha3;
 always @*begin
  fg_calc=plate2;bg_calc=bg2;alpha_calc=pa2;
  // Text lives above the paper. Since its plate is opaque, 2-bit text coverage
  // is blended directly into paper before the stream's final alpha operation.
  if(coverage2!=0)begin
   alpha_calc=15;
   case(coverage2)
    1:begin
     fg_calc[23:16]=({2'b0,text2[23:16]}+{2'b0,plate2[23:16]}*3)>>2;
     fg_calc[15:8]=({2'b0,text2[15:8]}+{2'b0,plate2[15:8]}*3)>>2;
     fg_calc[7:0]=({2'b0,text2[7:0]}+{2'b0,plate2[7:0]}*3)>>2;
    end
    2:begin
     fg_calc[23:16]=({2'b0,text2[23:16]}*3+{2'b0,plate2[23:16]})>>2;
     fg_calc[15:8]=({2'b0,text2[15:8]}*3+{2'b0,plate2[15:8]})>>2;
     fg_calc[7:0]=({2'b0,text2[7:0]}*3+{2'b0,plate2[7:0]})>>2;
    end
    default:fg_calc=text2;
   endcase
   // Header glyphs outside plate blend against actual image, not black.
   if(pa2==0)begin alpha_calc=coverage2==3?4'd15:{coverage2,2'b00};fg_calc=text2;end
  end
 end
 always @(posedge clk)begin
  if(rst)begin
   sync0<=0;sync1<=0;sync2<=0;sync3<=0;bg0<=0;bg1<=0;bg2<=0;
   plate0<=0;plate1<=0;plate2<=0;text0<=0;text1<=0;text2<=0;
   pa0<=0;pa1<=0;pa2<=0;glyph_addr0<=0;glyph_col0<=0;glyph_col1<=0;
   text_en0<=0;text_en1<=0;glyph_word1<=0;coverage2<=0;
   r3<=0;g3<=0;b3<=0;fg3<=0;bg3<=0;alpha3<=0;
   o_hs<=0;o_vs<=0;o_de<=0;o_rgb<=0;
  end else begin
   sync0<={i_hs,i_vs,i_de};bg0<=i_rgb;plate0<=plate_rgb;pa0<=plate_alpha;text0<=text_rgb;
   glyph_addr0<=glyph_id*14'd40+glyph_y*14'd2+glyph_x[3];
   glyph_col0<=glyph_x[2:0];text_en0<=text_visible&&i_de&&glyph_y<20;
   sync1<=sync0;bg1<=bg0;plate1<=plate0;pa1<=pa0;text1<=text0;
   glyph_word1<=glyph_rom[glyph_addr0];glyph_col1<=glyph_col0;text_en1<=text_en0;
   sync2<=sync1;bg2<=bg1;plate2<=plate1;pa2<=pa1;text2<=text1;
   coverage2<=text_en1?((glyph_word1>>(14-glyph_col1*2))&16'h3):2'd0;
   sync3<=sync2;fg3<=fg_calc;bg3<=bg_calc;alpha3<=alpha_calc;
   r3<=blend_product(fg_calc[23:16],bg_calc[23:16],alpha_calc);
   g3<=blend_product(fg_calc[15:8],bg_calc[15:8],alpha_calc);
   b3<=blend_product(fg_calc[7:0],bg_calc[7:0],alpha_calc);
   {o_hs,o_vs,o_de}<=sync3;
   if(alpha3==15)o_rgb<=fg3;
   else if(alpha3==0)o_rgb<=bg3;
   else o_rgb<={r3[11:4],g3[11:4],b3[11:4]};
  end
 end
endmodule
