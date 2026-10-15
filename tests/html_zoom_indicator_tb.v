`timescale 1ns/1ps
module html_zoom_indicator_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,hs=0,vs=0,de=0;
 reg [23:0] rgb=24'h123456;
 reg [2:0] page=0,focus=0;
 reg [1:0] scale=0;
 wire oh,ov,od;wire [23:0] out;
 wire sp,sy;
 html_osd_overlay dut(.clk(clk),.rst(rst),.i_hs(hs),.i_vs(vs),.i_de(de),.i_rgb(rgb),
  .osd_enable(1'b1),.page_event(1'b0),.page_index(page),.dual_enable(1'b0),.zoom_enable(scale!=0),
  .scale_mode(scale),.focus(focus),.progress(8'd0),.brightness(9'd0),.contrast(3'd2),.mode(3'd0),
  .volume(4'd8),.mute(1'b0),.paused(1'b0),.auto_mode(1'b1),.interval(8'd5),
  .audio_peak(16'd0),.audio_status(4'd0),.speaking(sp),.syllable(sy),
  .o_hs(oh),.o_vs(ov),.o_de(od),.o_rgb(out));
 exhibit_viewport mapper(.clk(clk),.rst(rst),.frame_latch(1'b0),.pixel_step(1'b0),
  .page_index(page),.dual_enable(1'b0),.page_reverse(1'b0),.zoom(scale),.focus(focus),
  .transition_mode(2'd0),.panels_ready(1'b1),.mapped_addr(),.mapped_valid(),
  .mapped_packed(),.mapped_half(),.mapped_black());
 integer p,f,z,d,l,t,w,h,xx,yy,checks=0,pixels=0;
 reg [23:0] org,expected_bounds,before_bounds;
 reg [2:0] sync_queue[0:4];integer xq[0:4],yq[0:4],q;
 reg pixel_checks=0;
 always @(posedge clk)begin
  if(rst)begin for(q=0;q<5;q=q+1)begin sync_queue[q]=0;xq[q]=0;yq[q]=0;end end
  else begin
   for(q=4;q>0;q=q-1)begin sync_queue[q]=sync_queue[q-1];xq[q]=xq[q-1];yq[q]=yq[q-1];end
   sync_queue[0]={hs,vs,de};xq[0]=xx;yq[0]=yy;
   #1;if({oh,ov,od}!==sync_queue[4])$fatal(1,"zoom indicator changed pipeline latency");
   if(pixel_checks&&od)begin
    pixels=pixels+1;
    if(xq[4]==522&&yq[4]==62&&out!==24'h64778a)$fatal(1,"mini outerborder alpha got%h",out);
    if(xq[4]==545&&yq[4]==72&&out!==24'hede9e2)$fatal(1,"viewportrectangle default2xleft notmapped correctly %h",out);
    if(xq[4]==550&&yq[4]==72&&out!==24'h2d4a67)$fatal(1,"viewportrectangle interioralpha %h",out);
    if(xq[4]==520&&yq[4]==72&&out!==rgb)$fatal(1,"badge leakedoutside sourcebounds");
   end
  end
 end
 task step;begin @(posedge clk);#2;@(negedge clk);end endtask
 task frame;begin vs=1;step;vs=0;repeat(7)step;end endtask
 initial begin
  xx=0;yy=0;repeat(3)step;rst=0;
  for(p=0;p<2;p=p+1)for(f=0;f<6;f=f+1)for(z=0;z<4;z=z+1)begin
   before_bounds=dut.mini_bounds;page=p;focus=f;scale=z;repeat(2)step;
   if(dut.mini_bounds!==before_bounds)$fatal(1,"zoom/focus configuration changed midframe");
   frame;org=mapper.origin(p==0,f,z);d=z==0 ? 1 : z==1 ? 2 : 3;
   l=(org[23:14]*50*d+org[3:2]*50)/(640*d);t=(org[12:4]*37*d+org[1:0]*37)/(480*d);
   w=(50+d/2)/d;h=(37+d/2)/d;if(l+w>50)l=50-w;if(t+h>37)t=37-h;
   expected_bounds=(l<<18)|(t<<12)|(w<<6)|h;
   if(dut.mini_bounds!==expected_bounds)$fatal(1,"mapper geometry mismatch page%0d focus%0d zoom%0d got%h expected%h",p,f,z,dut.mini_bounds,expected_bounds);
   if(dut.live_char(27)!==8'd48+d)$fatal(1,"live Z shows wrong actualfactor");
   checks=checks+1;
  end
  page=1;focus=0;scale=1;frame;
  if(dut.mini_bounds!=={6'd22,6'd4,6'd25,6'd19})$fatal(1,"source Eagle2xdefault DOMgeometry");
  pixel_checks=1;
  for(yy=0;yy<105;yy=yy+1)begin
   for(xx=0;xx<640;xx=xx+1)begin de=1;step;end
   de=0;step;
  end
  repeat(8)step;pixel_checks=0;
  if(pixels!=640*105)$fatal(1,"indicator region pixelcount");
  $display("TEST_PASS html_zoom_indicator48configurations actualmappergeometry,67200pixels,frameatomic,latencyunchanged");$finish;
 end
 initial begin #10000000;$fatal(1,"zoom indicator watchdog");end
endmodule
