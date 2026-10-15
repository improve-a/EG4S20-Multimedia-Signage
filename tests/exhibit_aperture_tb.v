`timescale 1ns/1ps
module exhibit_aperture_tb;
reg clk=0;always#5 clk=~clk;
reg rst=1,latch=0,step=0,direction=0;reg[2:0]page=0;reg[1:0]mode=1;
wire[20:0]addr;wire valid;
exhibit_viewport #(.ENABLE_TRANSITION(1),.EXPLICIT_DIRECTION(1))dut(.clk(clk),.rst(rst),.frame_latch(latch),.pixel_step(step),
.page_index(page),.dual_enable(1'b0),.zoom(2'd0),.focus(3'd0),.transition_mode(mode),.panels_ready(1'b0),.page_reverse(direction),.mapped_addr(addr),.mapped_valid(valid));
integer golden[0:63];integer checks=0,x=0,e0=0,e1=0,e2=0,oldp=0,newp=0,width=640,rev=0;
reg[2:0]v=0;
always@(posedge clk)begin
 if(rst)begin v=0;x=0;end
 else begin
  e2=e1;e1=e0;v={v[1:0],step&&!latch};
  if(latch)x=0;
  else if(step)begin
   e0=((rev?(x<width):(x>=640-width))?newp:oldp)*307200+x;
   x=x+1;
  end
  #1;if(valid!==v[2])$fatal(1,"valid");
  if(valid)begin if(addr!==e2)$fatal(1,"aperture got%0d expected%0d",addr,e2);checks=checks+1;end
 end
end
task line;input integer p,w,r,o;
begin
 @(negedge clk);page=p;width=w;rev=r;direction=r;oldp=o;newp=p;latch=1;step=0;
 @(negedge clk);latch=0;step=1;repeat(640)@(negedge clk);step=0;repeat(4)@(negedge clk);
end endtask
integer i;
initial begin
 golden[0]=0;
 golden[1]=0;
 golden[2]=0;
 golden[3]=1;
 golden[4]=2;
 golden[5]=3;
 golden[6]=4;
 golden[7]=5;
 golden[8]=7;
 golden[9]=9;
 golden[10]=12;
 golden[11]=15;
 golden[12]=18;
 golden[13]=22;
 golden[14]=26;
 golden[15]=31;
 golden[16]=36;
 golden[17]=42;
 golden[18]=49;
 golden[19]=56;
 golden[20]=65;
 golden[21]=75;
 golden[22]=86;
 golden[23]=98;
 golden[24]=113;
 golden[25]=129;
 golden[26]=149;
 golden[27]=172;
 golden[28]=199;
 golden[29]=231;
 golden[30]=268;
 golden[31]=309;
 golden[32]=352;
 golden[33]=391;
 golden[34]=426;
 golden[35]=455;
 golden[36]=480;
 golden[37]=501;
 golden[38]=519;
 golden[39]=535;
 golden[40]=548;
 golden[41]=560;
 golden[42]=570;
 golden[43]=580;
 golden[44]=588;
 golden[45]=595;
 golden[46]=601;
 golden[47]=607;
 golden[48]=612;
 golden[49]=616;
 golden[50]=620;
 golden[51]=624;
 golden[52]=627;
 golden[53]=630;
 golden[54]=632;
 golden[55]=634;
 golden[56]=635;
 golden[57]=637;
 golden[58]=638;
 golden[59]=639;
 golden[60]=639;
 golden[61]=640;
 golden[62]=640;
 golden[63]=640;
 repeat(4)@(negedge clk);rst=0;
 line(0,640,0,0);
 for(i=0;i<64;i=i+1)line(1,golden[i],0,0);
 // Reverse previous-page event uses the opposite aperture andlocks source metadata.
 for(i=0;i<64;i=i+1)line(0,golden[i],1,1);
 for(i=0;i<64;i=i+1)line(4,golden[i],1,0); // Explicitreverse, non-neighbourlatestrequest.
 mode=0;line(5,640,0,0);
 mode=1;line(0,0,0,5); // Forwardwrap5->0 mustenter fromright.
 $display("TEST_PASS exhibit_aperture %0d per_pixeladdresses eased1050msactual16.8msframe forward_reverse_wrap_cut noextraSDRAMreads",checks);$finish;
end
endmodule
