`timescale 1ns/1ps
module html_osd_columns_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,hs=0,vs=0,de=0;reg [23:0] rgb=0;
 reg [2:0] page=0;reg dual=0;reg signed [8:0] brightness=-255;
 wire dh,dv,dd,rh,rv,rd;wire [23:0] drgb,rrgb;
 html_osd_overlay dut(.clk(clk),.rst(rst),.i_hs(hs),.i_vs(vs),.i_de(de),.i_rgb(rgb),
 .osd_enable(1'b1),.page_event(1'b0),.page_index(page),.dual_enable(dual),.zoom_enable(1'b1),
 .scale_mode(2'd2),.focus(3'd5),.progress(8'd127),.brightness(brightness),.contrast(3'd3),.mode(3'd1),
 .volume(4'd12),.mute(1'b0),.paused(1'b0),.auto_mode(1'b1),.interval(8'd255),.interval_fraction(4'd0),
 .audio_peak(16'd20000),.audio_status(4'd2),.speaking(),.syllable(),.o_hs(dh),.o_vs(dv),.o_de(dd),.o_rgb(drgb));
 html_osd_reference refdut(.clk(clk),.rst(rst),.i_hs(hs),.i_vs(vs),.i_de(de),.i_rgb(rgb),
 .osd_enable(1'b1),.page_event(1'b0),.page_index(page),.dual_enable(dual),.zoom_enable(1'b1),
 .scale_mode(2'd2),.focus(3'd5),.progress(8'd127),.brightness(brightness),.contrast(3'd3),.mode(3'd1),
 .volume(4'd12),.mute(1'b0),.paused(1'b0),.auto_mode(1'b1),.interval(8'd255),.interval_fraction(4'd0),
 .audio_peak(16'd20000),.audio_status(4'd2),.speaking(),.syllable(),.o_hs(rh),.o_vs(rv),.o_de(rd),.o_rgb(rrgb));
 integer checks=0,pixels=0,xx=0,yy=0,layout,pass,seg,first,last,j;
 reg compare=0;integer xq[0:4],yq[0:4];
 always @(posedge clk)begin
  for(j=4;j>0;j=j-1)begin xq[j]=xq[j-1];yq[j]=yq[j-1];end
  xq[0]=xx;yq[0]=yy;
  #1;
  if(!rst&&compare)begin
   checks=checks+1;
   if({dh,dv,dd,drgb}!=={rh,rv,rd,rrgb})$fatal(1,"column/reference mismatch layout%0d pass%0d x%0d y%0d got%h ref%h sync%b%b",layout,pass,xq[4],yq[4],drgb,rrgb,{dh,dv,dd},{rh,rv,rd});
   if(dd)pixels=pixels+1;
  end
 end
 task step;begin @(posedge clk);#2;@(negedge clk);end endtask
 initial begin
  repeat(5)step;rst=0;
  for(layout=0;layout<12;layout=layout+1)begin
   page=layout%6;dual=layout>=6;brightness=layout%2 ? -255 : 255;
   vs=1;step;vs=0;repeat(8)step;
   for(pass=0;pass<(layout==0 ? 4 : 1);pass=pass+1)begin
    dut.swap_age=31;dut.swap_values=dut.SWAP_STEADY;dut.palette_loading=0;dut.palette_valid0=0;dut.swap_palette_ready=1;
    dut.typed_count=pass==0 ? 127 : pass==1 ? 0 : pass==2 ? 5 : 25;
    refdut.typed_count=dut.typed_count;dut.cursor_frame=0;refdut.cursor_frame=0;
    for(seg=0;seg<2;seg=seg+1)begin
     first=seg==0 ? 22 : 386;last=seg==0 ? 44 : 480;
     dut.y=first;refdut.y=first;
     compare=1;
     for(yy=first;yy<last;yy=yy+1)begin
      for(xx=0;xx<660;xx=xx+1)begin
       de=xx<640;hs=xx>=645&&xx<650;rgb={xx[7:0],yy[7:0],xx[7:0]^yy[7:0]};step;
      end
     end
     de=0;repeat(7)step;compare=0;
    end
   end
   $display("LAYOUT_PASS %0d checks%0d pixels%0d",layout,checks,pixels);$fflush();
  end
  $display("TEST_PASS html_osd_columns exact original-decoder geometry + scalar thirds AA checks%0d pixels%0d",checks,pixels);$finish;
 end
 initial begin #30000000;$fatal(1,"column regression watchdog");end
endmodule
