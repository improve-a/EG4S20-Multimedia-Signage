// Two-stage pixel pipeline and synchronous history RAM read. Actual post-mute
// HDMI PCM24 samples, decimated by 64: 256 stereo points span ~0.341 seconds.
module audio_visualizer(
 input clk,rst,i_hs,i_vs,i_de,input [23:0] i_rgb,
 input sample_valid,input [23:0] sample_left,sample_right,
 input [15:0] peak,input [3:0] audio_status,input enable,
 output reg o_hs,o_vs,o_de,output reg [23:0] o_rgb
);
reg [13:0] history[0:255]; /* fehdl force_ram=1, ram_style="bram" */
reg [7:0] write_pointer;
reg [8:0] history_count;
reg [5:0] decimate;
reg [9:0] x,y;
reg prev_de,prev_vs;
wire [9:0] px=prev_de?x:10'd0;
wire in_wave=i_de&&px>=16&&px<528&&y>=320&&y<416;
wire [7:0] point=(px-10'd16)>>1;
wire [8:0] blank_points=9'd256-history_count;
wire history_valid=(history_count==256)||({1'b0,point}>=blank_points);
wire [7:0] read_address=(history_count==256)?write_pointer+point:point-blank_points[7:0];
reg [13:0] read_data;
reg s_h,s_v,s_d,s_enable,s_wave,s_history_valid;
reg [9:0] s_x,s_y;
reg [23:0] s_rgb;
reg [15:0] s_peak;
reg [3:0] s_status;
wire signed [6:0] left_point=$signed(read_data[13:7]);
wire signed [6:0] right_point=$signed(read_data[6:0]);
wire signed [10:0] left_y=11'sd368-left_point;
wire signed [10:0] right_y=11'sd368-right_point;
wire [9:0] peak_width=s_peak>=32768?10'd512:{1'b0,s_peak[14:6]};
function [7:0] hexchar;
 input [3:0] n;
 begin hexchar=n<10?8'd48+n:8'd65+n-10;end
endfunction
function [7:0] status_char;
 input [2:0] n;input [3:0] code;
 begin
  if(code==4'hb)case(n)0:status_char="T";1:status_char="O";2:status_char="N";3:status_char="E";default:status_char=" ";endcase
  else case(n)0:status_char="W";1:status_char=":";2:status_char=hexchar(code);default:status_char=" ";endcase
 end
endfunction
function [34:0] glyph;
 input [7:0] ch;
 begin case(ch)
 "W":glyph=35'b10001100011000110101101011010101010;
 "T":glyph=35'b11111001000010000100001000010000100;
 "O":glyph=35'b01110100011000110001100011000101110;
 "N":glyph=35'b10001110011010110011100011000110001;
 "E":glyph=35'b11111100001000011110100001000011111;
 ":":glyph=35'b00000001000010000000001000010000000;
 "0":glyph=35'b01110100011001110101110011000101110;
 "1":glyph=35'b00100011000010000100001000010001110;
 "2":glyph=35'b01110100010000100010001000100011111;
 "3":glyph=35'b11110000010000101110000010000111110;
 "4":glyph=35'b00010001100101010010111110001000010;
 "5":glyph=35'b11111100001000011110000010000111110;
 "6":glyph=35'b01110100001000011110100011000101110;
 "7":glyph=35'b11111000010001000100010001000010000;
 "8":glyph=35'b01110100011000101110100011000101110;
 "9":glyph=35'b01110100011000101111000010000101110;
 "A":glyph=35'b01110100011000111111100011000110001;
 "B":glyph=35'b11110100011000111110100011000111110;
 "C":glyph=35'b01111100001000010000100001000001111;
 "D":glyph=35'b11110100011000110001100011000111110;
 "F":glyph=35'b11111100001000011110100001000010000;
 default:glyph=0;
 endcase end
endfunction
reg [23:0] composed;
reg [34:0] text_bits;
reg [9:0] text_x,text_y;
reg [2:0] char_index,col,row;
always @*begin
 composed=s_rgb;text_bits=0;text_x=0;text_y=0;char_index=0;col=0;row=0;
 if(s_enable&&s_d)begin
  if(s_wave)begin
   composed=24'h0a0e14;
   if(s_y==320||s_y==415||s_x==16||s_x==527)composed=24'h405060;
   else if(s_y==368)composed=24'h263340;
   if(s_history_valid)begin
    if($signed({1'b0,s_y})==left_y)composed=24'h00ff80;
    if($signed({1'b0,s_y})==right_y)composed=24'h40a0ff;
    if($signed({1'b0,s_y})==left_y&&$signed({1'b0,s_y})==right_y)composed=24'hffffff;
   end
  end else if(s_x>=16&&s_x<528&&s_y>=428&&s_y<440)
   composed=((s_x-16)<peak_width)?24'hffaa30:24'h0a0e14;
  else if(s_x>=16&&s_x<80&&s_y>=304&&s_y<318)begin
   composed=24'h0a0e14;text_x=s_x-16;text_y=s_y-304;
   char_index=text_x/12;col=(text_x%12)>>1;row=text_y>>1;
   text_bits=glyph(status_char(char_index,s_status));
   if(col<5&&row<7&&text_bits[34-row*5-col])composed=24'hffffff;
  end
 end
end
always @(posedge clk)begin
 if(rst)begin write_pointer<=0;history_count<=0;decimate<=0;end
 else if(sample_valid)begin
  decimate<=decimate+1'b1;
  if(decimate==63)begin
   history[write_pointer]<={{sample_left[23],sample_left[23:18]},{sample_right[23],sample_right[23:18]}};
   write_pointer<=write_pointer+1'b1;
   if(history_count<256)history_count<=history_count+1'b1;
  end
 end
end
// The history array is not reset. Valid history count prevents unwritten reads.
always @(posedge clk)begin
 if(in_wave&&history_valid&&!rst)read_data<=history[read_address];
 // Hold an unreset RAM output when not reading; s_history_valid masks it.
end
always @(posedge clk)begin
 if(rst)begin
  x<=0;y<=0;prev_de<=0;prev_vs<=0;
  s_h<=0;s_v<=0;s_d<=0;s_enable<=0;s_wave<=0;s_history_valid<=0;
  s_x<=0;s_y<=0;s_rgb<=0;s_peak<=0;s_status<=0;
  o_hs<=0;o_vs<=0;o_de<=0;o_rgb<=0;
 end else begin
  prev_de<=i_de;prev_vs<=i_vs;
  if(i_vs&&!prev_vs)y<=0;
  else if(prev_de&&!i_de&&y<1023)y<=y+1'b1;
  if(i_de)x<=prev_de?x+1'b1:10'd1;else x<=0;
  s_h<=i_hs;s_v<=i_vs;s_d<=i_de;s_rgb<=i_rgb;s_enable<=enable;
  s_wave<=in_wave;s_history_valid<=history_valid;s_x<=px;s_y<=y;s_peak<=peak;s_status<=audio_status;
  o_hs<=s_h;o_vs<=s_v;o_de<=s_d;o_rgb<=composed;
 end
end
endmodule
