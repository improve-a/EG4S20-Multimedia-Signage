`timescale 1ns/1ps
module html_osd_swap_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,vs=0,de=0,page_event=0;wire h,v,d;wire[23:0] rgb;
 html_osd_overlay dut(.clk(clk),.rst(rst),.i_hs(1'b0),.i_vs(vs),.i_de(de),.i_rgb(24'h123456),
  .osd_enable(1'b1),.page_event(page_event),.page_index(3'd0),.dual_enable(1'b0),.zoom_enable(1'b0),
  .scale_mode(2'd0),.focus(3'd0),.progress(8'd0),.brightness(9'd0),.contrast(3'd2),.mode(3'd0),
  .volume(4'd8),.mute(1'b0),.paused(1'b0),.auto_mode(1'b1),.interval(8'd5),.interval_fraction(4'd0),
  .audio_peak(16'd0),.audio_status(4'd0),.speaking(),.syllable(),.o_hs(h),.o_vs(v),.o_de(d),.o_rgb(rgb));
 integer xx=0,yy=0,j,age,fd,framefd,pixels=0,checks=0;reg capture=0;
 reg[23:0] eq[0:4];reg cq[0:4];reg[2:0] sq[0:4];
 reg[15:0] atlas[0:9639];initial $readmemh("rtl/ext/html_assets/html_glyph_coverage.hex",atlas);
 wire[7:0] gid;wire[3:0] gx;wire[4:0] gy;wire[6:0] ordinal,total;wire caption,text,pause;
 wire[9:0] rx=xx;wire[9:0] ry=yy-dut.swap_y;
 html_caption_map original_map(.page_index(3'd0),.dual_enable(1'b0),.x(rx),.y(ry),.glyph_id(gid),.glyph_x(gx),.glyph_y(gy),
  .char_index(ordinal),.is_caption(caption),.is_text(text),.total_chars(total),.typing_index(7'd0),.punctuation_pause(pause));
 reg[1:0] coverage;reg[23:0] expected;reg cursor,gray;
 always @*begin
  coverage=0;expected=24'hede9e2;gray=ry<411&&xx>=94;
  if(text&&!caption&&gy<20)coverage=(atlas[gid*40+gy*2+gx[3]]>>(14-gx[2:0]*2))&3;
  cursor=text&&caption&&ordinal==0&&gx>=1&&gx<5&&gy>=11&&gy<15&&
   !((gx==1||gx==4)&&(gy==11||gy==14));
  if(cursor)begin coverage=3;gray=0;end
  if(gray)begin
   case(coverage)
    1:expected=dut.swap_values[71:48];2:expected=dut.swap_values[47:24];3:expected=dut.swap_values[23:0];default:expected=24'hede9e2;
   endcase
  end else begin
   case(coverage)
    1:expected=dut.swap_values[143:120];2:expected=dut.swap_values[119:96];3:expected=dut.swap_values[95:72];default:expected=24'hede9e2;
   endcase
  end
 end
 always @(posedge clk)begin
  for(j=4;j>0;j=j-1)begin eq[j]=eq[j-1];cq[j]=cq[j-1];sq[j]=sq[j-1];end
  eq[0]=expected;cq[0]=capture&&de&&xx>=42&&xx<434&&yy>=397&&yy<455;sq[0]={1'b0,vs,de};
  #1;if(!rst&&{h,v,d}!==sq[4])$fatal(1,"swap changedfive-stage latency");
  if(cq[4])begin
   checks=checks+1;
   if(rgb!==eq[4])$fatal(1,"swap original-map pixel mismatch age%0d got%h expected%h",age,rgb,eq[4]);
  end
  if(capture&&d)begin $fwrite(framefd,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);pixels=pixels+1;end
 end
 task step;begin @(posedge clk);#2;@(negedge clk);end endtask
 task frame;begin vs=1;step;vs=0;page_event=0;repeat(24)step;end endtask
 task region;
 reg[127:0] name;
 begin
  $sformat(name,"swap_%02d.ppm",age);framefd=$fopen(name,"wb");$fwrite(framefd,"P6\n640 83\n255\n");
  dut.y=386;dut.cursor_frame=0;capture=1;
  for(yy=386;yy<469;yy=yy+1)begin
   for(xx=0;xx<640;xx=xx+1)begin de=1;step;end
   de=0;step;
  end
  repeat(8)step;capture=0;$fclose(framefd);
 end endtask
 initial begin
  for(j=0;j<5;j=j+1)begin eq[j]=0;cq[j]=0;sq[j]=0;end
  fd=$fopen("swap_actual.csv","w");$fdisplay(fd,"age,values");
  repeat(5)step;rst=0;frame;
  for(age=0;age<32;age=age+1)begin
   page_event=age==0;frame;page_event=0;
   if(dut.swap_age!==age)$fatal(1,"swap age notframe-synchronous %0d",dut.swap_age);
   $fdisplay(fd,"%0d,%h",age,dut.swap_values);
   if(age==0||age==3||age==10||age==30)region;
  end
  $fclose(fd);
  if(checks!=90944||pixels!=212480)$fatal(1,"swap pixel/check count %0d %0d",checks,pixels);
  $display("TEST_PASS OSDswap32frameparameters,212480actualDUTpixels,90944originalmap/opacitychecks,five-stage sync");$finish;
 end
endmodule
