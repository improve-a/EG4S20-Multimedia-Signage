`timescale 1ns/1ps
module html_layer_line_setup_tb;
reg clk=0;always#12.5 clk=~clk;reg rst=1,iv=0,ready=1;
reg[4:0]tag=0;reg[20:0]base=0;reg signed[15:0]cx=0,cy=0,px=0,py=0;
reg[9:0]w=0,h=0,startx=0;reg[8:0]y=0;reg[1:0]kind=0;
reg signed[17:0]tx=0;reg signed[12:0]ty=0;reg[12:0]inv=4096;reg[7:0]alpha=255;
wire accept,ov;wire[4:0]ot;wire[1:0]ok;wire signed[31:0]origin;wire[16:0]step;
wire signed[15:0]ocx;wire[9:0]ow;wire[20:0]rowbase;wire[7:0]oa;
html_layer_line_setup dut(clk,rst,1'b0,iv,accept,tag,base,cx,cy,w,h,px,py,kind,tx,ty,inv,alpha,y,startx,ov,ready,ot,ok,origin,step,ocx,ow,rowbase,oa);
reg[31:0]desc[0:767],headers[0:95];reg[31:0]rng=32'h8bc713e9;
integer p,i,row,mode,sent=0,received=0,expected=0,cycles=0,j;
integer esy,erow,eorigin,estep,ebase;reg[31:0]e[0:150000];reg[31:0]ex[0:150000];reg[16:0]st[0:150000];reg[4:0]tags[0:150000];reg[1:0]kinds[0:150000];reg[9:0]widths[0:150000];reg signed[15:0]cxs[0:150000];reg[7:0]alphas[0:150000];
reg signed[63:0]calc;
always@(posedge clk)if(!rst)begin
 cycles=cycles+1;
 if(iv&&accept)begin
  sent=sent+1;
  if(kind==1&&inv!=4096)begin calc=$signed(ty);calc=calc>>>1;calc=$signed({1'b0,y})*128-$signed(py)*8-calc;calc=calc*$signed({1'b0,inv});calc=calc+$signed(py)*32768;esy=calc>>>19;end
  else begin calc=$signed(ty);calc=$signed({1'b0,y})*256-calc;esy=calc>>>8;end
  erow=esy-$signed(cy);
  if(alpha!=0&&w!=0&&h!=0&&erow>=0&&erow<h)begin
   if(kind==1&&inv!=4096)begin calc=$signed(tx);calc=calc>>>1;calc=$signed({1'b0,startx})*128-$signed(px)*8-calc;calc=calc*$signed({1'b0,inv});calc=calc>>>3;eorigin=calc+$signed(px)*4096;estep=inv*16;end
   else begin calc=$signed(tx);calc=calc*256;calc=$signed({1'b0,startx})*65536-calc;eorigin=calc;estep=65536;end
   e[expected]=base+erow*w;ex[expected]=eorigin;st[expected]=estep;tags[expected]=tag;kinds[expected]=kind;widths[expected]=w;cxs[expected]=cx;alphas[expected]=alpha;expected=expected+1;
  end
 end
 if(ov&&ready)begin
  if(received>=expected||rowbase!==e[received][20:0]||origin!==ex[received]||step!==st[received]||ot!==tags[received]||ok!==kinds[received]||ow!==widths[received]||ocx!==cxs[received]||oa!==alphas[received])$fatal(1,"line_setup tuple%0d gotbase%0d expected%0d origin%0d expected%0d",received,rowbase,e[received],origin,$signed(ex[received]));
  received=received+1;
 end
end
always@(negedge clk)begin rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};ready=rng[2:0]!=0;end
initial begin
 $readmemh("output/html_fidelity/layers/html_layer_descriptors.hex",desc);$readmemh("output/html_fidelity/layers/html_layer_headers.hex",headers);
 repeat(4)@(negedge clk);rst=0;
 for(mode=0;mode<3;mode=mode+1)for(p=0;p<6;p=p+1)for(row=0;row<480;row=row+1)for(i=0;i<16;i=i+1)begin
  if(desc[p*128+i*8][7:0]!=255)begin
   while(!accept)@(negedge clk);
   j=p*128+i*8;tag=i;base=headers[p*16+14]+desc[j+3];cx=desc[j+1][15:0];cy=desc[j+1][31:16];w=desc[j+2][15:0];h=desc[j+2][31:16];px=desc[j+4][15:0];py=desc[j+4][31:16];
   case(desc[j][7:0])2,3:kind=1;1:kind=2;4:kind=3;default:kind=0;endcase
   y=row;startx=mode==2?426:0;
   if(mode==0)begin tx=0;ty=0;inv=4096;alpha=255;end
   else if(mode==1)begin tx=-11775;ty=kind==3?-2560:0;inv=4096;alpha=kind==0?255:64;end
   else begin tx=kind==1?17920:kind==2?30720:0;ty=kind==3?3584:0;inv=kind==1?4245:4096;alpha=i%5==0?0:128;end
   iv=1;@(negedge clk);iv=0;
  end
 end
 while(!accept)@(negedge clk);repeat(4)@(negedge clk);
 if(received!=expected)$fatal(1,"linedrain");
 $display("TEST_PASS html_layer_line_setup all6HFXLdescriptors480rows3poses nearestQ7 hero_inverse signedoffsets originalDOMpivots orderedspan backpressure requests%0d spans%0d",sent,received);$finish;
end
initial begin #40000000;$fatal(1,"timeout");end
endmodule
