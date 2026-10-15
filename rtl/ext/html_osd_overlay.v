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
 input wire [1:0] scale_mode,
 input wire [2:0] focus,
 input wire [7:0] progress,
 input wire signed [8:0] brightness,
 input wire [2:0] contrast,mode,
 input wire [3:0] volume,
 input wire mute,paused,auto_mode,
 input wire [7:0] interval,
 input wire [3:0] interval_fraction,
 input wire [15:0] audio_peak,
 input wire [3:0] audio_status,
 output reg speaking,syllable,
 output reg o_hs,o_vs,o_de,
 output reg [23:0] o_rgb
);
 reg [9:0] x,y;reg prev_de,prev_vs;
 wire [9:0] px=prev_de?x:10'd0;
 wire frame_start=i_vs&&!prev_vs;
 reg enabled,dual,zoom,muted,stopped,auto_flag;
 reg [2:0] page,ccontrast,cmode;
 reg [1:0] zoom_mode;
 reg [2:0] focus_l;
 reg [23:0] mini_bounds;
 reg [1:0] resolved_scale;
 reg signed [8:0] bright;
 reg [3:0] vol;
 reg [7:0] prog,seconds;
 reg [3:0] seconds_fraction;
 reg event_pending;
 reg [5:0] swap_age;
 reg [146:0] swap_values;
 wire [2:0] swap_y=swap_values[146:144];
 wire [9:0] card_y=y-{7'd0,swap_y};
 // BEGIN GENERATED SWAP
 localparam [146:0] SWAP_STEADY=147'h0a7a49e605e5a1a1916c6c2ba9e9a9377736b;
 function [2:0] swap_offset;input[5:0] a;begin case(a)
   6'd0:swap_offset=3'd6;
   6'd1:swap_offset=3'd5;
   6'd2:swap_offset=3'd4;
   6'd3:swap_offset=3'd3;
   6'd4:swap_offset=3'd2;
   6'd5:swap_offset=3'd2;
   6'd6:swap_offset=3'd1;
   6'd7:swap_offset=3'd1;
   6'd8:swap_offset=3'd1;
   6'd9:swap_offset=3'd1;
   6'd10:swap_offset=3'd1;
   6'd11:swap_offset=3'd0;
   6'd12:swap_offset=3'd0;
   6'd13:swap_offset=3'd0;
   6'd14:swap_offset=3'd0;
   6'd15:swap_offset=3'd0;
   6'd16:swap_offset=3'd0;
   6'd17:swap_offset=3'd0;
   6'd18:swap_offset=3'd0;
   6'd19:swap_offset=3'd0;
   6'd20:swap_offset=3'd0;
   6'd21:swap_offset=3'd0;
   6'd22:swap_offset=3'd0;
   6'd23:swap_offset=3'd0;
   6'd24:swap_offset=3'd0;
   6'd25:swap_offset=3'd0;
   6'd26:swap_offset=3'd0;
   6'd27:swap_offset=3'd0;
   6'd28:swap_offset=3'd0;
   6'd29:swap_offset=3'd0;
   6'd30:swap_offset=3'd0;
   6'd31:swap_offset=3'd0;
   default:swap_offset=0;
  endcase end endfunction
 // END GENERATED SWAP
 reg [6:0] typed_count;
 reg [5:0] typing_delay;
 reg [10:0] typing_phase;
 reg [6:0] cursor_frame;
 reg [4:0] audio_history[0:8];
 reg [3:0] pcm_status;integer ah;
 // Serial18-byte prefill shares one9K ROM instead of144 parallel lookup bits.
 // It finishes19 pixel clocks after VS, well before active video33 lines later.
 wire swap_restart=page_event||event_pending||page_index!=page||dual_enable!=dual;
 reg [9:0] palette_base;
 reg [4:0] palette_issue;
 reg palette_loading,palette_valid0,swap_palette_ready;
 wire [9:0] palette_address=palette_loading ? palette_base+{5'd0,palette_issue} : 10'd0;
 wire [7:0] palette_byte;
 html_osd_swap_rom swap_rom(.clk(clk),.address(palette_address),.data(palette_byte));
 always @(posedge clk)begin
  if(rst)begin
   swap_age<=31;swap_values<=SWAP_STEADY;palette_base<=0;palette_issue<=0;
   palette_loading<=0;palette_valid0<=0;swap_palette_ready<=1;
  end else if(frame_start&&(swap_restart||swap_age<31))begin
   swap_age<=swap_restart ? 6'd0 : swap_age+1'b1;
   swap_values[146:144]<=swap_offset(swap_restart ? 6'd0 : swap_age+1'b1);
   palette_base<=swap_restart ? 10'd0 : (swap_age+6'd1)*10'd18;
   palette_issue<=0;palette_loading<=1;palette_valid0<=0;swap_palette_ready<=0;
  end else begin
   palette_valid0<=palette_loading;
   if(palette_loading)begin
    if(palette_issue==17)palette_loading<=0;
    else palette_issue<=palette_issue+1'b1;
   end
   if(palette_valid0)begin
    swap_values[143:0]<={swap_values[135:0],palette_byte};
    if(!palette_loading)swap_palette_ready<=1;
   end
  end
 end
 wire [7:0] glyph_id;
 wire [3:0] glyph_x;wire [4:0] glyph_y;
 wire [6:0] char_index,total_chars;
 wire is_caption,is_text,punctuation_pause;
 html_caption_map text_map(.page_index(page),.dual_enable(dual),.x(10'd0),.y(10'd0),
  .glyph_id(glyph_id),.glyph_x(glyph_x),.glyph_y(glyph_y),.char_index(char_index),
  .is_caption(is_caption),.is_text(is_text),.total_chars(total_chars),
  .typing_index(typed_count),.punctuation_pause(punctuation_pause));
 // Constant-coordinate metadata instance retains only totals and punctuation.
 reg [12:0] body_base,header_base,index_base;
 wire [2:0] next_page=page_index<6 ? page_index : 3'd0;
 function [23:0] viewport_origin;
 input home;input[2:0] f;input[1:0] z;
 begin case({home,(f>5?3'd0:f),(z>2?2'd2:z)})
  6'd0:viewport_origin=24'h000000;
  6'd1:viewport_origin=24'h480350;
  6'd2:viewport_origin=24'h5545d4;
  6'd4:viewport_origin=24'h000000;
  6'd5:viewport_origin=24'h280780;
  6'd6:viewport_origin=24'h354a04;
  6'd8:viewport_origin=24'h000000;
  6'd9:viewport_origin=24'h000780;
  6'd10:viewport_origin=24'h0d4a04;
  6'd12:viewport_origin=24'h000000;
  6'd13:viewport_origin=24'h500780;
  6'd14:viewport_origin=24'h5d4a04;
  6'd16:viewport_origin=24'h000000;
  6'd17:viewport_origin=24'h280000;
  6'd18:viewport_origin=24'h354284;
  6'd20:viewport_origin=24'h000000;
  6'd21:viewport_origin=24'h280f00;
  6'd22:viewport_origin=24'h355184;
  6'd32:viewport_origin=24'h000000;
  6'd33:viewport_origin=24'h44c480;
  6'd34:viewport_origin=24'h520704;
  6'd36:viewport_origin=24'h000000;
  6'd37:viewport_origin=24'h280780;
  6'd38:viewport_origin=24'h354a04;
  6'd40:viewport_origin=24'h000000;
  6'd41:viewport_origin=24'h000780;
  6'd42:viewport_origin=24'h0d4a04;
  6'd44:viewport_origin=24'h000000;
  6'd45:viewport_origin=24'h500780;
  6'd46:viewport_origin=24'h5d4a04;
  6'd48:viewport_origin=24'h000000;
  6'd49:viewport_origin=24'h280000;
  6'd50:viewport_origin=24'h354284;
  6'd52:viewport_origin=24'h000000;
  6'd53:viewport_origin=24'h280f00;
  6'd54:viewport_origin=24'h355184;
 default:viewport_origin=0;
 endcase end endfunction
 // Content box is50x37 inside the source52x39 one-pixel border.
 // Bounds are quantized to the nearest output pixel for width/height and floor
 // for position; source origin/remainder matches the actual viewport mapper.
 function [23:0] mini_geometry;
 input [2:0] p,f;input [1:0] z;
 begin
  if(z==0)mini_geometry=24'h000ca5;
  else case({p==0,(f>5 ? 3'd0 : f),(z>2 ? 2'd2 : z)})
   6'd1:mini_geometry=24'h584653;
   6'd2:mini_geometry=24'h68744c;
   6'd5:mini_geometry=24'h309653;
   6'd6:mini_geometry=24'h40c44c;
   6'd9:mini_geometry=24'h009653;
   6'd10:mini_geometry=24'h10c44c;
   6'd13:mini_geometry=24'h649653;
   6'd14:mini_geometry=24'h74c44c;
   6'd17:mini_geometry=24'h300653;
   6'd18:mini_geometry=24'h40344c;
   6'd21:mini_geometry=24'h312653;
   6'd22:mini_geometry=24'h41544c;
   6'd33:mini_geometry=24'h545653;
   6'd34:mini_geometry=24'h64844c;
   6'd37:mini_geometry=24'h309653;
   6'd38:mini_geometry=24'h40c44c;
   6'd41:mini_geometry=24'h009653;
   6'd42:mini_geometry=24'h10c44c;
   6'd45:mini_geometry=24'h649653;
   6'd46:mini_geometry=24'h74c44c;
   6'd49:mini_geometry=24'h300653;
   6'd50:mini_geometry=24'h40344c;
   6'd53:mini_geometry=24'h312653;
   6'd54:mini_geometry=24'h41544c;
   default:mini_geometry=24'h000ca5;
  endcase
 end endfunction
 always @*begin
  case(scale_mode)
   2'd0:resolved_scale=0;2'd1:resolved_scale=1;2'd2,2'd3:resolved_scale=2;
   default:resolved_scale=zoom_enable ? 2'd1 : 2'd0;
  endcase
 end
 always @(posedge clk)begin
  if(rst)begin
   x<=0;y<=0;prev_de<=0;prev_vs<=0;enabled<=0;dual<=0;zoom<=0;
   muted<=0;stopped<=0;auto_flag<=0;page<=0;ccontrast<=2;cmode<=0;
   bright<=0;vol<=8;prog<=0;seconds<=5;seconds_fraction<=0;event_pending<=0;zoom_mode<=0;focus_l<=0;mini_bounds<=0;
   body_base<=0;header_base<=13'd6720;index_base<=13'd7616;typed_count<=0;typing_delay<=6;typing_phase<=0;cursor_frame<=0;speaking<=0;syllable<=0;
   for(ah=0;ah<9;ah=ah+1)audio_history[ah]<=0;pcm_status<=0;
  end else begin
   prev_de<=i_de;prev_vs<=i_vs;syllable<=0;
   if(i_de)x<=prev_de?x+1'b1:10'd1;else x<=0;
   if(frame_start)y<=0;else if(prev_de&&!i_de&&y<1023)y<=y+1'b1;
   if(page_event)event_pending<=1;
   if(frame_start)begin
    enabled<=osd_enable;page<=next_page;dual<=dual_enable;
    body_base<=(dual_enable ? 13'd3360 : 13'd0)+next_page*13'd560;
    header_base<=13'd6720+(dual_enable ? 13'd768 : {next_page,7'b0});
    index_base<=13'd7616+next_page*13'd80;zoom<=resolved_scale!=0;zoom_mode<=resolved_scale;focus_l<=focus;
    mini_bounds<=mini_geometry(page_index,focus,resolved_scale);
    bright<=brightness;ccontrast<=contrast;cmode<=mode;vol<=volume;
    muted<=mute;stopped<=paused;auto_flag<=auto_mode;prog<=progress;seconds<=interval;seconds_fraction<=interval_fraction<10 ? interval_fraction : 4'd0;
    cursor_frame<=cursor_frame+1'b1;pcm_status<=audio_status;
    for(ah=8;ah>0;ah=ah-1)audio_history[ah]<=audio_history[ah-1];
    audio_history[0]<=(mute||paused)?5'd0:(audio_peak>=16'd32768 ?5'd29:audio_peak[14:10]);
    if(page_event||event_pending||page_index!=page||dual_enable!=dual)begin
     event_pending<=0;typed_count<=0;typing_delay<=(page_event||event_pending||page_index!=page)?6'd33:6'd6;
     typing_phase<=0;speaking<=0;
    end else begin
     if(typing_delay!=0)begin typing_delay<=typing_delay-1'b1;speaking<=0;end
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
  "s":digit=35'b01111100001000001110000010000111110;
  "X":digit=35'b00000100010101000100010101000100000;
  ".":digit=35'b00000000000000000000000000010000100;
  default:digit=0;
 endcase end
 endfunction
 function [7:0] live_char;
 input [5:0] n;
 reg [8:0] mag;
 reg [31:0] ratio;
 reg [5:0] position;
 begin
  mag=bright[8]?-bright:bright;live_char=" ";
  position=(seconds_fraction!=0&&n>=28) ? n-6'd3 : n;
  case(ccontrast)
   0:ratio="0.50";1:ratio="0.75";3:ratio="1.25";4:ratio="1.50";
   5:ratio="1.75";6:ratio="2.00";default:ratio="1.00";
  endcase
  case(position)
   0:live_char="B";1:live_char=":";2:live_char=bright[8]?"-":"+";
   3:live_char="0"+mag/100;4:live_char="0"+(mag/10)%10;5:live_char="0"+mag%10;
   7:live_char="C";8:live_char=":";9:live_char=ratio[31:24];10:live_char=ratio[23:16];11:live_char=ratio[15:8];12:live_char=ratio[7:0];
   14:live_char="V";15:live_char=":";16:live_char="0"+vol/10;17:live_char="0"+vol%10;
   19:live_char="T";20:live_char=":";21:live_char=seconds_fraction!=0&&seconds<100 ? " " : "0"+seconds/100;
   22:live_char=seconds_fraction!=0&&seconds<10 ? " " : "0"+(seconds/10)%10;23:live_char="0"+seconds%10;
   25:live_char="Z";26:live_char=":";27:live_char=zoom_mode==0 ? "1" : zoom_mode==1 ? "2" : "3";
   29:live_char=auto_flag?"A":"M";31:live_char=stopped?"P":" ";33:live_char=muted?"M":" ";
  endcase
  if(seconds_fraction!=0)begin
   case(n)
    24:live_char=".";25:live_char="0"+seconds_fraction;26:live_char="s";27:live_char=" ";
    default:begin end
   endcase
  end
 end
 endfunction
 reg [23:0] plate_rgb,text_rgb;
 reg [3:0] plate_alpha;
 reg [34:0] live_bits;
 reg live_ink;
 reg [2:0] tick;
 reg [9:0] tx,ty;
 reg [7:0] live_x;
 reg [3:0] live_y;
 reg [4:0] tick_col;
 reg [5:0] bar_x,font_bit;
 reg [2:0] live_col;
 reg [9:0] mini_x0,mini_y0,mini_x1,mini_y1;
 reg [7:0] zoom_char;
 reg [3:0] bar_index;reg [2:0] bar_col;reg [4:0] bar_height;reg [9:0] bar_top,bar_bottom;
 reg [15:0] live_word;
 always @*begin
  plate_rgb=0;plate_alpha=0;text_rgb=24'h1a1916;
  tick=0;tx=0;ty=0;live_x=0;live_y=0;live_bits=0;live_ink=0;live_word=0;bar_index=0;bar_col=0;bar_height=0;bar_top=0;bar_bottom=0;mini_x0=0;mini_y0=0;mini_x1=0;mini_y1=0;zoom_char=" ";tick_col=0;bar_x=0;font_bit=0;live_col=0;
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
    bar_x=px-10'd455;bar_index=bar_x/6'd5;bar_col=bar_x%6'd5;
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
    tx=px-10'd504;tick=tx/10'd18;tick_col=tx%10'd18;
    if(tick<6&&tick_col<14)begin
     plate_rgb=24'hede9e2;plate_alpha=tick==page?5:3;
     if(tick==page&&{tick_col,8'b0}-tick_col<prog*12'd14)begin plate_rgb=page_accent(page);plate_alpha=15;end
    end
   end
   // Source zoom badge: outer mini x521.64,y62,w52,h39; label x581.64.
   // Integer raster usesx522 andx582. OSD remains fixed while A layer zooms.
   if(zoom&&px>=522&&px<574&&y>=62&&y<101)begin
    if(px==522||px==573||y==62||y==100)begin plate_rgb=24'hede9e2;plate_alpha=6;end
    mini_x0=523+mini_bounds[23:18];mini_y0=63+mini_bounds[17:12];
    mini_x1=mini_x0+mini_bounds[11:6];mini_y1=mini_y0+mini_bounds[5:0];
    if(px>=mini_x0&&px<mini_x1&&y>=mini_y0&&y<mini_y1)begin
     plate_rgb=24'hede9e2;
     plate_alpha=(px==mini_x0||px+1==mini_x1||y==mini_y0||y+1==mini_y1) ? 15 : 2;
    end
   end
   if(zoom&&px>=582&&px<606&&y>=76&&y<83)begin
    live_x=px-582;live_y=y-76;
    case(live_x/8'd6)
     0:zoom_char=zoom_mode==1 ? "2" : "3";1:zoom_char=".";2:zoom_char="0";default:zoom_char="X";
    endcase
    live_bits=digit(zoom_char);
    live_col=live_x%8'd6;font_bit=6'd34-live_y*6'd5-live_col;
    if(live_col<5&&live_bits[font_bit])begin plate_rgb=24'hede9e2;plate_alpha=15;end
   end
   // Live adjustment strip appears while a parameter mode is selected.
   if(cmode!=0&&px>=24&&px<(seconds_fraction!=0 ? 10'd256 : 10'd238)&&y>=467&&y<478)begin
    plate_rgb=24'h141311;plate_alpha=13;
    live_x=px-10'd28;live_y=y-10'd469;
    if(px>=28&&px<(seconds_fraction!=0 ? 10'd250 : 10'd232)&&y>=469&&y<476)begin
     live_bits=digit(live_char(live_x/8'd6));
     live_col=live_x%8'd6;font_bit=6'd34-live_y*6'd5-live_col;
     if(live_col<5)live_ink=live_bits[font_bit];
     if(live_ink)begin plate_rgb=24'hede9e2;plate_alpha=15;end
    end
   end
  end
  if(y<62)text_rgb=24'hede9e2;
  else if(y<411&&px>=72)text_rgb=24'h77736b;
 end
 // A synchronous column descriptor replaces parallel comparisons of758 runs.
 // Metadata, glyph read and alpha arithmetic retain five registered stages.
 reg [12:0] column_address;
 reg column_valid,column_caption,column_card;
 reg [4:0] column_row;
 reg [1:0] column_style;
 always @*begin
  column_address=13'd0;column_valid=0;column_caption=0;column_card=0;column_row=0;
  column_style=y<62 ? 2'd2 : ((y<411&&px>=72) ? 2'd1 : 2'd0);
  if(px>=42&&px<170&&card_y>=397&&card_y<417)begin
   column_address=header_base+px-10'd42;column_valid=1;column_card=1;column_row=card_y-10'd397;
  end else if(px>=42&&px<434&&card_y>=416&&card_y<435)begin
   column_address=body_base+px-10'd42;column_valid=1;column_caption=1;column_card=1;column_row=card_y-10'd416;
  end else if(px>=42&&px<210&&card_y>=435&&card_y<455)begin
   column_address=body_base+13'd392+px-10'd42;column_valid=1;column_caption=1;column_card=1;column_row=card_y-10'd435;
  end else if(px>=528&&px<608&&y>=22&&y<43)begin
   column_address=index_base+px-10'd528;column_valid=1;column_row=y-(px>=584 ? 10'd23 : 10'd22);
  end else if(px>=468&&px<486&&y>=433&&y<453)begin
   column_address=13'd8096+px-10'd468;column_valid=1;column_row=y-10'd433;
  end
  if(column_card)column_style=card_y<411&&px>=72 ? 2'd1 : 2'd0;
 end
 wire [17:0] column_word0;
 html_caption_column_rom column_rom(.clk(clk),.address(column_address),.data(column_word0));
 reg [2:0] sync0,sync1,sync2,sync3;
 reg [23:0] bg0,bg1,bg2,plate0,plate1,plate2;
 reg [3:0] pa0,pa1,pa2;
 reg column_valid0,caption0,card0,card1,card2;
 reg [4:0] row0;
 reg [3:0] px_low0;
 reg [1:0] style0,style1,style2;
 wire [3:0] local_x0=px_low0-column_word0[9:6];
 wire descriptor_valid0=column_valid0&&column_word0[17:10]!=8'd255;
 wire cursor_ink0=enabled&&descriptor_valid0&&caption0&&typed_count<total_chars&&
  {1'b0,column_word0[5:0]}==typed_count&&local_x0>=1&&local_x0<5&&
  row0>=11&&row0<15&&!cursor_frame[5]&&
  !((local_x0==1||local_x0==4)&&(row0==11||row0==14));
 reg [13:0] glyph_addr1;
 reg [2:0] glyph_col1,glyph_col2;
 reg text_en1,text_en2;
 wire [15:0] glyph_word2;
 html_rom16 #(.WORDS(GLYPH_WORDS),.ADDR_BITS(14),.INIT_FILE(GLYPH_FILE)) glyph_rom(
  .clk(clk),.address(glyph_addr1),.data(glyph_word2));
 wire [1:0] coverage2=text_en2 ? ((glyph_word2>>(4'd14-{glyph_col2,1'b0}))&16'h3) : 2'd0;
 reg [23:0] fg_calc,bg_calc,text_color;
 reg [3:0] alpha_calc;
 function [7:0] third_blend;
 input [7:0] fg,bg;input two;
 reg [9:0] sum;
 begin
  sum=two ? {1'b0,fg,1'b0}+{2'b0,bg}+10'd1 : {2'b0,fg}+{1'b0,bg,1'b0}+10'd1;
  third_blend=sum/10'd3;
 end endfunction
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
  text_color=style2==2 ? 24'hede9e2 : style2==1 ? 24'h77736b : 24'h1a1916;
  // Atlas codes represent exactly0,1/3,2/3,1 coverage.
  if(coverage2!=0)begin
   alpha_calc=15;
   if(card2)begin
    if(style2==1)begin
     case(coverage2)
      1:fg_calc=swap_values[71:48];2:fg_calc=swap_values[47:24];default:fg_calc=swap_values[23:0];
     endcase
    end else begin
     case(coverage2)
      1:fg_calc=swap_values[143:120];2:fg_calc=swap_values[119:96];default:fg_calc=swap_values[95:72];
     endcase
    end
   end else if(coverage2==3)fg_calc=text_color;
   else if(pa2==15)begin
    if(style2==1)fg_calc=coverage2==1 ? 24'hc6c2ba : 24'h9e9a93;
    else fg_calc=coverage2==1 ? 24'ha7a49e : 24'h605e5a;
   end else begin
    fg_calc[23:16]=third_blend(text_color[23:16],bg2[23:16],coverage2==2);
    fg_calc[15:8]=third_blend(text_color[15:8],bg2[15:8],coverage2==2);
    fg_calc[7:0]=third_blend(text_color[7:0],bg2[7:0],coverage2==2);
   end
  end
 end
 always @(posedge clk)begin
  if(rst)begin
   sync0<=0;sync1<=0;sync2<=0;sync3<=0;bg0<=0;bg1<=0;bg2<=0;
   plate0<=0;plate1<=0;plate2<=0;pa0<=0;pa1<=0;pa2<=0;
   column_valid0<=0;caption0<=0;card0<=0;card1<=0;card2<=0;row0<=0;px_low0<=0;style0<=0;style1<=0;style2<=0;
   glyph_addr1<=0;glyph_col1<=0;glyph_col2<=0;text_en1<=0;text_en2<=0;
   r3<=0;g3<=0;b3<=0;fg3<=0;bg3<=0;alpha3<=0;
   o_hs<=0;o_vs<=0;o_de<=0;o_rgb<=0;
  end else begin
   sync0<={i_hs,i_vs,i_de};bg0<=i_rgb;plate0<=plate_rgb;pa0<=plate_alpha;
   column_valid0<=column_valid&&enabled&&i_de;caption0<=column_caption;card0<=column_card;row0<=column_row;px_low0<=px[3:0];style0<=column_style;
   sync1<=sync0;bg1<=bg0;plate1<=cursor_ink0 ? swap_values[95:72] : plate0;pa1<=cursor_ink0 ? 4'd15 : pa0;style1<=style0;card1<=card0;
   glyph_addr1<=column_word0[17:10]*14'd40+{row0,1'b0}+local_x0[3];
   glyph_col1<=local_x0[2:0];
   text_en1<=descriptor_valid0&&row0<20&&(!caption0||{1'b0,column_word0[5:0]}<typed_count);
   sync2<=sync1;bg2<=bg1;plate2<=plate1;pa2<=pa1;style2<=style1;card2<=card1;
   glyph_col2<=glyph_col1;text_en2<=text_en1;
   sync3<=sync2;fg3<=fg_calc;bg3<=bg_calc;alpha3<=alpha_calc;
   r3<=blend_product(fg_calc[23:16],bg_calc[23:16],alpha_calc);
   g3<=blend_product(fg_calc[15:8],bg_calc[15:8],alpha_calc);
   b3<=blend_product(fg_calc[7:0],bg_calc[7:0],alpha_calc);
   {o_hs,o_vs,o_de}<=sync3;
   if(alpha3==15)o_rgb<=fg3;
   else o_rgb<={r3[11:4],g3[11:4],b3[11:4]};
  end
 end
endmodule
