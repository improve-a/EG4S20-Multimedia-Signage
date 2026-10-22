`timescale 1ns/1ps
// Real debounced keys -> production config packing -> six-clock RGB pipeline.
// Only scan y is accelerated; state, ROM and outputs are never forced.
module probe_osd_default_1x_tb;
 reg clk=0; always #5 clk=~clk;
 reg rst=1,kn=1,ka=1,kp=1,hs=0,vs=0,de=0;
 wire [2:0] mode,focus; wire signed [8:0] bright;
 wire [2:0] contrast; wire [7:0] seconds; wire [3:0] fraction,volume;
 wire osd,dual,muted,paused,auto_flag; wire [1:0] scale,transition;
 wire [15:0] milliseconds;
 media_controls #(.CLK_FREQ_HZ(1000),.DEBOUNCE_MS(2),.LONG_PRESS_MS(24),.ENABLE_EXHIBIT(1)) controls(
  .clk(clk),.rst(rst),.key_next(kn),.key_auto(ka),.key_pause_mute(kp),
  .next_pulse(),.prev_pulse(),.content_mode(dual),.content_mode_changed(),
  .auto_mode(auto_flag),.paused(paused),.muted(muted),.mode_changed(),.mode(mode),
  .brightness(bright),.contrast(contrast),.interval_seconds(seconds),.interval_fraction(fraction),
  .osd_enable(osd),.transition_mode(transition),.scale_mode(scale),.volume(volume),
  .interval_milliseconds(milliseconds),.zoom_focus(focus),.param_changed());
 wire [50:0] config_data={fraction,4'd0,muted,paused,auto_flag,8'd0,volume,scale,transition,osd,seconds,contrast,bright,mode};
 wire oh,ov,od;wire [23:0] rgb;
 html_video_overlay dut(.clk(clk),.rst(rst),.i_hs(hs),.i_vs(vs),.i_de(de),.i_rgb(24'h808080),
  .config_data(config_data),.page_event(1'b0),.page_index(3'd0),.dual_enable(dual),
  .page_reverse(1'b0),.focus(focus),.audio_peak(16'd0),.audio_status(4'd0),
  .o_hs(oh),.o_vs(ov),.o_de(od),.o_rgb(rgb));
 // Independent glyph oracle, not the RTL digit helper.
 function [34:0] glyph;
 input [7:0] c;
 begin case(c)
  "0":glyph=35'b01110100011001110101110011000101110;
  "1":glyph=35'b00100011000010000100001000010001110;
  "2":glyph=35'b01110100010000100010001000100011111;
  "3":glyph=35'b11110000010000101110000010000111110;
  "4":glyph=35'b00010001100101010010111110001000010;
  "5":glyph=35'b11111100001000011110000010000111110;
  "6":glyph=35'b01110100001000011110100011000101110;
  "7":glyph=35'b11111000010001000100010000100001000;
  "8":glyph=35'b01110100011000101110100011000101110;
  "9":glyph=35'b01110100011000101111000010000101110;
  "B":glyph=35'b11110100011000111110100011000111110;
  "C":glyph=35'b01111100001000010000100001000001111;
  "V":glyph=35'b10001100011000110001100010101000100;
  "T":glyph=35'b11111001000010000100001000010000100;
  "Z":glyph=35'b11111000010001000100010001000011111;
  "P":glyph=35'b11110100011000111110100001000010000;
  "A":glyph=35'b01110100011000111111100011000110001;
  "M":glyph=35'b10001110111010110101100011000110001;
  ":":glyph=35'b00000001000010000000001000010000000;
  "+":glyph=35'b00000001000010011111001000010000000;
  "-":glyph=35'b00000000000000011111000000000000000;
  "s":glyph=35'b01111100001000001110000010000111110;
  "X":glyph=35'b00000100010101000100010101000100000;
  ".":glyph=35'b00000000000000000000000000010000100;
  "R":glyph=35'b11110100011000111110101001001010001;
  "I":glyph=35'b11111001000010000100001000010011111;
  "G":glyph=35'b01110100011000010111100011000101110;
  "H":glyph=35'b10001100011000111111100011000110001;
  "O":glyph=35'b01110100011000110001100011000101110;
  "N":glyph=35'b10001110011010110011100011000110001;
  "L":glyph=35'b10000100001000010000100001000011111;
  "S":glyph=35'b01111100001000001110000010000111110;
  "Y":glyph=35'b10001100010101000100001000010000100;
  "D":glyph=35'b11110100011000110001100011000111110;
  default:glyph=0;
 endcase end endfunction
 reg [135:0] expected="P0 PLAY          ";
 function [7:0] character; input integer n; begin character=expected[(16-n)*8+:8];end endfunction
 function [23:0] pixel;
 input integer x,y;integer bg,col,row,n;reg[34:0]bits;reg[7:0] pr,pg,pb;
 begin
  // Neutral gray input is unaffected by contrast.
  bg=128+$signed(bright);if(bg<0)bg=0;if(bg>255)bg=255;
  pixel={bg[7:0],bg[7:0],bg[7:0]};
  if(x>=24&&x<(mode==0?76:136)&&y>=467&&y<478)begin
   pr=(20*13+bg*3)>>4;pg=(19*13+bg*3)>>4;pb=(17*13+bg*3)>>4;pixel={pr,pg,pb};
   if(x>=28&&x<(mode==0?70:130)&&y>=469&&y<476)begin
    n=(x-28)/6;col=(x-28)%6;row=y-469;bits=glyph(character(n));
    if(col<5&&bits[34-row*5-col])pixel=24'hede9e2;
   end
  end
 end endfunction
 integer xx=0,yy=0,checks=0,pixels=0,ink=0,plate_count=0;
 integer xq[0:5],yq[0:5],j;
 reg[2:0]sq[0:5];reg cq[0:5];reg checking=0;reg[23:0] want;
 always @(posedge clk)begin
  if(rst)begin for(j=0;j<6;j=j+1)begin sq[j]=0;cq[j]=0;xq[j]=0;yq[j]=0;end end
  else begin
   for(j=5;j>0;j=j-1)begin sq[j]=sq[j-1];cq[j]=cq[j-1];xq[j]=xq[j-1];yq[j]=yq[j-1];end
   sq[0]={hs,vs,de};cq[0]=checking;xq[0]=xx;yq[0]=yy;
   #1;
   if({oh,ov,od}!==sq[5])$fatal(1,"six-cycle sync mismatch");
   if(cq[5]&&od)begin
    want=pixel(xq[5],yq[5]);pixels=pixels+1;
    if(want==24'hede9e2)ink=ink+1;
    if(xq[5]==24&&yq[5]==467)plate_count=plate_count+1;
    if(rgb!==want)$fatal(1,"pixel %s x%0d y%0d got%h expected%h",expected,xq[5],yq[5],rgb,want);
   end
  end
 end
 task step;begin @(posedge clk);#2;@(negedge clk);end endtask
 task key;input integer which,longpress;begin
  if(which==2)kn=0;else ka=0;
  repeat(8)step;if(longpress)repeat(40)step;
  if(which==2)kn=1;else ka=1;repeat(9)step;
 end endtask
 task status;input[135:0] s;integer n;begin
  for(n=0;n<17;n=n+1)if(dut.osd.status_char(n)!==s[(16-n)*8+:8])
   $fatal(1,"status col%0d got%c wanted%c (%s)",n,dut.osd.status_char(n),s[(16-n)*8+:8],s);
 end endtask
 task frame;begin vs=1;step;vs=0;repeat(32)step;end endtask
 task render;integer y0,x0;begin
  // All glyph rows, spaces, plate edges and background are checked.
  for(y0=466;y0<=478;y0=y0+1)begin
   de=0;repeat(8)step;dut.osd.y=y0;
   yy=y0;checking=1;de=1;
   for(x0=0;x0<141;x0=x0+1)begin xx=x0;step;end
   de=0;checking=0;repeat(8)step;
  end
 end endtask
 task commit;input[135:0] s;begin
  status(expected);frame;expected=s;status(s);render;checks=checks+1;
 end endtask
 task navigate;input[2:0] m;input[135:0] s;reg[1:0] z;begin
  z=scale;key(4,1);
  if(mode!==m||scale!==z)$fatal(1,"navigation mode%0d scale%0d expected mode%0d scale%0d",mode,scale,m,z);
  commit(s);
 end endtask
 task zoom_to;input[1:0] z;input[135:0] s;input integer k;begin
  key(k,0);if(scale!==z)$fatal(1,"zoom step got%0d expected%0d",scale,z);commit(s);
 end endtask
 integer i,r;reg[279:0] alphabet="0123456789BCVTZPAM:+-sX. RIGHONLSYD";reg[34:0] bits;
 initial begin
  repeat(4)step;rst=0;repeat(8)step;
  if(scale!==0||mode!==0||focus!==0||transition!==1||dual!==0)$fatal(1,"exhibit reset must be native1x");
  if(milliseconds!==5400||seconds!==5||fraction!==4)$fatal(1,"interval reset");
  // All 35 ROM glyphs, including high 6-bit indices S/Y/D.
  for(i=0;i<35;i=i+1)begin
   bits=glyph(alphabet[(34-i)*8+:8]);
   for(r=0;r<7;r=r+1)if(dut.osd.swap_rom.memory[576+i*7+r]!=={3'd0,bits[34-r*5-:5]})
    $fatal(1,"utility ROM mismatch index%0d row%0d",i,r);
   if(dut.osd.font_index(alphabet[(34-i)*8+:8])!==i)$fatal(1,"font index contract %0d",i);
  end
  frame;status(expected);render;
  navigate(1,"P1 BRIGHT +000   ");key(2,0);commit("P1 BRIGHT +016   ");key(4,0);commit("P1 BRIGHT +000   ");
  navigate(2,"P2 CONTR  1.00   ");key(2,0);commit("P2 CONTR  1.25   ");key(4,0);commit("P2 CONTR  1.00   ");
  navigate(3,"P3 INTV   05.4s  ");key(2,0);commit("P3 INTV   05.5s  ");key(4,0);commit("P3 INTV   05.4s  ");
  navigate(4,"P4 OSD    1      ");key(2,0);commit("P4 OSD    0      ");
  if(osd!==0||dut.osd.enabled!==0)$fatal(1,"OSD disable packing");
  navigate(5,"P5 TRANS  M1     ");key(2,0);
  if(transition!==2||dut.osd.trans_mode!==1)$fatal(1,"transition must wait for VS");
  commit("P5 TRANS  M2     ");key(2,0);commit("P5 TRANS  M0     ");key(2,0);commit("P5 TRANS  M1     ");
  navigate(6,"P6 ZOOM   1.0X   ");
  zoom_to(1,"P6 ZOOM   2.0X   ",2);zoom_to(2,"P6 ZOOM   3.0X   ",2);zoom_to(0,"P6 ZOOM   1.0X   ",2);
  zoom_to(2,"P6 ZOOM   3.0X   ",4);zoom_to(1,"P6 ZOOM   2.0X   ",4);
  for(i=1;i<=6;i=i+1)begin
   key(2,1);if(focus!==(i%6)||scale!==1)$fatal(1,"focus long press changes zoom or repeats");commit("P6 ZOOM   2.0X   ");
  end
  navigate(7,"P7 VOL    08     ");key(4,0);commit("P7 VOL    07     ");key(2,0);commit("P7 VOL    08     ");
  navigate(0,"P0 PLAY          ");
  key(2,1);if(dual!==1||scale!==1||mode!==0)$fatal(1,"dual long press overwrote zoom");commit("P0 PLAY          ");
  key(2,1);if(dual!==0||scale!==1||mode!==0)$fatal(1,"single long press overwrote zoom");commit("P0 PLAY          ");
  // Render every page again with captions disabled and a chosen non-default zoom.
  navigate(1,"P1 BRIGHT +000   ");navigate(2,"P2 CONTR  1.00   ");
  navigate(3,"P3 INTV   05.4s  ");navigate(4,"P4 OSD    0      ");
  navigate(5,"P5 TRANS  M1     ");navigate(6,"P6 ZOOM   2.0X   ");
  navigate(7,"P7 VOL    08     ");navigate(0,"P0 PLAY          ");
   if(scale!==1||osd!==0)$fatal(1,"page traversal overwrote chosen zoom/OSD");
   // Reassert the same production reset after a user-selected 2x setting.
   rst=1;repeat(4)step;rst=0;repeat(8)step;
   if(scale!==0||mode!==0||dual!==0||osd!==1||transition!==1||focus!==0)
    $fatal(1,"reset after user changes did not restore actual native1x");
   frame;status(expected);render;
   if(pixels<60000||ink<2000||plate_count<30)$fatal(1,"insufficient rendered evidence");
  $display("TEST_PASS probe_osd_default_1x commits=%0d pixels=%0d ink=%0d plates=%0d all8pages real_keys config_pack VS ROM35",checks,pixels,ink,plate_count);$finish;
 end
 initial begin #10000000;$fatal(1,"default1x watchdog");end
endmodule
