`timescale 1ns/1ps
// Real HFXL trailers, real RIFF/PCM client, real shared sector arbiter.
module html_scene_real_tb #(parameter SET_ID=32'h003adc1b,parameter FOCUSED_PAGE0=0);
reg clk=0,aclk=0;always #5 clk=~clk;always #20 aclk=~aclk;
reg rst=1,enable=0,sd_ready=0,sv=0,se=0;reg[7:0]sd=0;
wire req,valid,ending,serr,sreq;wire[31:0]addr,saddr;wire[7:0]data;
wire active,ready,error,wreq,we;wire[5:0]page_ready;wire[31:0]wd;wire[20:0]base,len;
reg ack=0,finish=0;
// Production wrapper registers the entire resource response tuple together.
reg[7:0] client_data=0;reg client_valid=0,client_end=0,client_error=0;
always @(posedge clk)begin
 if(rst)begin client_data<=0;client_valid<=0;client_end<=0;client_error<=0;end
 else begin client_data<=data;client_valid<=valid;client_end<=ending;client_error<=serr;end
end
html_scene_loader #(.TIMEOUT_CYCLES(200000),.SET_ID(SET_ID)) dut(.clk(clk),.rst(rst),.enable(enable),
.sector0(32'd10000),.sector1(32'd20000),.sector2(32'd30000),.sector3(32'd40000),.sector4(32'd50000),.sector5(32'd60000),
.active(active),.ready(ready),.error(error),.page_ready(page_ready),.sector_req(req),.sector_addr(addr),.sector_data(client_data),.sector_valid(client_valid),.sector_end(client_end),.sector_error(client_error),.write_req(wreq),.write_req_ack(ack),.write_en(we),.write_data(wd),.write_base(base),.write_len(len),.write_finish_toggle(finish));
wire ar,au,ag,av,ae,ax;wire[31:0]aa;wire[7:0]ad;
media_sector_arbiter arb(.clk(clk),.rst(rst),.sd_ready(sd_ready),.bmp_req(req),.bmp_addr(addr),.bmp_data(data),.bmp_valid(valid),.bmp_end(ending),.bmp_error(serr),.audio_req(ar),.audio_addr(aa),.audio_urgent(au),.audio_grant(ag),.audio_data(ad),.audio_valid(av),.audio_end(ae),.audio_error(ax),.sd_req(sreq),.sd_addr(saddr),.sd_data(sd),.sd_valid(sv),.sd_end(se),.sd_error(1'b0));
reg restart=0;wire pcm_valid,uf,of,eof,aerror;wire[23:0]left,right;wire[3:0]status;wire[15:0]peak;wire[9:0]level;
audio_media #(.FIFO_ADDRESS_BITS(9),.PREFILL_FRAMES(128),.SCAN_MAX_SECTOR(5)) audio(
clk,rst,aclk,rst,enable,1'b0,1'b0,restart,4'd8,sd_ready,ag,ad,av,ae,ax,ar,aa,au,pcm_valid,left,right,status,peak,uf,of,eof,aerror,level);
reg[7:0]headers[0:3071],payload[0:7215103],card[0:3071];reg[31:0]gold[0:1803775],pcm[0:299];
integer bases[0:5],lens[0:5],offsets[0:5];
integer seed=981247,words=0,page=0,local_words=0,completed=0,ackwait=-1,tail=0,finish_wait=-1;
integer scenes=0,audios=0,urgent_grants=0,bytes=0,sector_index=0,p=0,k=0,b=0,g=0,idx=0,busy=0,cool=0,cycles=0;
integer pops=0,received=0,total_pcm=0,restarts=0;reg eof_seen=0;reg[31:0]locked;reg old_sreq=0;reg pending=0;reg[31:0]pending_address;
function integer rnd(input integer n);integer r;begin r=$random(seed)&32'h7fffffff;rnd=r%n;end endfunction
always @(posedge aclk)if(!rst&&audio.fifo_pop)begin
 if(pops>=300)$fatal(1,"WAV overconsumed");pops=pops+1;
end
always @(negedge aclk)if(!rst&&pcm_valid)begin
 if(received<pops)begin
  if(left!=={pcm[received][31:16],8'd0}||right!=={pcm[received][15:0],8'd0})$fatal(1,"real PCM frame mismatch %0d",received);
  received=received+1;total_pcm=total_pcm+1;
 end else if(left!==0||right!==0)$fatal(1,"unexpected PCM outside stream");
end
always @(negedge clk)begin
 restart=0;sv=0;se=0;
 if(!rst)begin
  cycles=cycles+1;
  if(eof&&!eof_seen&&!ready)begin
   if(received!=300||pops!=300)$fatal(1,"WAV restart before complete output");
   restart=1;eof_seen=1;restarts=restarts+1;pops=0;received=0;
  end
  if(!eof)eof_seen=0;
  if(uf||of||aerror)$fatal(1,"audio flow error UF%0d OF%0d err%0d",uf,of,aerror);
  if(wreq)begin
   if(base!==bases[page]||len!==lens[page])$fatal(1,"metadata changed page%0d",page);
   if(ackwait<0)ackwait=51+rnd(301);
   else if(ackwait==0)begin ack=1;tail=7+rnd(23);ackwait=-2;end
   else ackwait=ackwait-1;
  end else if(ack)begin tail=tail-1;if(tail==0)begin ack=0;ackwait=-1;end end
  if(finish_wait>0)finish_wait=finish_wait-1;
  else if(finish_wait==0)begin #2;finish=~finish;completed=completed+1;$display("PAGE_PHYSICAL_FINISH page%0d checked_words%0d scene_sectors%0d PCMframes%0d",completed-1,words,scenes,total_pcm);finish_wait=-1;end
  if(page_ready&~((1<<completed)-1))$fatal(1,"page_ready before delayed physical finish");
  if(!sreq&&busy==2)begin busy=0;cool=0;end
  if(busy==0)begin
   if(cool>0)begin cool=cool-1;sd_ready=0;end else sd_ready=1;
   if(sreq)begin
    locked=saddr;busy=1;b=0;g=3;sd_ready=0;
    if(saddr<6)begin audios=audios+1;if(au)urgent_grants=urgent_grants+1;end
    else begin
     p=saddr/10000-1;if(p<0||p>5)$fatal(1,"bad scene origin");
     sector_index=saddr-(p+1)*10000;
     if(sector_index!=0&&(sector_index<offsets[p]||sector_index>=offsets[p]+lens[p]/128))$fatal(1,"read main BMP instead of trailer LBA%0d",saddr);
     if(sector_index!=0&&ack)$fatal(1,"payload read before ACK released");
     scenes=scenes+1;
     if((scenes%1024)==0)$display("TRANSFER_PROGRESS scene_sectors%0d words%0d page%0d cycle%0d",scenes,words,page,cycles);
    end
   end
  end
  if(busy==1)begin
   if(!sreq||saddr!==locked)$fatal(1,"physical request not stable");
   if(g>0)g=g-1;
   else begin
    if(locked<6)sd=card[locked*512+b];
    else if(sector_index==0)sd=headers[p*512+b];
    else begin idx=bases[p]*4+(sector_index-offsets[p])*512+b;sd=payload[idx];end
    sv=1;bytes=bytes+1;b=b+1;g=0; // Keep bytes contiguous; request/ACK timing remains randomized.
    if(b==512)begin se=1;busy=2;end
   end
  end
 end
end
always @(posedge clk)if(!rst)begin
 if(pending&&!client_end&&(!req||addr!==pending_address))$fatal(1,"logical request/address changed before routed sector end");
 if(req&&!pending)begin pending=1;pending_address=addr;end
 if(client_end)pending=0;
 if(error)$fatal(1,"scene loader error at page%0d words%0d",page,words);
 if(we)begin
  if(ack)$fatal(1,"write while ACK clears FIFO");
  if(words>=1803776||wd!==gold[words])$fatal(1,"payload mismatch globalword%0d got%x expected%x",words,wd,gold[words]);
  if(base+local_words!==words)$fatal(1,"global address overlap/hole");
  words=words+1;local_words=local_words+1;
  if(cycles>12000000)$fatal(1,"cycle watchdog cycles%0d words%0d scene_sectors%0d page%0d local_words%0d arbiter_busy%0d request%0d valid%0d end%0d",cycles,words,scenes,page,local_words,busy,sreq,sv,se);
  if(local_words==lens[page])begin
   $display("PAGE_WORDS_COMPLETE page%0d words%0d scene_sectors%0d audio_sectors%0d cycles%0d",page,words+1,scenes,audios,cycles);
   finish_wait=271+rnd(431);local_words=0;page=page+1;
  end
 end
end
initial begin
 $readmemh("headers.hex",headers);$readmemh("payload_bytes.hex",payload);$readmemh("payload_words.hex",gold);
 $readmemh("audio_card.hex",card);$readmemh("pcm.hex",pcm);$readmemh("bases.hex",bases);$readmemh("lengths.hex",lens);$readmemh("offsets.hex",offsets);
 repeat(10)@(negedge clk);rst=0;enable=1;cool=300;
 if(FOCUSED_PAGE0)begin
  wait(page_ready[0]);repeat(10)@(negedge clk);
  if(words!=lens[0]||completed!=1||page_ready[0]!==1'b1)$fatal(1,"focused page0 incomplete words%0d expected%0d completed%0d",words,lens[0],completed);
  $display("FOCUSED_PASS page0 words%0d scene_sectors%0d audio_sectors%0d cycles%0d",words,scenes,audios,cycles);$finish;
 end else begin
  wait(ready);repeat(10)@(negedge clk);
  if(words!=1803776||page!=6||completed!=6||page_ready!=63||scenes!=14098||audios<20||urgent_grants==0||total_pcm<300)$fatal(1,"incomplete words%0d scene_sectors%0d audio%0d urgent%0d PCM%0d",words,scenes,audios,urgent_grants,total_pcm);
  $display("TEST_PASS real scenes6 bytes7215104 words%0d scene_sectors%0d audio_sectors%0d urgent_grants%0d PCMframes%0d restarts%0d cycles%0d",words,scenes,audios,urgent_grants,total_pcm,restarts,cycles);$finish;
 end
end
initial begin #1000000000;$fatal(1,"global timeout");end
endmodule
