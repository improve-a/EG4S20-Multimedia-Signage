`timescale 1ns/1ps
// Actual final production wrapper. Independent unchanged-pixel oracle covers
// former character/tail region with OSD on and every pixel with OSD disabled.
// Preloaded y=380 bounds simulation cost; this is not production frame cadence.
module no_bot_overlay_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,hs=0,vs=0,de=0,page_event=0,enable=1,dual=0;
 reg[2:0]page=0,focus=0;reg[1:0]zoom=0;reg[23:0]src=0;
 wire oh,ov,od;wire[23:0]rgb;
 wire[50:0]cfg={4'd4,4'd0,1'b0,1'b0,1'b1,8'd173,4'd8,zoom,2'd1,enable,8'd5,3'd2,9'd0,3'd0};
 html_video_overlay dut(.clk(clk),.rst(rst),.i_hs(hs),.i_vs(vs),.i_de(de),.i_rgb(src),.config_data(cfg),.page_event(page_event),.page_index(page),.dual_enable(dual),.page_reverse(1'b0),.focus(focus),.audio_peak(16'd24576),.audio_status(4'd2),.o_hs(oh),.o_vs(ov),.o_de(od),.o_rgb(rgb));
 reg[2:0]sq[0:5];reg[23:0]eq[0:5];reg checkq[0:5];integer xx=0,yy=0,k,mode,checks=0,tailchecks=0,syncchecks=0;
 always@(posedge clk)begin
  for(k=5;k>0;k=k-1)begin sq[k]=sq[k-1];eq[k]=eq[k-1];checkq[k]=checkq[k-1];end
  sq[0]={hs,vs,de};eq[0]=de?src:24'd0;checkq[0]=de&&(!enable||xx>=510);
  #1;if(!rst)begin
   if({oh,ov,od}!==sq[5])$fatal(1,"noBot wrapper six-clock qualifier alignment");
   if(checkq[5])begin if(rgb!==eq[5])$fatal(1,"noBot unchanged pixel got%h expected%h",rgb,eq[5]);checks=checks+1;end
   if(dut.osd.speaking!==0||dut.osd.syllable!==0)$fatal(1,"legacy character outputs must be zero");
   syncchecks=syncchecks+1;
  end
 end
 task step;begin @(posedge clk);#2;@(negedge clk);end endtask
 initial begin
  for(k=0;k<6;k=k+1)begin sq[k]=0;eq[k]=0;checkq[k]=0;end
  repeat(10)step;rst=0;
  for(mode=0;mode<12;mode=mode+1)begin
   page=mode%6;dual=mode%2;zoom=mode%3;focus=mode%6;enable=mode<6;
   page_event=1;vs=1;step;page_event=0;vs=0;repeat(50)step;
   dut.osd.y=380;
   for(yy=380;yy<480;yy=yy+1)begin
    for(xx=0;xx<640;xx=xx+1)begin de=1;src={xx[7:0],yy[7:0],(xx[7:0]^yy[7:0])};step;end
    de=0;step;
   end
   repeat(10)step;
  end
  if(checks!=6*(130+640)*100)$fatal(1,"noBot checked pixel total%0d",checks);
  $display("TEST_PASS noBot productionwrapper sixclock qualifiers,6pages OSDon/off dual/zoom/focus,462000exactbackgroundpixels including formertail+characterregion,legacyoutputs0; accelerated region test");$finish;
 end
 initial begin #10000000;$fatal(1,"noBot overlay timeout");end
endmodule
