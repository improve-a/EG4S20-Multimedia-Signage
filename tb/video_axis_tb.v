`timescale 1ns/1ps
module video_axis_tb;
reg clk=0;always #5 clk=~clk;
reg rst=1,vs=0,de=0;reg[23:0] rgb=0;
wire user,valid,last;wire[23:0] data;
video_rgb_to_axis_640x480 dut(clk,rst,vs,de,rgb,user,valid,last,data);
integer x,y,frames,px,sof,eol;
initial begin
 px=0;sof=0;eol=0;repeat(5) @(negedge clk);rst=0;
 for(frames=0;frames<2;frames=frames+1) begin
   vs=1;repeat(2) @(negedge clk);vs=0;repeat(3) @(negedge clk);
   for(y=0;y<480;y=y+1) begin
     for(x=0;x<640;x=x+1) begin
       de=1;rgb=(frames<<20)|(y<<10)|x;@(posedge clk);#1;
       if(!valid || data!==rgb) $fatal(1,"pixel mismatch frame=%0d y=%0d x=%0d",frames,y,x);
       if(user !== (y==0 && x==0)) $fatal(1,"SOF incorrect y=%0d x=%0d",y,x);
       if(last !== (x==639)) $fatal(1,"TLAST incorrect y=%0d x=%0d last=%b",y,x,last);
       px=px+1;sof=sof+user;eol=eol+last;@(negedge clk);
     end
     de=0;repeat(4) @(negedge clk);
   end
 end
 if(px!=614400 || sof!=2 || eol!=960) $fatal(1,"count mismatch");
 $display("TEST_PASS video_axis pixels=%0d sof=%0d eol=%0d",px,sof,eol);$finish;
end
initial begin #100000000;$fatal(1,"timeout");end
endmodule
