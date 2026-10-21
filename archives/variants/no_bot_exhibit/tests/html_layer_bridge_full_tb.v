`timescale 1ns/1ps
`define HTML_SIM
module html_layer_bridge_full_tb #(parameter PAGE=0,CONTEXT_BITS=3,CACHE_SLOT_BITS=4,BG_SLOT_BITS=4,DESC_COUNT=307200,DIVISOR=1,COMPARE=0,CASE_NAME="home",FIXTURE_ROOT="output/html_fidelity/page_control/layer_engine_full_v1");
reg clk=0;always#12.5 clk=~clk;reg rst=1,iv=0,raw=0,refresh=0;wire ir,lr,lv,re,busy,fault,pr;wire[20:0]ra;wire[31:0]pixel;wire[11:0]pa;reg[23:0]pd=0;
reg[115:0]descs[0:307199];reg[31:0]gold[0:307199],memory[0:2097151],fifo[0:511];reg[23:0]palette[0:3071];
wire[2:0]page;wire[20:0]bg,a0,a1,da;wire[1:0]lane,rep,rc;wire[7:0]op0,op1;wire direct,is_packed,half,black;
integer sent=0,consumed=0,produced=0,i,phase=0,base=0,cycles=0,groups=0,used=0,wp=0,rp=0,x=0,y=0,phaseacc=0,lowwater=512,critical=512,burst=0,drain=0,rdstate=0;reg pop;
integer rowfile,tasks=0,physical=0,lasttasks=0,lastphysical=0,lastproduced=0,rowmin=512,maxtasks=0,maxphysical=0;
assign {page,bg,lane,rep,rc,a0,a1,op0,op1,direct,is_packed,half,black,da}=descs[sent];
reg[9:0]rv=0;reg[31:0]pipe[0:9];
reg ack=0;
wire[4:0]view={1'b0,COMPARE!=0,PAGE[2:0]};wire[1:0]zoom=DIVISOR-1;
html_layer_memory_bridge #(.CACHE_SLOT_BITS(CACHE_SLOT_BITS),.CONTEXT_BITS(CONTEXT_BITS),.BG_SLOT_BITS(BG_SLOT_BITS))dut(.mem_clk(clk),.rst(rst),.video_read_req(1'b0),.read_accept_mem(ack),.active_view(view),.zoom(zoom),.transition_mode(2'd0),.focus(3'd1),
 .panels_ready(1'b1),.layer_resources_enabled(1'b1),.write_busy_mem(1'b0),.mem_ready(1'b1),.refresh_active(refresh),.raw_read_en(raw),.read_en(re),.read_addr(ra),.response(rv[9]),.memory_data(pipe[9]),
 .pixel_data(pixel),.logical_ready(lr),.logical_response(lv),.busy(busy),.fault(fault));
always@(posedge clk)begin
 if(rst)begin rv<=0;refresh<=0;end else begin
  cycles=cycles+1;refresh<=cycles%312<20;
  if(dut.engine.task_accept)tasks=tasks+1;if(re)physical=physical+1;if(used<rowmin)rowmin=used;
  for(i=9;i>0;i=i-1)pipe[i]<=pipe[i-1];rv<={rv[8:0],re};if(pr)pd<=palette[pa];
  if(re)begin if(phase==0)begin if(ra[1:0]!=0||refresh)$fatal(1,"groupalignmentrefresh");base=ra;groups=groups+1;end pipe[0]<=memory[base+phase];phase=(phase+1)%4;end else if(phase!=0)$fatal(1,"groupinterrupted");

  pop=0;
  if(cycles>=5000)begin phaseacc=phaseacc+5;if(phaseacc>=8)begin
   phaseacc=phaseacc-8;
   if(x<640&&y<480)begin
    if(used==0)$fatal(1,"ENGINE_UNDERFLOW page%0d ctx%0d cache%0d bg%0d y%0d x%0d produced%0d sent%0d",PAGE,1<<CONTEXT_BITS,1<<CACHE_SLOT_BITS,1<<BG_SLOT_BITS,y,x,produced,sent);
    if(fifo[rp]!==gold[consumed])$fatal(1,"videopixel%0d got%h expected%h",consumed,fifo[rp],gold[consumed]);
    if(consumed>512&&consumed<306688&&used<lowwater)lowwater=used;if(y>=50&&y<=380&&used<critical)critical=used;
    rp=(rp+1)%512;consumed=consumed+1;pop=1;
   end
   if(x==799)begin
    $fdisplay(rowfile,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",y,tasks-lasttasks,physical-lastphysical,produced-lastproduced,used,rowmin,dut.engine.fetch_count,dut.engine.compute_count);$fflush(rowfile);
    if(tasks-lasttasks>maxtasks)maxtasks=tasks-lasttasks;if(physical-lastphysical>maxphysical)maxphysical=physical-lastphysical;
    lasttasks=tasks;lastphysical=physical;lastproduced=produced;rowmin=used;x=0;y=y+1;
   end else x=x+1;
  end end
  if(lv)begin if(used==512&&!pop)$fatal(1,"FIFOoverflow");fifo[wp]<=pixel;wp=(wp+1)%512;produced=produced+1;end
  case({lv,pop})2'b10:used=used+1;2'b01:used=used-1;endcase
  // Mirror the actual controller's256-word admission and13-cycle drain.
  if(rdstate==0)begin if(used<256)begin rdstate=1;burst=0;end end
  else if(rdstate==1&&lv)begin burst=burst+1;if(burst==256)begin rdstate=2;drain=0;end end
  else if(rdstate==2)begin drain=drain+1;if(drain==13)rdstate=0;end
  #1;if(fault)$fatal(1,"enginefault");
  if(consumed==307200)begin
   if(dut.issued!=307200||produced!=307200||phase!=0)$fatal(1,"fullcounts");
   $display("TEST_PASS html_layer_bridge_full static_motion_age127_hook actual_mapper_spanfrontend page%0d contexts%0d cache%0d bg%0d pixels307200 actualRGBApalette exactsourceover 25MHz40MHz20of312refresh FIFO512 burst256drain13 interiorlowwater%0d critical%0d physicalgroups%0d maxtasksperline%0d maxphysicalperline%0d",PAGE,1<<CONTEXT_BITS,1<<CACHE_SLOT_BITS,1<<BG_SLOT_BITS,lowwater,critical,groups,maxtasks,maxphysical);$fclose(rowfile);$finish;
  end
 end
end
always@(negedge clk)if(!rst)begin raw=rdstate==1&&cycles>10;end
initial begin
 rowfile=$fopen({FIXTURE_ROOT,"/",CASE_NAME,"_rows.csv"},"w");
 $fdisplay(rowfile,"row,tasks,physical_beats,produced,fifo_level,fifo_min,fetch_pending,compute_pending");
 $readmemh({FIXTURE_ROOT,"/",CASE_NAME,"_descriptors.hex"},descs,0,DESC_COUNT-1);
 $readmemh({FIXTURE_ROOT,"/",CASE_NAME,"_gold.hex"},gold);
 $readmemh({FIXTURE_ROOT,"/memory.hex"},memory);$readmemh("rtl/ext/html_assets/html_layer_palette.hex",palette);
 force dut.geometry.motion.frame_age=7'd127;
 repeat(4)@(negedge clk);rst=0;repeat(6)@(negedge clk);ack=1;@(negedge clk);ack=0;
end
initial begin #25000000;$fatal(1,"timeout");end
endmodule
