`timescale 1ns/1ps
`define HTML_SIM
module html_layer_geometry_tb #(parameter CASE_COUNT=720,FIXTURE_ROOT="output/html_fidelity/page_control/span4_candidate_v1");
reg clk=0;always#12.5 clk=~clk;reg rst=1,flush=0,iv=0,oldflag=0,ready=1;wire ir,ov,fault;
reg[2:0]cur,prev;reg[6:0]age;reg reverse;reg[8:0]row;reg[9:0]x;wire[2:0]page=oldflag?prev:cur;
wire[20:0]bg,a0,a1,da;wire[1:0]lane,rep,count;wire[7:0]op0,op1;wire direct,packedflag,half,black;
reg[23:0]cases[0:CASE_COUNT-1];reg[59:0]expected[0:CASE_COUNT*1280-1];integer c,old,i,ticks=0,index=0;
wire[2:0]page_unused;
html_layer_span_frontend dut(clk,rst,flush,1'b1,1'b0,reverse,cur,prev,1'b1,10'd0,row,iv,ir,page,oldflag,1'b0,x,x,row,2'd1,21'd0,1'b0,1'b0,1'b0,
 ov,ready,page_unused,bg,lane,rep,count,a0,a1,op0,op1,direct,packedflag,half,black,da,fault);
always@(posedge clk)if(!rst)begin ticks=ticks+1;#1;if(fault)$fatal(1,"frontendfault case%0d cur%0d old%0d age%0d row%0d",c,cur,prev,age,row);end
initial begin
 $readmemh({FIXTURE_ROOT,"/cases.hex"},cases);$readmemh({FIXTURE_ROOT,"/gold.hex"},expected);
 repeat(4)@(negedge clk);rst=0;
 for(c=0;c<CASE_COUNT;c=c+1)begin
  @(negedge clk);{cur,prev,age,reverse,row}=cases[c][22:0];iv=0;flush=1;
  force dut.motion.frame_age=age;force dut.motion.reverse_l=reverse;
  @(negedge clk);flush=0;
  wait(dut.prepared[0]);
  for(old=0;old<2;old=old+1)begin
   i=0;
   while(i<640)begin
    @(negedge clk);iv=1;oldflag=old;x=i;ready=ticks%7!=0;
    @(posedge clk);
    if(ov&&ready)begin
     if({count,a0,a1,op0,op1}!==expected[index])$fatal(1,"geometry case%0d pixel%0d cur%0d old%0d oldflag%0d age%0d dir%0d row%0d x%0d got%h expected%h",c,index,cur,prev,oldflag,age,reverse,row,x,{count,a0,a1,op0,op1},expected[index]);
     index=index+1;i=i+1;
    end
   end
  end
  @(negedge clk);iv=0;release dut.motion.frame_age;release dut.motion.reverse_l;
 end
 $display("TEST_PASS html_layer_geometry all30orderedpagepairs bothdirections ages0_16_25_66_92_93 sixcriticalrows fixed4new4old spans exactaddressesalpha sourceinverse64b backpressure cases%0d pixels%0d",c,index);$finish;
end
initial begin #200000000;$fatal(1,"timeout");end
endmodule
