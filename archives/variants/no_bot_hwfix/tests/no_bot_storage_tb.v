`timescale 1ns/1ps
// Authored interface contract only. Abstract busy is intentionally independent
// of memory data/valid; no vendor cone, chip timing, or tRC is modeled.
// mem_ready is Sdr_init_done: high after init until reset, not beat backpressure.
// Results have an independent address-to-word scoreboard; duplicate returns
// may exceed logical work but must never modify cache payload.
module no_bot_storage_tb;
 parameter HANDSHAKE=1,LATENCY=11,VARIABLE=0,TAIL=16,BUSY_RACE=0,REFRESH_RACE=0,RESET_MID=0,SATURATION=0,STALLS=0;
 reg clk=0;always #12.5 clk=~clk;
 reg rst=1,flush=0,iv=0,ready_out=1,refresh=0,writing=0,pause=0,mem_busy=0,foreign_busy=0;
 reg[20:0]ia=0;reg[11:0]it=0;wire ir,ov,re,busy,fault,physical;wire[20:0]ra;wire[31:0]od;wire[11:0]ot;
 reg response=0;reg[31:0]md=0;
 html_layer_cache #(.TAG_BITS(12),.CACHE_SLOT_BITS(3),.ENABLE_PHYSICAL_FAIRNESS(1),.ENABLE_STREAM_HANDSHAKE(HANDSHAKE))dut(
  .clk(clk),.rst(rst),.flush(flush),.request_valid(iv),.request_addr(ia),.request_tag(it),.request_ready(ir),.result_valid(ov),.result_ready(ready_out),.result_data(od),.result_tag(ot),
  .mem_ready(1'b1),.refresh_active(refresh),.write_busy_mem(writing),.read_en(re),.read_addr(ra),.response(response),.memory_data(md),.busy(busy),.fault(fault),.pause_new_groups(pause),.physical_busy(physical),.mem_busy(mem_busy));
 reg sv[0:20000];reg[31:0]sd[0:20000],expected[0:255];reg[11:0]tags[0:255];
 integer cycle=0,sent=0,got=0,commands=0,returns=0,phase=0,base=0,last_due=0,due,delay,i,j;
 integer assert_due=1000000,busy_until=0,firsts=0,continuous=0,tail_checks=0,race_blocks=0,handoffs=0,refresh_blocks=0;
 reg previous_re=0,stream_known=0,any_read=0,race_done=0,refresh_done=0;
 integer discard_groups=0,discard_returns=0,max_groups=0,real_groups=0,max_idle=0,ring_wraps=0,result_stalls=0,return_gaps=0,discard_addr=0;
 reg [31:0] discard_before;reg check_discard;
 function[31:0]word;input[20:0]a;begin word=32'ha5c39e17^(32'h1<<a[4:0])^{a[15:0],a[20:5]};end endfunction
 always@(posedge clk)begin
  if(rst)begin
   cycle=0;sent=0;got=0;commands=0;returns=0;phase=0;last_due=0;assert_due=1000000;busy_until=0;previous_re=0;stream_known=0;any_read=0;firsts=0;continuous=0;tail_checks=0;race_blocks=0;handoffs=0;refresh_blocks=0;
   discard_groups=0;discard_returns=0;max_groups=0;real_groups=0;max_idle=0;ring_wraps=0;result_stalls=0;return_gaps=0;
   for(i=0;i<20001;i=i+1)begin sv[i]=0;sd[i]=0;end
  end else begin
   cycle=cycle+1;
   if(iv&&ir)begin expected[sent]=word(ia);tags[sent]=it;sent=sent+1;end
   if(re)begin
    if(writing)$fatal(1,"read/write overlap");
    if(!previous_re)begin
     if(mem_busy)$fatal(1,"UNSAFE_RESTART cycle%0d addr%0d pending%0d",cycle,ra,commands-returns);
     firsts=firsts+1;assert_due=cycle+3;stream_known=1;
    end else if(phase==0)continuous=continuous+1;
    if(phase==0)begin base=ra;if(ra[1:0]!=0||refresh)$fatal(1,"quad start qualification");end
    if(ra!==base+phase)$fatal(1,"quad address order");
    phase=(phase+1)%4;any_read=1;busy_until=cycle+TAIL+1;
    delay=LATENCY;if(VARIABLE)case(commands%4)0:delay=6;1:delay=10;2:delay=11;3:delay=32;endcase
    due=cycle+delay;if(due<=last_due)due=last_due+1;last_due=due;sv[due]=1;sd[due]=word(ra);commands=commands+1;
   end
   if(response)returns=returns+1;
   if(HANDSHAKE&&any_read&&mem_busy&&!dut.issue_active&&dut.return_count==0)begin
    tail_checks=tail_checks+1;if(!physical)$fatal(1,"read tail ownership released before busy low");
   end
   if(foreign_busy&&dut.issue_active&&dut.issue_phase==0)begin race_blocks=race_blocks+1;if(HANDSHAKE&&re)$fatal(1,"phase0 busy race");end
   if(refresh&&dut.issue_active&&dut.issue_phase==0)begin refresh_blocks=refresh_blocks+1;if(re)$fatal(1,"refresh group gate");end
   if(ov&&ready_out)begin
    if(got>=sent||ot!==tags[got]||od!==expected[got])$fatal(1,"data/order index%0d",got);
    got=got+1;
   end
   if(fault)$fatal(1,"cache fault");previous_re=re;
   if(ov&&!ready_out)result_stalls=result_stalls+1;
   if(commands!=returns&&!response)return_gaps=return_gaps+1;
   if(dut.return_groups_count>max_groups)max_groups=dut.return_groups_count;
   if(dut.group_push&&dut.twp==7)ring_wraps=ring_wraps+1;
   check_discard=0;
`ifndef NO_BOT_ORIGINAL_POLICY
   if(dut.group_push)begin
    if(dut.issue_discard)discard_groups=discard_groups+1;else real_groups=real_groups+1;
   end
   if(dut.idle_groups>max_idle)max_idle=dut.idle_groups;
   if(dut.idle_groups>8)$fatal(1,"duplicate group budget exceeded");
   if(response&&dut.return_head_valid&&dut.return_discard[dut.trp])begin
    discard_returns=discard_returns+1;check_discard=1;
    discard_addr=dut.returning;discard_before=dut.cache_data[discard_addr];
   end
