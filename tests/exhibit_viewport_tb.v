`timescale 1ns/1ps
module exhibit_viewport_tb;
reg clk=0;always #5 clk=~clk;
reg rst=1,frame_latch=0,pixel_step=0,dual_enable=0;
reg[2:0]page_index=0,focus=0;reg[1:0]zoom=0;
wire[20:0]addr;wire valid;
exhibit_viewport dut(.clk(clk),.rst(rst),.frame_latch(frame_latch),.pixel_step(pixel_step),
.page_index(page_index),.dual_enable(dual_enable),.zoom(zoom),.focus(focus),.mapped_addr(addr),.mapped_valid(valid),
.transition_mode(2'd0),.panels_ready(1'b0));
integer x=0,y=0,p=0,z=1,f=0,d=0,cx,cy,panx,pany,mx,my,srcp,sx;
integer e0=0,e1=0,e2=0,accepted=0,checked=0,frames=0;
reg[2:0]v=0;reg[31:0]rng=32'h18af9031;
always @(posedge clk)begin
 if(rst)begin v=0;x=0;y=0;end
 else begin
  e2=e1;e1=e0;v={v[1:0],pixel_step&&!frame_latch};
  if(frame_latch)begin
   x=0;y=0;p=page_index;z=zoom+1;f=focus;d=dual_enable;
   case(f)
    0:begin cx=p==0?435:448;cy=p==0?192:173;end
    1:begin cx=320;cy=240;end
    2:begin cx=160;cy=240;end
    3:begin cx=480;cy=240;end
    4:begin cx=320;cy=120;end
    5:begin cx=320;cy=360;end
   endcase
   panx=cx*z-320;if(panx<0)panx=0;if(panx>640*(z-1))panx=640*(z-1);
   pany=cy*z-240;if(pany<0)pany=0;if(pany>480*(z-1))pany=480*(z-1);
  end else if(pixel_step)begin
   mx=(x+panx)/z;my=(y+pany)/z;srcp=p;sx=mx;
   if(d)begin
    case(p)
     1:srcp=mx>=320?2:1;2:srcp=mx>=320?1:2;
     3:srcp=mx>=320?4:3;4:srcp=mx>=320?3:4;
     default:srcp=mx>=320?2:1;
    endcase
    sx=(mx%320)*2;
   end
   e0=srcp*307200+my*640+sx;
   if(x==639)begin x=0;y=y==479?0:y+1;end else x=x+1;
   accepted=accepted+1;
  end
  #1;
  if(valid!==v[2])$fatal(1,"valid latency/bubble mismatch");
  if(valid)begin
   if(addr!==e2 || addr>=1843200)$fatal(1,"addr got%0d expected%0d checked%0d",addr,e2,checked);
   checked=checked+1;
  end
 end
end
task frame;
input integer pp,dd,zz,ff;
integer n;
begin
 @(negedge clk);page_index=pp;dual_enable=dd;zoom=zz;focus=ff;frame_latch=1;pixel_step=0;
 @(negedge clk);frame_latch=0;n=0;
 while(n<307200)begin
  rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};pixel_step=rng[1:0]!=0;
  if(pixel_step)n=n+1;
  // Config inputs are deliberately changed mid-frame. Only the next latch may use them.
  if(n==200)begin page_index=5-pp;dual_enable=!dd;zoom=(zz+1)%3;focus=(ff+1)%6;end
  @(negedge clk);
 end
 pixel_step=0;repeat(4)@(negedge clk);frames=frames+1;
 if(checked!=accepted)$fatal(1,"lost requests");
end endtask
integer i;
initial begin
 repeat(4)@(negedge clk);rst=0;
 for(i=0;i<6;i=i+1)frame(i,0,0,0);
 for(i=0;i<6;i=i+1)frame(i,1,0,0);
 for(i=0;i<6;i=i+1)frame(i,i%2,1+i%2,i);
 // Consecutive no-bubble requests around the right/bottom viewport bounds.
 frame(4,1,2,5);
 $display("TEST_PASS exhibit_viewport %0d full640x480frames %0d exact_addresses bubbles atomic_frame_config pair_orientation zoom123focus_bounds",frames,checked);$finish;
end
initial begin #300000000;$fatal(1,"timeout");end
endmodule
