// Active pixels are counted from DE, lines from DE falling edges, and frames
// from VS rising edges. Configure once per frame. One registered output cycle.
// Layers, highest first: title, status, ticker, bottom progress, source RGB.
module osd_overlay (
 input wire clk, rst, i_hs, i_vs, i_de,
 input wire [23:0] i_rgb,
 input wire osd_enable,
 input wire [2:0] mode,
 input wire signed [8:0] brightness,
 input wire [2:0] contrast,
 input wire [7:0] interval,
 input wire [1:0] transition_mode, scale_mode,
 input wire [3:0] volume,
 input wire paused, auto_mode, mute,
 input wire [3:0] state,
 input wire [7:0] progress,
 input wire [9:0] title_x,title_y,status_x,status_y,ticker_y,
 input wire [23:0] fg_rgb,accent_rgb,
 output reg o_hs,o_vs,o_de,
 output reg [23:0] o_rgb
);
 reg [9:0] x,y;
 reg prev_de,prev_vs;
 reg [7:0] scroll;
 wire [9:0] px = prev_de ? x : 10'd0;
 function [34:0] glyph;
 input [7:0] ch;
 begin
 case(ch)
 8'd65: glyph=35'b01110100011000111111100011000110001;
 8'd66: glyph=35'b11110100011000111110100011000111110;
 8'd67: glyph=35'b01111100001000010000100001000001111;
 8'd68: glyph=35'b11110100011000110001100011000111110;
 8'd69: glyph=35'b11111100001000011110100001000011111;
 8'd70: glyph=35'b11111100001000011110100001000010000;
 8'd71: glyph=35'b01111100001000010111100011000101111;
 8'd72: glyph=35'b10001100011000111111100011000110001;
 8'd73: glyph=35'b11111001000010000100001000010011111;
 8'd76: glyph=35'b10000100001000010000100001000011111;
 8'd77: glyph=35'b10001110111010110101100011000110001;
 8'd78: glyph=35'b10001110011010110011100011000110001;
 8'd79: glyph=35'b01110100011000110001100011000101110;
 8'd80: glyph=35'b11110100011000111110100001000010000;
 8'd82: glyph=35'b11110100011000111110101001001010001;
 8'd83: glyph=35'b01111100001000001110000010000111110;
 8'd84: glyph=35'b11111001000010000100001000010000100;
 8'd85: glyph=35'b10001100011000110001100011000101110;
 8'd86: glyph=35'b10001100011000110001100010101000100;
 8'd88: glyph=35'b10001100010101000100010101000110001;
 8'd89: glyph=35'b10001100010101000100001000010000100;
 8'd90: glyph=35'b11111000010001000100010001000011111;
 8'd48: glyph=35'b01110100011001110101110011000101110;
 8'd49: glyph=35'b00100011000010000100001000010001110;
 8'd50: glyph=35'b01110100010000100010001000100011111;
 8'd51: glyph=35'b11110000010000101110000010000111110;
 8'd52: glyph=35'b00010001100101010010111110001000010;
 8'd53: glyph=35'b11111100001000011110000010000111110;
 8'd54: glyph=35'b01110100001000011110100011000101110;
 8'd55: glyph=35'b11111000010001000100010000100001000;
 8'd56: glyph=35'b01110100011000101110100011000101110;
 8'd57: glyph=35'b01110100011000101111000010000101110;
 8'd58: glyph=35'b00000001000010000000001000010000000;
 8'd46: glyph=35'b00000000000000000000000000010000100;
 8'd43: glyph=35'b00000001000010011111001000010000000;
 8'd45: glyph=35'b00000000000000011111000000000000000;
 default: glyph=35'd0;
 endcase
 end
 endfunction
 function ink;
 input [7:0] ch;
 input integer col,row;
 reg [34:0] bits;
 begin
 bits=glyph(ch);
 if(col>=0 && col<5 && row>=0 && row<7) ink=bits[34-row*5-col];
 else ink=0;
 end
 endfunction
 function [7:0] title_char;
 input integer n;
 reg [95:0] text_value;
 begin text_value="HX4S20 MEDIA"; title_char=text_value[95-n*8 -:8]; end
 endfunction
 function [7:0] ticker_char;
 input integer n;
 reg [255:0] text_value;
 begin text_value={"TF CARD HDMI AUDIO VIDEO",64'h2020202020202020}; ticker_char=text_value[255-n*8 -:8]; end
 endfunction
 function [7:0] status_char;
 input integer n;
 reg [8:0] magnitude;
 reg [31:0] mode_text,contrast_text;
 begin
 magnitude=brightness[8] ? (~brightness + 9'd1) : brightness;
 case(mode)
 0:mode_text="PLAY"; 1:mode_text="BRIT"; 2:mode_text="CONT";
 3:mode_text="TIME";4:mode_text="OSD ";5:mode_text="TRAN";
 6:mode_text="ZOOM";7:mode_text="VOL ";
 endcase
 case(contrast)
 0:contrast_text="0.50";1:contrast_text="0.75";3:contrast_text="1.25";
 4:contrast_text="1.50";5:contrast_text="1.75";6:contrast_text="2.00";
 default:contrast_text="1.00";
 endcase
 status_char=" ";
 if(n<4) status_char=mode_text[31-n*8 -:8];
 else if(n>=14 && n<18) status_char=contrast_text[31-(n-14)*8 -:8];
 else case(n)
 5:status_char="B";6:status_char=":";
 7:status_char=brightness<0?"-":"+";
 8:status_char=48+magnitude/100;
 9:status_char=48+(magnitude/10)%10;
 10:status_char=48+magnitude%10;
 12:status_char="C";13:status_char=":";
 19:status_char="I";20:status_char=":";
 21:status_char=48+interval/100;
 22:status_char=48+(interval/10)%10;
 23:status_char=48+interval%10;
 25:status_char=paused?"P":"R";
 27:status_char=auto_mode?"A":"M";
 29:status_char=mute?"M":"U";
 31:status_char="S";32:status_char=":";
 33:status_char=state<10?48+state:65+state-10;
 35:status_char="T";36:status_char=":";37:status_char=48+transition_mode;
 39:status_char="Z";40:status_char=":";41:status_char=48+scale_mode;
 43:status_char="V";44:status_char=":";
 45:status_char=48+volume/10;46:status_char=48+volume%10;
 endcase
 end
 endfunction
 integer dx,dy,ticker_pos;
 reg [23:0] composed;
 always @* begin
 composed=i_rgb;
 dx=0;dy=0;ticker_pos=0;
 if(osd_enable && i_de) begin
  // Progress fills exactly 0..256 pixels, 255 means complete.
  if(y>=10'd468 && y<10'd472 && px>=10'd16 && px<10'd272) begin
   if(progress==255 || px-16 < progress) composed=accent_rgb;
   else composed=24'h202020;
  end
  if(y>=ticker_y && {1'b0,y}<{1'b0,ticker_y}+11'd9 && px<640) begin
   ticker_pos=(px+scroll)&255;
   if(ink(ticker_char(ticker_pos/8),ticker_pos%8,y-ticker_y)) composed=accent_rgb;
   else composed=24'h101820;
  end
  if(px>=status_x && {1'b0,px}<{1'b0,status_x}+11'd376 &&
     y>=status_y && {1'b0,y}<{1'b0,status_y}+11'd9) begin
   dx=px-status_x;dy=y-status_y;
   if(ink(status_char(dx/8),dx%8,dy)) composed=fg_rgb;
   else composed=24'h101820;
  end
  if(px>=title_x && {1'b0,px}<{1'b0,title_x}+11'd192 &&
     y>=title_y && {1'b0,y}<{1'b0,title_y}+11'd16) begin
   dx=(px-title_x)/2;dy=(y-title_y)/2;
   if(ink(title_char(dx/8),dx%8,dy)) composed=fg_rgb;
   else composed=24'h101820;
  end
 end
 end
 always @(posedge clk) begin
 if(rst) begin
  x<=0;y<=0;prev_de<=0;prev_vs<=0;scroll<=0;
  o_hs<=0;o_vs<=0;o_de<=0;o_rgb<=0;
 end else begin
  prev_de<=i_de;prev_vs<=i_vs;
  if(i_vs && !prev_vs) begin y<=0;scroll<=scroll+1'b1;end
  else if(prev_de && !i_de && y<1023) y<=y+1'b1;
  if(i_de) x<=prev_de ? x+1'b1 : 10'd1;
  else x<=0;
  o_hs<=i_hs;o_vs<=i_vs;o_de<=i_de;o_rgb<=composed;
 end
 end
endmodule
