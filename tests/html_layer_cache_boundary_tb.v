`define HTML_SIM
`timescale 1ns/1ps
// Positive drain/reset replay and intentional protocol violations. Faults are
// checked, never suppressed. Reset aborts both cache and physical-response model.
module html_layer_cache_boundary_tb;
reg clk=0;always#12.5 clk=~clk;
reg rst=1,flush=0,valid=0,ready=1,refresh=0,writing=0,inject=0;
reg[20:0]addr=0;reg[7:0]tag=0;
wire accept,ov,re,busy,fault;wire[31:0]data;wire[7:0]ot;wire[20:0]ra;
reg[9:0]rv=0;reg[31:0]pipe[0:9];integer i,phase=0,base=0,received=0,sent=0,groups=0;
reg[31:0]expected[0:255];reg[7:0]tags[0:255];reg check_data=1;
function[31:0]word;input integer a;begin word=32'h8739ab21^(a*32'd479);end endfunction
html_layer_cache #(.TAG_BITS(8),.CACHE_SLOT_BITS(3))dut(clk,rst,flush,valid,addr,tag,accept,ov,ready,data,ot,1'b1,refresh,writing,re,ra,rv[9]|inject,pipe[9],busy,fault,1'b0,);
always@(posedge clk)begin
 if(rst)begin rv<=0;phase=0;end else begin
  for(i=9;i>0;i=i-1)pipe[i]<=pipe[i-1];rv<={rv[8:0],re};
  if(re)begin if(phase==0)begin if(ra[1:0]!=0||refresh||writing)$fatal(1,"badgroupstart");base=ra;groups=groups+1;end pipe[0]<=word(base+phase);phase=(phase+1)%4;end
  if(valid&&accept&&check_data)begin expected[sent]=word(addr);tags[sent]=tag;sent=sent+1;end
  if(ov&&ready&&check_data)begin if(received>=sent||data!==expected[received]||ot!==tags[received])$fatal(1,"order%0d",received);received=received+1;end
 end
end
task reset_clean;begin
 @(negedge clk);rst=1;valid=0;flush=0;inject=0;check_data=0;
 repeat(4)@(negedge clk);rst=0;phase=0;sent=0;received=0;check_data=1;
 #1;if(fault||busy)$fatal(1,"resetnotclean");
end endtask
task request;input integer a;input[7:0]t;begin
 @(negedge clk);addr=a;tag=t;valid=1;
 @(posedge clk);while(!accept)@(posedge clk);
 @(negedge clk);valid=0;
end endtask
task completed;input integer count;begin
 wait(received==count);wait(!busy);repeat(3)@(negedge clk);
 if(fault||phase!=0)$fatal(1,"legaldrainfault");
end endtask
initial begin
 reset_clean;
 request(21'd16403,8'h11);completed(1);
 // Legal frame flush immediately after all physical and logical work drains.
 flush=1;@(negedge clk);flush=0;request(21'd16403,8'h12);completed(2);
 // Flush during pending physical returns is illegal and sticky-diagnosed.
 request(21'd45213,8'h22);wait(re&&dut.issue_phase==3);@(negedge clk);check_data=0;flush=1;
 @(negedge clk);flush=0;#1;if(!fault)$fatal(1,"busyflushnotdiagnosed");
 repeat(15)@(negedge clk);if(!fault)$fatal(1,"faultnotsticky");
 reset_clean;request(21'd99123,8'h33);completed(1);
 // Idle unsolicited memory response must be rejected.
 inject=1;@(negedge clk);inject=0;#1;if(!fault)$fatal(1,"unsolicitednotdiagnosed");
 reset_clean;
 // Common controller reset can abort a group; response model resets with it.
 request(21'd19635,8'h44);wait(re&&dut.issue_phase==1);reset_clean;
 request(21'd64999,8'h55);completed(1);
 // Refresh at first issue phase must hold the entire group until released.
 request(21'd72317,8'h66);wait(dut.issue_active&&dut.issue_phase==0);@(negedge clk);refresh=1;
 repeat(20)begin @(negedge clk);if(re)$fatal(1,"refreshfirstbeat");end
 refresh=0;completed(2);
 $display("TEST_PASS html_layer_cache_boundary legaldrainflush busyflushsticky unsolicitedresponse commonresetmidgroup replay refresh20 firstbeat slots8 groups%0d",groups);$finish;
end
initial begin #1000000;$fatal(1,"timeout");end
endmodule
