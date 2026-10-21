`define HTML_SIM
`timescale 1ns/1ps
module html_layer_cache_tb #(parameter CACHE_SLOT_BITS=5);
reg clk=0;always#12.5 clk=~clk;reg rst=1,flush=0,valid=0,ready=0,refresh=0,writing=0;
reg[20:0]addr=0;reg[11:0]tag=0;
wire accept,ov,re,busy,fault;wire[31:0]data;wire[11:0]ot;wire[20:0]ra;
reg[9:0]rv=0;reg[31:0]pipe[0:9];
html_layer_cache #(.CACHE_SLOT_BITS(CACHE_SLOT_BITS)) dut(clk,rst,flush,valid,addr,tag,accept,ov,ready,data,ot,1'b1,refresh,writing,re,ra,rv[9],pipe[9],busy,fault,1'b0,);
reg[31:0]expected[0:8191];reg[11:0]tags[0:8191];integer sent=0,received=0,phase=0,base=0,i,groups=0,held=0,writecount=0;
reg[31:0]rng=32'h27a94df1;reg injected=0;
function[31:0]word;input integer a;begin word=32'hb39a2701^(a*32'd257);end endfunction
always@(posedge clk)begin
 if(rst)begin rv<=0;refresh<=0;writing<=0;end
 else begin
  for(i=9;i>0;i=i-1)pipe[i]<=pipe[i-1];rv<={rv[8:0],re};
  if(!injected&&dut.take_job&&!dut.issue_active)begin injected<=1;refresh<=1;held<=0;end
  else if(refresh)begin held<=held+1;if(held==19)refresh<=0;end
  if(writing)begin writecount<=writecount+1;if(writecount==7)begin writing<=0;writecount<=0;end end
  else if(!busy&&rng[3:0]==0)writing<=1;
  if(re)begin
   if(writing)$fatal(1,"readwritecollision");
   if(phase==0)begin if(ra[1:0]!=0||refresh)$fatal(1,"firstgroup");base=ra;groups=groups+1;end
   pipe[0]<=word(base+phase);phase=(phase+1)%4;
  end else if(phase!=0)$fatal(1,"broken4beatgroup");
  if(valid&&accept)begin expected[sent]=word(addr);tags[sent]=tag;sent=sent+1;end
  if(ov&&ready)begin
   if(received>=sent||data!==expected[received]||ot!==tags[received])$fatal(1,"cachetaskorder/data at%0d",received);
   received=received+1;
  end
  #1;if(fault)$fatal(1,"cachefault");
 end
end
integer n;
task batch;input integer start,stop;
begin
 n=start;
 while(n<stop)begin
  @(negedge clk);rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
  valid=rng[2:0]!=0;ready=rng[3:2]!=0;tag=n;
  case((n/256)%4)
   0:addr=(n%1536)*7+307200;
   1:addr=(n%1536)/2+614400;
   2:addr=(n%1536)/3+921600;
   default:addr=((n*19)%524288)+1228800;
  endcase
  @(posedge clk);if(valid&&accept)n=n+1;
 end
 @(negedge clk);valid=0;ready=1;wait(received==stop);wait(!busy);repeat(2)@(negedge clk);
end endtask
initial begin
 repeat(4)@(negedge clk);rst=0;
 batch(0,4096);flush=1;@(negedge clk);flush=0;batch(4096,8192);
 if(!injected||phase!=0)$fatal(1,"coverage");
 $display("TEST_PASS html_layer_cache8192taggedwordtasks parameterizedslots fourbeatalignedIP cachehitsmisses arbitrarybackpressure evictionrefcounts frameflush refreshwritearbitration groups%0d",groups);$finish;
end
initial begin #10000000;$fatal(1,"timeout");end
endmodule
