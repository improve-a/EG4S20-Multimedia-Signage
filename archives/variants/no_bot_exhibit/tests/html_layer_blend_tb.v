`timescale 1ns/1ps
module html_layer_blend_tb;
reg clk=0;always#12.5 clk=~clk;reg rst=1,iv=0;
reg[23:0]bg=0;reg[31:0]fg=0;reg[7:0]opacity=0;reg[11:0]tag=0;
wire ov;wire[11:0]ot;wire[23:0]rgb;
html_layer_blend dut(clk,rst,iv,tag,bg,fg,opacity,ov,ot,rgb);
reg[23:0]expect_rgb[0:100000];reg[11:0]expect_tag[0:100000];reg[31:0]rng=32'h137984af;
integer sent=0,received=0,a,o,k,n;reg[23:0]expected;
function[23:0]gold;input[23:0]b;input[31:0]f;input[7:0]op;integer aa,r,g,bb;
begin aa=(f[7:0]*op+127)/255;r=(f[31:24]*aa+b[23:16]*(255-aa)+127)/255;
g=(f[23:16]*aa+b[15:8]*(255-aa)+127)/255;bb=(f[15:8]*aa+b[7:0]*(255-aa)+127)/255;gold={r[7:0],g[7:0],bb[7:0]};end endfunction
always@(posedge clk)if(!rst)begin
 if(iv)begin expect_rgb[sent]=gold(bg,fg,opacity);expect_tag[sent]=tag;sent=sent+1;end
 if(ov)begin if(received>=sent||rgb!==expect_rgb[received]||ot!==expect_tag[received])$fatal(1,"blend expected%h actual%h item%0d",expect_rgb[received],rgb,received);received=received+1;end
end
initial begin
 repeat(4)@(negedge clk);rst=0;
 // Every intrinsic alpha/motion opacity pair with alternating black/white
 // verifies signed RGB differences and both /255 roundings at all extremes.
 for(a=0;a<256;a=a+1)for(o=0;o<256;o=o+1)begin
  @(negedge clk);iv=1;opacity=o;tag=sent;fg={8'hff,8'h00,8'h7f,a[7:0]};bg=24'h00ff80;
 end
 for(n=0;n<20000;n=n+1)begin
  @(negedge clk);rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};iv=rng[2:0]!=0;tag=sent;fg=rng;bg=rng[23:0]^24'h6b91c7;opacity=rng[21:14];
 end
 @(negedge clk);iv=0;repeat(8)@(negedge clk);
 if(received!=sent)$fatal(1,"blenddrain");
 $display("TEST_PASS html_layer_blend exhaustive65536 alpha_opacity pairs randomRGB bubbles signedsourceover rounding orderedtags count%0d",received);$finish;
end
endmodule
