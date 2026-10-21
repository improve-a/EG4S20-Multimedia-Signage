`timescale 1ns/1ps
module timing_head_prefetch_tb;
 reg clk=0;always #12.5 clk=~clk;
 reg rst=1,flush=0,push=0,ready=0;reg[59:0]data=0;
 wire nv,ov,np,op;wire[59:0]nh,oh;wire[3:0]nq,oq;wire[2:0]nw,nr,ow,orr;
 queue_after a(clk,rst,flush,push,ready,data,nv,nh,np,nq,nw,nr);
 queue_before b(clk,rst,flush,push,ready,data,ov,oh,op,oq,ow,orr);
 reg[59:0]gold[0:7];integer gw=0,gr=0,gcount=0,checks=0,popped=0,pushed=0,stalls=0,sole_replace=0,wraps=0,flushes=0,resets=0;
 reg[59:0]held;reg held_valid=0;reg sampled_pop;integer n;reg[31:0]rng=32'h13579bdf;
 always @(posedge clk)begin
  if(nv!==ov||np!==op||nq!==oq||nw!==ow||nr!==orr)$fatal(1,"cycle control mismatch");
  if(nv&&nh!==oh)$fatal(1,"head differs from original asynchronoushead");
  if(!rst&&!flush)begin
   if(nq!==gcount)$fatal(1,"gold occupancy mismatch");
   if(nv&&nh!==gold[gr])$fatal(1,"tag/geometryword ordering or coherence mismatch");
   if(held_valid&&nh!==held)$fatal(1,"stalledhead changed");
   if(nv&&!ready)stalls=stalls+1;
   if(nq==1&&push&&np)sole_replace=sole_replace+1;
   if(np)begin if(nr==7)wraps=wraps+1;gr=(gr+1)%8;gcount=gcount-1;popped=popped+1;end
   if(push)begin if(gcount>=8)$fatal(1,"test overflow");gold[gw]=data;gw=(gw+1)%8;gcount=gcount+1;pushed=pushed+1;end
  end else begin
   gw=0;gr=0;gcount=0;
   if(rst)resets=resets+1;else flushes=flushes+1;
  end
  held_valid=nv&&!ready&&!rst&&!flush;held=nh;
  #0.001;
  if(nv!==ov||np!==op||nq!==oq||nw!==ow||nr!==orr)$fatal(1,"postedgecontrol mismatch");
  if(nv&&nh!==oh)$fatal(1,"postedgehead mismatch");
  if(nq!==gcount)$fatal(1,"postedgeoccupancy mismatch");
  if(nv&&nh!==gold[gr])$fatal(1,"postedgehead golden mismatch");
  checks=checks+1;
 end
 task step(input p,input r,input f,input reset);
 begin @(negedge clk);push=p;ready=r;flush=f;rst=reset;data=data+60'h0123456789abcdf;end endtask
 initial begin
  repeat(3)step(0,0,0,1);step(1,0,0,0);repeat(10)step(0,0,0,0);
  repeat(30)step(1,1,0,0);step(0,1,0,0);step(0,0,0,0);
  repeat(8)step(1,0,0,0);repeat(50)step(0,0,0,0);repeat(8)step(0,1,0,0);
  repeat(5)step(1,0,0,0);step(1,1,1,0);step(1,0,0,0);
  for(n=0;n<20000;n=n+1)begin
   @(negedge clk);rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
   rst=n%331==0;flush=n%257==0;ready=rng[1]||rng[2];
   push=(rng[3]||rng[5])&&(nq<8||(nv&&ready));data={rng,~rng[27:0]};
  end
  step(0,0,1,0);step(0,0,0,0);@(negedge clk);
  if(checks<20000||sole_replace<30||wraps<100||stalls<100||flushes<20||resets<20)$fatal(1,"coverage insufficient");
  $display("TEST_PASS timing_head_prefetch checks=%0d pushes=%0d pops=%0d sole_pop_push=%0d wraps=%0d stalls=%0d flushes=%0d resets=%0d",checks,pushed,popped,sole_replace,wraps,stalls,flushes,resets);$finish;
 end
 initial begin #1000000;$fatal(1,"watchdog");end
endmodule
