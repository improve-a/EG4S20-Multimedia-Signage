`timescale 1ns/1ps
module pixel_adjust_tb;
reg clk=0;always #5 clk=~clk;
reg rst=1,hs=0,vs=0,de=0;
reg [23:0] rgb=0;
reg signed [8:0] brightness=0;
reg [2:0] contrast=2;
wire oh,ov,od;wire [23:0] out;
pixel_adjust dut(clk,rst,hs,vs,de,rgb,brightness,contrast,oh,ov,od,out);
integer fd,rc,n=0;reg [23:0] expected;reg [1023:0] vectors;
initial begin
 if(!$value$plusargs("vectors=%s",vectors)) vectors="tests/pixel_vectors.txt";
 fd=$fopen(vectors,"r");if(!fd)$fatal(1,"vectors missing");
 @(posedge clk);#1;if({oh,ov,od,out}!==0)$fatal(1,"reset");
 @(negedge clk);rst=0;
 while(!$feof(fd)) begin
  rc=$fscanf(fd,"%h %h %h %h\n",rgb,brightness,contrast,expected);
  if(rc==4) begin
   hs=n%2;vs=(n%7)==0;de=1;
   @(posedge clk);#1;
   if(out!==expected || {oh,ov,od}!=={hs,vs,de})$fatal(1,"vector %0d got %h expected %h",n,out,expected);
   @(negedge clk);n=n+1;
  end
 end
 de=0;rgb=24'hffffff;hs=1;vs=1;
 @(posedge clk);#1;if(out!==0 || {oh,ov,od}!==3'b110)$fatal(1,"blank sync");
 @(negedge clk);rst=1;
 @(posedge clk);#1;if({oh,ov,od,out}!==0)$fatal(1,"midstream reset");
 $display("TEST_PASS pixel_adjust %0d vectors",n);$finish;
end
endmodule