`endif
   #1;if(check_discard&&dut.cache_data[discard_addr]!==discard_before)$fatal(1,"discard response wrote cache");
  end
 end
 always@(negedge clk)begin
  if(rst)begin response=0;md=0;mem_busy=0;end
  else begin response=sv[cycle+1];md=sd[cycle+1];mem_busy=foreign_busy||(stream_known&&cycle+1>=assert_due&&cycle+1<busy_until);ready_out=STALLS?(cycle%37>=19):((cycle%9)!=2);end
 end
 task req;input integer a;input integer t;begin
  @(negedge clk);ia=a;it=t;iv=1;@(posedge clk);while(!ir)@(posedge clk);@(negedge clk);iv=0;
 end endtask
 task idle;begin wait(!busy&&got==sent);wait(!mem_busy);repeat(3)@(negedge clk);end endtask
 initial begin
  repeat(5)@(negedge clk);rst=0;
  if(RESET_MID)begin req(4096,255);wait(re&&dut.issue_phase==2);@(negedge clk);rst=1;iv=0;repeat(3)@(negedge clk);rst=0;end
  req(0,0);req(1024,1);idle;
  flush=1;@(negedge clk);flush=0;req(1024,2);req(0,3);idle;
  req(2048,4);wait(re&&dut.issue_phase==3);@(negedge clk);req(1040,5);idle;
  pause=1;wait(!physical);if(mem_busy)$fatal(1,"writer granted before read tail idle");writing=1;handoffs=handoffs+1;
  repeat(6)@(negedge clk);writing=0;pause=0;
  refresh=1;req(3072,6);repeat(5)@(negedge clk);refresh=0;
  for(j=7;j<71;j=j+1)begin req(4*(j%16)+((j%3)==0?1024:0),j);if(j%5==0)repeat(3)@(negedge clk);end
  idle;
  if(commands!=returns||got!=71||continuous==0||firsts<3||((TAIL>(VARIABLE?32:LATENCY))&&tail_checks==0)||handoffs==0||(BUSY_RACE&&race_blocks==0)||(REFRESH_RACE&&refresh_blocks==0))$fatal(1,"coverage commands%0d returns%0d results%0d continuous%0d firsts%0d tail%0d",commands,returns,got,continuous,firsts,tail_checks);
`ifndef NO_BOT_ORIGINAL_POLICY
  if(HANDSHAKE&&(discard_groups==0||discard_returns!=discard_groups*4||max_idle==0||(!(SATURATION||VARIABLE)&&max_idle!=8)))$fatal(1,"discard coverage groups%0d returns%0d maxidle%0d",discard_groups,discard_returns,max_idle);
`endif
  if(SATURATION&&(max_groups!=8||ring_wraps==0))$fatal(1,"slot saturation coverage maxgroups%0d ringwraps%0d",max_groups,ring_wraps);
  if(STALLS&&(result_stalls==0||return_gaps==0))$fatal(1,"stall coverage");
  $display("DISCARD_STATS groups%0d returns%0d realgroups%0d maxidle%0d maxgroups%0d ringwraps%0d resultstalls%0d returngaps%0d",discard_groups,discard_returns,real_groups,max_idle,max_groups,ring_wraps,result_stalls,return_gaps);
  $display("TEST_PASS no_bot_storage latency%0d variable%0d tail%0d requests%0d results%0d commands%0d returns%0d newstreams%0d continuous_quads%0d tail_checks%0d race_blocks%0d refresh_blocks%0d handoffs%0d",LATENCY,VARIABLE,TAIL,sent,got,commands,returns,firsts,continuous,tail_checks,race_blocks,refresh_blocks,handoffs);$finish;
 end
 initial begin
  if(BUSY_RACE)begin
   wait(!rst);@(posedge clk);while(!(dut.take_job&&!dut.issue_active))@(posedge clk);
   @(negedge clk);foreign_busy=1;repeat(7)@(negedge clk);foreign_busy=0;race_done=1;
  end
 end
 initial begin
  if(REFRESH_RACE)begin
   wait(!rst);@(posedge clk);while(!(dut.take_job&&dut.issue_active&&dut.issue_phase==3))@(posedge clk);
   @(negedge clk);refresh=1;repeat(8)@(negedge clk);refresh=0;refresh_done=1;
  end
 end
 initial begin#2000000;$fatal(1,"timeout sent%0d got%0d",sent,got);end
endmodule
