`timescale 1ns/1ps
module video_extensions_tb;
reg clk=0;always #20 clk=~clk;
reg rst=1,hs=0,vs=0,de=0;reg [23:0] rgb=0;
reg [46:0] cfg=0;
reg signed [8:0] brightness=0;reg [2:0] contrast=2;reg enable=0;
wire oh,ov,od;wire [23:0] out;
wire user,valid,last;wire [23:0] data;
video_extensions dut(clk,rst,hs,vs,de,rgb,cfg,oh,ov,od,out);
video_rgb_to_axis_640x480 axis(clk,rst,ov,od,out,user,valid,last,data);
reg [23:0] q0=0,q1=0;
reg [2:0] s0=0,s1=0;
reg u0=0,u1=0,l0=0,l1=0,m0=1,m1=1;
integer checks=0,pixels=0,sof_count=0,eol_count=0,x,y,f;reg [23:0] expected;reg mask,sof,eol;
function [7:0] adjust;
 input [7:0] p;input signed [8:0] b;input [2:0] c;
 integer n,q;
 begin q=c==7?4:c+2;n=($signed({1'b0,p})-128)*q;
 // Explicit mathematical floor of negative quarter values.
 n=(n>=0?n/4:-((-n+3)/4))+128+$signed(b);
 adjust=n<0?0:n>255?255:n;
 end
endfunction
task cycle;
 begin
 expected=de?{adjust(rgb[23:16],brightness,contrast),adjust(rgb[15:8],brightness,contrast),adjust(rgb[7:0],brightness,contrast)}:0;
 mask=1;sof=de && x==0 && y==0;eol=de && x==639;
 if(enable && de)begin
  if((x>=16 && x<208 && y>=16 && y<32) ||
     (x>=16 && x<392 && y>=40 && y<49) || (y>=450 && y<459))mask=0;
  // Independent anchors verify OSD position and source/OSD pipeline alignment.
  if(y==16 && (x==16 || x==17 || x==24 || x==25))begin mask=1;expected=24'hffffff;end
  if(y==16 && (x==18 || x==19 || x==26 || x==27))begin mask=1;expected=24'h101820;end
  if(y==40 && x==16)begin mask=1;expected=24'hffffff;end
  if(y>=468 && y<472 && x>=16 && x<272)expected=x<144?24'h28dce8:24'h202020;
 end
 @(posedge clk);#1;
 if({oh,ov,od}!==s0)$fatal(1,"extension sync latency");
 if(m0 && out!==q0)$fatal(1,"extension data f%0d x%0d y%0d got%h exp%h",f,x,y,out,q0);
 if({valid,user,last}!=={s1[0],u1,l1})$fatal(1,"AXIS flags f%0d x%0d y%0d got%b exp%b",f,x,y,{valid,user,last},{s1[0],u1,l1});
 if(m1 && data!==q1)$fatal(1,"AXIS RGB mismatch");
 if(valid)pixels=pixels+1;if(user)sof_count=sof_count+1;if(last)eol_count=eol_count+1;
 q1=q0;q0=expected;s1=s0;s0={hs,vs,de};
 u1=u0;u0=sof;l1=l0;l0=eol;m1=m0;m0=mask;
 checks=checks+1;@(negedge clk);
 end
endtask
initial begin
 @(posedge clk);#1;@(negedge clk);rst=0;
 for(f=0;f<4;f=f+1)begin
  case(f)
  0:begin brightness=0;contrast=2;enable=0;end
  1:begin brightness=40;contrast=2;enable=0;end
  2:begin brightness=-1;contrast=0;enable=0;end
  3:begin brightness=0;contrast=2;enable=1;end
  endcase
  cfg={4'd1,1'b0,1'b0,1'b0,8'd128,4'd8,2'd0,2'd0,enable,8'd10,contrast,brightness,3'd0};
  // VS transitions occur well before the first active pixel. Drain previous
  // frame before updating cfg, matching production frame-commit behavior.
  de=0;vs=1;hs=0;repeat(5)cycle;vs=0;repeat(5)cycle;
  for(y=0;y<480;y=y+1)begin
   for(x=0;x<640;x=x+1)begin
    de=1;hs=0;rgb={x[7:0],y[7:0],(x[7:0]^y[7:0])};cycle;
   end
   de=0;hs=1;repeat(8)cycle;
  end
  de=0;hs=0;repeat(5)cycle;
 end
 if(pixels!=4*640*480 || sof_count!=4 || eol_count!=4*480)$fatal(1,"frame totals %0d %0d %0d",pixels,sof_count,eol_count);
 $display("TEST_PASS video_extensions %0d cycles %0d pixels %0d SOF %0d EOL",checks,pixels,sof_count,eol_count);$finish;
end
endmodule
