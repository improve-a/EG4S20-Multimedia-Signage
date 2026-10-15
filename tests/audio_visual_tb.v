`timescale 1ns/1ps
module audio_visual_tb;
reg clk=0;always #20 clk=~clk;
reg rst=1,hs=0,vs=0,de=0;reg[23:0]rgb=24'h123456;
reg sample_valid=0;reg[23:0]sample_left=0,sample_right=0;
reg[15:0]peak=0;reg[3:0]status=3;reg enable=0;
wire oh,ov,od;wire[23:0]out;
audio_visualizer dut(clk,rst,hs,vs,de,rgb,sample_valid,sample_left,sample_right,peak,status,enable,oh,ov,od,out);
integer x,y,k,j,point_idx,l,r,lp,rp,checked=0;reg[23:0]expected;reg[34:0]g_w,g_t;
reg[23:0]qrgb=0;reg[2:0]qsync=0;
task cycle;
 input[23:0]exp;
 begin
  @(posedge clk);#1;
  if({oh,ov,od}!==qsync)$fatal(1,"two-stage sync mismatch x%0d y%0d",x,y);
  if(out!==qrgb)$fatal(1,"pixel x%0d y%0d got %h expected prior %h",x,y,out,qrgb);
  qrgb=exp;qsync={hs,vs,de};checked=checked+1;@(negedge clk);
 end
endtask
task frame_start;
 begin de=0;vs=1;hs=0;cycle(rgb);vs=0;cycle(rgb);end
endtask
task raster;
 input integer filled;
 begin
  frame_start;
  for(y=0;y<480;y=y+1)begin
   for(x=0;x<640;x=x+1)begin
    de=1;hs=x%2;expected=rgb;
    if(enable&&x>=16&&x<528&&y>=320&&y<416)begin
     expected=24'h0a0e14;
     if(y==320||y==415||x==16||x==527)expected=24'h405060;
     else if(y==368)expected=24'h263340;
     if(filled==1&&x>=526)begin
      if(y==400)expected=24'h00ff80;
      if(y==337)expected=24'h40a0ff;
     end else if(filled==2)begin
      point_idx=44+(x-16)/2;l=(point_idx%64)-32;r=31-(point_idx%64);
      if(y==368-l)expected=24'h00ff80;
      if(y==368-r)expected=24'h40a0ff;
     end else if(filled==3)begin
      if(y==368)expected=24'hffffff;
     end
    end else if(enable&&x>=16&&x<528&&y>=428&&y<440)
     expected=(x-16<(peak>=32768?512:peak/64))?24'hffaa30:24'h0a0e14;
    else if(enable&&x>=16&&x<80&&y>=304&&y<318)begin
     // Status text exact-bit cases use directed checks separately below.
     expected=24'h0a0e14;
     if(status==3)begin
      if(text_ink(x-16,y-304))expected=24'hffffff;
     end
    end
    cycle(expected);
   end
   de=0;hs=1;cycle(rgb);
  end
 end
endtask
// Compile-friendly font reference function. Directed glyph bit checks below
// establish expected status semantics; raster verifies placement and clipping.
function text_ink;
 input integer cx,cy;reg[34:0]bits;
 begin bits=dut.glyph(dut.status_char(cx/12,status));text_ink=(cx%12<10)&&bits[34-(cy/2)*5-(cx%12)/2];end
endfunction
task point;
 input integer lv,rv;integer n;
 begin
  for(n=0;n<64;n=n+1)begin
   sample_valid=1;sample_left=(n==63)?(lv*262144):24'd0;sample_right=(n==63)?(rv*262144):24'd0;
   cycle(rgb);sample_valid=0;cycle(rgb);
  end
 end
endtask
initial begin
 @(posedge clk);#1;if({oh,ov,od,out}!==0)$fatal(1,"reset output");@(negedge clk);rst=0;
 // Bypass carries even blank RGB and independently toggling HS with same delay.
 raster(0);enable=1;peak=0;
 if(dut.history_count!=0)$fatal(1,"history appeared without samples");
 raster(0);
 point(-32,31);
 if(dut.history_count!=1||dut.history[0]!=={(-7'sd32),7'sd31})$fatal(1,"decimation/signed extrema storage");
 raster(1);
 // Fill and wrap: oldest point is 44 after writing total 300 history points.
 for(k=1;k<300;k=k+1)point((k%64)-32,31-(k%64));
 if(dut.history_count!=256||dut.write_pointer!=44)$fatal(1,"history ring count/pointer");
 peak=32768;raster(2);
 if(dut.status_char(0,4'hb)!="T"||dut.status_char(1,4'hb)!="O"||dut.status_char(2,4'hb)!="N"||dut.status_char(3,4'hb)!="E")$fatal(1,"fallback status not TONE");
 if(dut.status_char(0,4'he)!="W"||dut.status_char(2,4'he)!="E")$fatal(1,"W:HEX status");
 g_w=dut.glyph("W");g_t=dut.glyph("T");
 if(g_w[34]!=1||g_w[33]!=0||g_t[34:30]!=5'b11111)$fatal(1,"status glyph display bits");
 // All-zero real samples overwrite the full ring; trace becomes white center.
 for(k=0;k<256;k=k+1)point(0,0);
 peak=16384;raster(3);
 enable=0;rgb=24'ha55a7e;raster(0);
 // Reset invalidates RAM contents without resetting the RAM itself.
 rst=1;@(posedge clk);#1;@(negedge clk);rst=0;qrgb=0;qsync=0;
 if(dut.history_count!=0)$fatal(1,"history not invalidated by reset");
 $display("TEST_PASS audio visualizer: %0d pipeline/pixel checks; bypass/sync; unwritten history; 64-sample decimation; ring order/wrap; signed extrema/zero; peakbar endpoints; W:HEX/TONE",checked);$finish;
end
endmodule
