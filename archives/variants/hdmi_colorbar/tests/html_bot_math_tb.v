`timescale 1ns/1ps
module html_bot_math_tb;
 reg clk=0;always #5 clk=~clk;
 wire h,v,d;wire[23:0] rgb;
 html_bot_overlay dut(.clk(clk),.rst(1'b1),.i_hs(1'b0),.i_vs(1'b0),.i_de(1'b0),.i_rgb(24'd0),
 .enable(1'b0),.page_event(1'b0),.page_direction(2'sd1),.speaking(1'b0),.syllable(1'b0),.audio_level(8'd0),
 .o_hs(h),.o_vs(v),.o_de(d),.o_rgb(rgb));
 real unit,radius,height,position;integer row;
 integer f,b,a,expected,got,checks=0,rx,ry,x,y,c1,c2,c3,c4,area_open,area_closed;
 initial begin
  #1;
  for(f=0;f<256;f=f+1)for(b=0;b<256;b=b+1)for(a=0;a<16;a=a+1)begin
   expected=(f*a+b*(15-a)+7)/15;
   got=dut.alpha15_result(dut.blend_product(f,b,a));
   if(got!=expected)$fatal(1,"linearalpha15 mismatch fg%0d bg%0d a%0d got%0d wanted%0d",f,b,a,got,expected);
   checks=checks+1;
  end
  for(rx=6;rx<=8;rx=rx+1)for(ry=1;ry<=7;ry=ry+1)for(row=0;row<32;row=row+1)begin
   height=(ry-0.5)*16;position=row*4+2;radius=(rx-0.5)*16;
   expected=0;
   if(position<height)expected=$rtoi(radius*$sqrt(1-(position/height)*(position/height))+0.5);
   got=dut.eye_edge((rx<<9)|(ry<<5)|row);
   if(got!=expected)$fatal(1,"factoredradius changed rx%0d ry%0d row%0d got%0d wanted%0d",rx,ry,row,got,expected);
   checks=checks+1;
  end
  for(rx=6;rx<=8;rx=rx+1)for(ry=1;ry<=7;ry=ry+1)for(x=0;x<=128;x=x+4)for(y=0;y<=128;y=y+4)begin
   c1=dut.eye_coverage_q4(x,y,rx,ry);c2=dut.eye_coverage_q4(-x,y,rx,ry);
   c3=dut.eye_coverage_q4(x,-y,rx,ry);c4=dut.eye_coverage_q4(-x,-y,rx,ry);
   if(c1!=c2||c1!=c3||c1!=c4)$fatal(1,"eye coverage asymmetric");
   checks=checks+1;
  end
  if(dut.eye_coverage_q4(0,0,7,7)!==15||dut.eye_coverage_q4(96,96,7,7)!==0||dut.eye_coverage_q4(0,32,7,1)!==0)
   $fatal(1,"circularbaseline/blinkcompression");
  for(a=0;a<16;a=a+1)for(b=0;b<16;b=b+1)begin
   expected=(244*a+dut.texture_channel(b)*(15-a)+7)/15;if(dut.alpha15_result(dut.blend_product(244,dut.texture_channel(b),a))!=expected)$fatal(1,"eyeRed coveragepalette");
   expected=(241*a+dut.texture_channel(b)*(15-a)+7)/15;if(dut.alpha15_result(dut.blend_product(241,dut.texture_channel(b),a))!=expected)$fatal(1,"eyeGreen coveragepalette");
   expected=(234*a+dut.texture_channel(b)*(15-a)+7)/15;if(dut.alpha15_result(dut.blend_product(234,dut.texture_channel(b),a))!=expected)$fatal(1,"eyeBlue coveragepalette");
   checks=checks+3;
  end
  $display("TEST_PASS Botmath all1048576alpha combinations,672exactanalyticradii,22869ellipse symmetries,768RGBcoverage cases checks%0d",checks);$finish;
 end
endmodule
