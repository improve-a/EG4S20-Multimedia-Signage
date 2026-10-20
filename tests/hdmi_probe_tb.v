`timescale 1ns/1ps
module tb;
 reg clk=0,rst=1,vs=0,hs=0,de=0,locked=0,audio=0;
 always #20 clk=~clk;
 integer cycle=0,h,v,mode=0,checks=0;
 wire rawvalid,rawuser,rawlast;wire [23:0] rawdata;
 wire av=mode==3?1'b0:rawvalid;
 wire au=mode==4?1'b0:rawuser;
 wire al=mode==5?1'b0:rawlast;
 wire ready=mode==2?1'b0:mode==6?(rawvalid&&dut.line_pixels!=100):rawvalid;
 wire [27:0] f;
 video_rgb_to_axis_640x480 source(clk,rst,vs,de,24'h123456,rawuser,rawvalid,rawlast,rawdata);
 hdmi_probe #(.WINDOW_CYCLES(5000),.FRAME_PIXELS(1280)) dut(
  clk,rst,vs,hs,de,av,au,al,ready,locked,audio,f);
 always @(negedge clk)begin
  if(rst)begin cycle=0;vs=0;hs=0;de=0;audio=0;end
  else begin
   cycle=cycle+1;h=cycle%800;v=(cycle/800)%3;
   vs=(v==0);hs=h<96;de=(mode!=1)&&(v!=0)&&(h>=160);audio=mode!=1&&cycle%521==0;
  end
 end
 task clocks;input integer n;begin repeat(n)@(posedge clk);#2;end endtask
 task clean;begin rst=1;clocks(4);rst=0;mode=0;locked=1;end endtask
 task must;input condition;input [255:0] name;begin
  checks=checks+1;if(condition!==1'b1)$fatal(1,"CHECK_FAIL %s flags=%h",name,f);
 end endtask
 initial begin
  clocks(4);rst=0;mode=0;locked=1;clocks(16000);
  must(f[9]&&!f[10],"frame1280 good");
  must(f[14]&&f[15]&&!f[16]&&!f[17],"SOF TLAST correct");
  must(f[18]&&f[19]&&!f[20]&&!f[21],"normal blank ready low");
  must(f[0]&&f[1]&&f[2]&&!f[3]&&!f[4],"stable lock");
  must(f[22]&&f[23]&&f[5]&&f[6]&&f[7]&&f[8],"audio VS DE activity");
  locked=0;clocks(2);must(f[3]&&!f[2]&&!f[0]&&f[1],"one lock drop sticky");
  locked=1;clocks(11000);must(f[3]&&f[2],"relock preserves drop");
  mode=1;clocks(11000);
  must(f[11]&&f[10]&&f[7]&&!f[8],"no DE and bad frame");
  must(f[22]&&!f[23],"audio stopped history");
  clean;locked=0;clocks(6000);must(f[4]&&!f[1],"never locked timeout");
  locked=1;clocks(2);must(f[4]&&f[1],"late lock retains timeout");
  clean;mode=2;clocks(5000);must(f[19]&&f[20]&&f[21]&&!f[18],"valid and SOL ready conflict");
  clean;mode=6;clocks(5000);must(f[20]&&!f[21],"midline conflict not SOL");
  clean;mode=3;clocks(5000);must(f[17],"valid not delayed DE");
  clean;mode=4;clocks(5000);must(f[16]&&!f[14],"missing SOF");
  clean;mode=5;clocks(5000);must(f[17]&&!f[15],"missing TLAST");
  clean;clocks(10);must(!f[3]&&!f[4]&&!f[10]&&!f[11]&&!f[16]&&!f[17]&&!f[20],"reset clears sticky");
  $display("PROBE_UNIT_PASS checks=%0d",checks);$finish;
 end
 initial begin #4000000;$fatal(1,"watchdog");end
endmodule

module display_tb;
 reg clk=0,rst=1;always #10 clk=~clk;
 reg [27:0] flags=0;reg vr=0,sl=1,vl=1;
 wire [23:0] digits;wire [2:0] page;
 hdmi_probe_display #(.PAGE_CYCLES(30)) dut(clk,rst,flags,vr,sl,vl,digits,page);
 integer n,seen=0;
 initial begin
  repeat(4)@(negedge clk);rst=0;
  flags[0]=1;flags[1]=1;flags[2]=1;
  flags[5]=1;flags[6]=1;flags[7]=1;flags[8]=1;flags[25]=1;flags[26]=1;flags[9]=1;
  flags[12]=1;flags[13]=1;flags[14]=1;flags[15]=1;
  flags[18]=1;flags[19]=1;flags[22]=1;flags[23]=1;flags[24]=1;
  repeat(5)@(negedge clk);
  for(n=0;n<155;n=n+1)begin
   @(negedge clk);
   case(page)
    1:if(digits!==24'h111100)$fatal(1,"page1 %h",digits);
    2:if(digits!==24'h222210)$fatal(1,"page2 %h",digits);
    3:if(digits!==24'h321100)$fatal(1,"page3 %h",digits);
    4:if(digits!==24'h411000)$fatal(1,"page4 %h",digits);
    5:if(digits!==24'h520111)$fatal(1,"page5 %h",digits);
    default:$fatal(1,"page range");
   endcase
   seen=seen|(1<<page);
  end
  if(seen!=62)$fatal(1,"missing pages");
  $display("PROBE_DISPLAY_PASS all5pages CDC stable flags");$finish;
 end
endmodule
