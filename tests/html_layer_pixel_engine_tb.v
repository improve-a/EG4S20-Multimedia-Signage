`timescale 1ns/1ps
`define HTML_SIM
module html_layer_pixel_engine_tb #(parameter CONTEXT_BITS=3,CACHE_SLOT_BITS=4,BG_SLOT_BITS=4,DESC_COUNT=44894,PIXEL_COUNT=54012,FIXTURE_ROOT="output/html_fidelity/page_control/layer_pixel_engine_v1");
reg clk=0;always#12.5 clk=~clk;reg rst=1,flush=0,iv=0,raw=0,refresh=0,writing=0;wire ir,logical_ready,logical_response,re,busy,fault,pr;
wire[20:0]ra;wire[31:0]pixel;wire[11:0]pa;reg[23:0]pd=0;
reg[115:0]descs[0:DESC_COUNT-1];reg[31:0]gold[0:PIXEL_COUNT-1];reg[31:0]memory[0:2097151];reg[23:0]palette[0:3071];
wire[2:0]page;wire[20:0]bg,a0,a1,da;wire[1:0]lane,rep,rc;wire[7:0]op0,op1;wire direct,is_packed,half,black;
integer sent=0,received=0,i,phase=0,base=0,cycles=0,writecount=0,groups=0;reg[31:0]rng=32'h39d713a5;
assign {page,bg,lane,rep,rc,a0,a1,op0,op1,direct,is_packed,half,black,da}=descs[sent];
reg[9:0]rv=0;reg[31:0]pipe[0:9];
html_layer_pixel_engine #(.CONTEXT_BITS(CONTEXT_BITS),.CACHE_SLOT_BITS(CACHE_SLOT_BITS),.BG_SLOT_BITS(BG_SLOT_BITS))dut(clk,rst,flush,iv,ir,page,bg,lane,rep,rc,a0,a1,op0,op1,direct,is_packed,half,black,da,pr,pa,pd,raw,logical_ready,logical_response,pixel,1'b1,refresh,writing,re,ra,rv[9],pipe[9],busy,fault);
always@(posedge clk)begin
 if(rst)begin rv<=0;refresh<=0;writing<=0;end
 else begin
  cycles=cycles+1;refresh<=cycles%312<20;
  for(i=9;i>0;i=i-1)pipe[i]<=pipe[i-1];rv<={rv[8:0],re};
  if(pr)pd<=palette[pa];
  if(re)begin
   if(writing)$fatal(1,"physicalreadwrite");
   if(phase==0)begin if(ra[1:0]!=0||refresh)$fatal(1,"groupalignmentrefresh");base=ra;groups=groups+1;end
   pipe[0]<=memory[base+phase];phase=(phase+1)%4;
  end else if(phase!=0)$fatal(1,"groupinterrupted");
  if(iv&&ir)sent=sent+1;
  if(logical_response)begin
   if(received>=PIXEL_COUNT||pixel!==gold[received])$fatal(1,"enginepixel%0d got%h expected%h head%0d state%0d",received,pixel,gold[received],dut.rp,dut.state[dut.crp]);received=received+1;
  end
  if(writing)begin writecount<=writecount+1;if(writecount==7)begin writing<=0;writecount<=0;end end
  else if(!busy&&rng[4:0]==0)writing<=1;
  #1;if(fault)$fatal(1,"enginefault contexts%0d wp%0d rp%0d",dut.fetch_count,dut.wp,dut.rp);
 end
end
always@(negedge clk)if(!rst)begin rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};iv=sent<DESC_COUNT;raw=rng[2:0]!=0;end
initial begin
 $readmemh({FIXTURE_ROOT,"/descriptors.hex"},descs);
 $readmemh({FIXTURE_ROOT,"/expected.hex"},gold);
 $readmemh({FIXTURE_ROOT,"/memory.hex"},memory);
 $readmemh("rtl/ext/html_assets/html_layer_palette.hex",palette);
 repeat(4)@(negedge clk);rst=0;
 wait(received==PIXEL_COUNT);wait(!busy);repeat(8)@(negedge clk);
 if(sent!=DESC_COUNT||phase!=0)$fatal(1,"enginedrain");
 $display("TEST_PASS html_layer_pixel_engine realHFXL6pages bboxtexels alphaopacity sourceover palette 1_2_3xrepeat is_packed4panels topfooter directRGB orderedphysical4groups refreshwrite backpressure records%0d pixels%0d groups%0d",sent,received,groups);$finish;
end
initial begin #40000000;$fatal(1,"timeout");end
endmodule
