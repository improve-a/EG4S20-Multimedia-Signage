`timescale 1ns/1ps
module sector_arbiter_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,ready=0,breq=0,areq=0,urgent=0;
 reg [31:0] ba=100,aa=200;
 wire [7:0] bd,ad;wire bv,be,ber,av,ae,aer,grant,req;wire[31:0]addr;
 reg[7:0]data=0;reg valid=0,done=0,error=0;
 media_sector_arbiter dut(clk,rst,ready,breq,ba,bd,bv,be,ber,areq,aa,urgent,grant,ad,av,ae,aer,req,addr,data,valid,done,error);
 integer busy=0,idx=0,bbytes=0,abytes=0,bcnt=0,acnt=0,total=0,streak=0,wait_b=0;
 reg [31:0] saved_addr;
 reg inject=0;
 // Realistic level-request reader: latch once, return 512 bytes, end once.
 always @(negedge clk)begin
  if(rst)begin busy=0;valid=0;done=0;error=0;idx=0;end
  else begin
   valid=0;done=0;error=0;
   if(busy==0&&req)begin
    saved_addr=addr;busy=1;idx=0;total=total+1;
    if(addr>=200)begin streak=streak+1;if(breq&&streak>2)$fatal(1,"BMP starved");end
    else streak=0;
   end else if(busy==1)begin
    if(addr!==saved_addr||!req)$fatal(1,"in-flight request/address changed");
    data=saved_addr+idx;valid=1;idx=idx+1;
    if(idx==512)busy=2;
   end else if(busy==2)begin done=1;error=inject&&(saved_addr==103);busy=3;end
   else if(busy==3&&!req)busy=0;
  end
 end
 always @(posedge clk)begin
  if(!rst)begin
   if(bv&&av || be&&ae || ber&&aer)$fatal(1,"response leaked to both owners");
   if(grant)areq<=0;
   if(bv)begin if(bd!==((ba+bbytes)&255))$fatal(1,"BMP order");bbytes=bbytes+1;end
   if(av)begin if(ad!==((aa+abytes)&255))$fatal(1,"audio order");abytes=abytes+1;end
   if(be)begin
    if(bbytes!=512)$fatal(1,"BMP length");
    if(ber!==(inject&&(ba==103)))$fatal(1,"error routing BMP");
    bbytes=0;bcnt=bcnt+1;breq<=0;ba<=ba+1;
   end else if(!breq&&bcnt<8) breq<=1;
   if(ae)begin
    if(abytes!=512||aer)$fatal(1,"audio length/error");
    abytes=0;acnt=acnt+1;aa<=aa+1;
    if(acnt<8)areq<=1;
   end
  end
 end
 initial begin
  repeat(5)@(negedge clk);rst=0;areq=1;breq=1;urgent=1;inject=1;
  repeat(20)@(negedge clk);
  if(req||grant||total)$fatal(1,"request before init");
  ready=1;
  wait(bcnt==8&&acnt==8);repeat(15)@(negedge clk);
  if(total!=16||req)$fatal(1,"duplicate transaction");
  if(bv||av||be||ae)$fatal(1,"response while idle");
  $display("TEST_PASS sector_arbiter 16 sectors 8192 bytes ownership bounded_fairness held_req errors init_guard");$finish;
 end
 initial begin #200000;$fatal(1,"timeout");end
endmodule
