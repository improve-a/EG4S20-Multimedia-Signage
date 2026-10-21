`timescale 1ns/1ps
module native_case #(parameter FIRST=35392)(input clk,rst,
 output [44:0] signature,output reg [31:0] writes,reads,blocked_writes,blocked_reads,
 output reg [31:0] drops,output reg signed [31:0] occupancy,max_occupancy);
 initial begin writes=0;reads=0;blocked_writes=0;blocked_reads=0;drops=0;occupancy=0;max_occupancy=0;end
 integer tick=0,h=0,y=0,rel; reg sof=0,sol=0,rd=0,was_locked=0;
 wire valid,user,locked,pause,fifo_rst,wgo,rgo;wire [9:0] wa,ra;
 always @*rel=(tick-FIRST)%420000;
 assign valid=tick>=FIRST && rel/800<480 && rel%800<640;
 assign user=tick>=FIRST && rel==0;
 mapped_receiver_control dut(clk,rst,user,valid,sof,sol,rd,locked,pause,fifo_rst,wgo,rgo,wa,ra);
 assign signature={h[9:0],y[9:0],locked,pause,fifo_rst,wgo,rgo,wa,ra};
 always @(posedge clk)begin
  if(rst)begin tick<=0;h<=0;y<=0;sof<=0;sol<=0;rd<=0;was_locked<=0;end
  else begin
   tick<=tick+1;
   sof<=h==150&&y==45;sol<=h==160&&y>=45;rd<=h>=160&&y>=45;
   if(h==15)y<=y==524?0:y+1;
   if(!pause)h<=h==799?0:h+1;
   was_locked<=locked;
   if(was_locked&&!locked)drops<=drops+1;
   if(fifo_rst)occupancy<=0;
   else begin
    if(valid&&!wgo)blocked_writes<=blocked_writes+1;
    if(rd&&!rgo)blocked_reads<=blocked_reads+1;
    if(wgo)writes<=writes+1;
    if(rgo)reads<=reads+1;
    occupancy<=occupancy+wgo-rgo;
    if(occupancy+wgo-rgo>max_occupancy)max_occupancy<=occupancy+wgo-rgo;
   end
  end
 end
endmodule
module tb;
 reg clk=0,rst=1;always #20 clk=~clk;
 wire [44:0] a,b;wire[31:0] aw,ar,abw,abr,ad,bw,br,bbw,bbr,bd;
 wire signed[31:0] ao,am,bo,bm;
 native_case #(.FIRST(35390)) old_case(clk,rst,a,aw,ar,abw,abr,ad,ao,am);
 native_case #(.FIRST(35392)) new_case(clk,rst,b,bw,br,bbw,bbr,bd,bo,bm);
 reg[44:0] delay1=0,delay2=0;integer count=0,mismatch=0;
 // Negative control intentionally fills the exact extracted FIFO control.
 wire nl,np,nfr,nwg,nrg;wire[9:0]nwa,nra;
 integer negative_writes=0,negative_blocked=0;
 mapped_receiver_control negative(clk,rst,count==12,count>=12,count==10,1'b0,1'b0,nl,np,nfr,nwg,nrg,nwa,nra);
 always @(posedge clk)if(!rst&&!nfr)begin
  if(nwg)negative_writes<=negative_writes+1;
  if(count>=12&&!nwg)negative_blocked<=negative_blocked+1;
 end
 always @(negedge clk)begin
  if(!rst)begin
   count=count+1;
   if(count==36000)begin $display("CHECKPOINT count=%0d old_lock=%b new_lock=%b",count,old_case.locked,new_case.locked);$fflush();end
   if(count>20 && ((^a===1'bx)||(^b===1'bx)))$fatal(1,"Unknown receiver control state");
   if(count>35400&&b!==delay2)begin
    mismatch=mismatch+1;if(mismatch<4)$display("MISMATCH t=%0d olddelay=%h new=%h",count,delay2,b);
   end
   delay2=delay1;delay1=a;
  end
 end
 initial begin
  repeat(10)@(negedge clk);rst=0;
  repeat(40000)@(negedge clk);
  $display("OLD writes=%0d reads=%0d blocked_writes=%0d blocked_reads=%0d drops=%0d max_occupancy=%0d",aw,ar,abw,abr,ad,am);
  $display("NEW writes=%0d reads=%0d blocked_writes=%0d blocked_reads=%0d drops=%0d max_occupancy=%0d",bw,br,bbw,bbr,bd,bm);
  $display("NEGATIVE writes_before_full=%0d blocked=%0d",negative_writes,negative_blocked);
  $display("PHASE_COMPARE mismatches=%0d",mismatch);
  if(mismatch||abw||bbw||ad||bd||negative_blocked==0)$fatal(1,"RECEIVER_CONE_FAIL");
  $display("MAPPED_RECEIVER_FIFO_CONTROL_PASS");$finish;
 end
endmodule
