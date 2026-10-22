`timescale 1ns/1ps
// Real WAV prefix and production audio clients. The sector transport is modeled
// at measured70sysclk/byte with explicit command/token/CRC clocks, not SD pins.
module no_bot_audio_load_tb;
 localparam FRAMES=4096,BYTE_CLOCKS=70,COMMAND_TOKEN_CLOCKS=634,CRC_CLOCKS=140;
 localparam MAX_SECTOR_CLOCKS=36620,GRANT_BOUND=2*(MAX_SECTOR_CLOCKS+16);
 reg sc=0,ac=0;always#5 sc=~sc;always#20 ac=~ac;
 reg rst=1,ar=1,enable=0,breq=0;reg[31:0]baddr=4096;
 wire areq,urgent,agrant,av,ae,ax,bv,be,bx,sdreq;wire[31:0]aaddr,sdaddr;wire[7:0]adata,bdata;
 reg[7:0]sddata=0;reg sdvalid=0,sdend=0,sderr=0;
 wire valid;wire[23:0]left,right;wire[15:0]peak;wire[3:0]status;wire uf,of,eof,err;wire[11:0]level;
 audio_media #(.LOOP_PLAY(0)) media(.sys_clk(sc),.rst(rst),.audio_clk(ac),.audio_rst(ar),.enable(enable),.paused(1'b0),.muted(1'b0),.restart(1'b0),.volume(4'd8),
 .sd_ready(1'b1),.sector_grant(agrant),.sector_data(adata),.sector_valid(av),.sector_end(ae),.sector_error(ax),.sector_req(areq),.sector_addr(aaddr),.sector_urgent(urgent),
 .audio_valid(valid),.audio_left(left),.audio_right(right),.status(status),.wave_peak(peak),.underflow(uf),.overflow(of),.eof(eof),.error(err),.fifo_level(level));
 media_sector_arbiter arb(.clk(sc),.rst(rst),.sd_ready(1'b1),.bmp_req(breq),.bmp_addr(baddr),.bmp_data(bdata),.bmp_valid(bv),.bmp_end(be),.bmp_error(bx),
 .audio_req(areq),.audio_addr(aaddr),.audio_urgent(urgent),.audio_grant(agrant),.audio_data(adata),.audio_valid(av),.audio_end(ae),.audio_error(ax),
 .sd_req(sdreq),.sd_addr(sdaddr),.sd_data(sddata),.sd_valid(sdvalid),.sd_end(sdend),.sd_error(sderr));
 reg[7:0]card[0:17919];reg[31:0]pcm[0:4095];
 reg[23:0]expected_l[0:4095],expected_r[0:4095];
 integer scan_checks=0;
 integer cycle=0,busy=0,delay_count=0,offset=0,base=0,started=0,max_sector=0,min_sector=999999;
 integer a_requests=0,a_sectors=0,b_sectors=0,sd_sectors=0,last_areq=-1,last_breq=-1,max_await=0,max_bwait=0;
 integer bbytes=0,bgap=0,last_bmp_end=0,max_bmp_gap=0,physical_audio=0,physical_bmp=0;
 reg[31:0]held_addr;reg served_audio=0,prev_sdreq=0,prev_breq=0,bmp_waiting=0;
 function[7:0]bmp_byte;input[31:0]lba;input integer n;begin bmp_byte=lba[7:0]^n[7:0]^8'ha5;end endfunction
 // Same70-clock spacing as the real existing SPI byte interface. The model
 // never preempts a sector, and its response owner follows its accepted LBA.
 always@(negedge sc)begin
  sdvalid=0;sdend=0;sderr=0;
  if(!rst)begin
   if(busy==0&&sdreq)begin
    held_addr=sdaddr;served_audio=sdaddr<4096;base=sdaddr*512;offset=0;busy=1;
    delay_count=COMMAND_TOKEN_CLOCKS+BYTE_CLOCKS-1;started=cycle;sd_sectors=sd_sectors+1;
    if(served_audio)begin if(sdaddr>34)$fatal(1,"WAV prefix bounds LBA%0d",sdaddr);physical_audio=physical_audio+1;end
    else physical_bmp=physical_bmp+1;
   end else if(busy==1)begin
    if(!sdreq||sdaddr!==held_addr)$fatal(1,"physical request changed during sector");
    if(delay_count>0)delay_count=delay_count-1;
    else if(offset<512)begin
     sdvalid=1;sddata=served_audio?card[base+offset]:bmp_byte(held_addr,offset);offset=offset+1;
     delay_count=offset==512?CRC_CLOCKS-1:BYTE_CLOCKS-1;
    end else begin
     sdend=1;busy=2;
     if(cycle-started>max_sector)max_sector=cycle-started;
     if(cycle-started<min_sector)min_sector=cycle-started;
    end
   end else if(busy==2&&!sdreq)busy=0;
  end
 end
 always@(posedge sc)if(!rst)begin
  cycle=cycle+1;
  if(media.state==3)begin
   if(media.scan_current_below_limit !== (media.current_sector<media.SCAN_MAX_SECTOR))
    $fatal(1,"stale actual-media scan comparison");
   scan_checks=scan_checks+1;
  end
  if(areq&&last_areq<0)last_areq=cycle;
  if(agrant)begin
   if(last_areq<0)$fatal(1,"audio grant without request");
   if(cycle-last_areq>max_await)max_await=cycle-last_areq;
   if(cycle-last_areq>GRANT_BOUND)$fatal(1,"audio grant bound%0d",cycle-last_areq);
   last_areq=-1;a_requests=a_requests+1;
  end
  if(breq&&!prev_breq)begin last_breq=cycle;bmp_waiting=1;end
  if(sdreq&&!prev_sdreq&&sdaddr>=4096)begin
   bmp_waiting=0;
   if(last_breq<0)$fatal(1,"BMP start without request");
   if(cycle-last_breq>max_bwait)max_bwait=cycle-last_breq;
   if(cycle-last_breq>GRANT_BOUND)$fatal(1,"BMP grant bound%0d",cycle-last_breq);
  end
  if(last_areq>=0&&cycle-last_areq>GRANT_BOUND)$fatal(1,"pending audio starved");
  if(bmp_waiting&&cycle-last_breq>GRANT_BOUND)$fatal(1,"pending BMP starved");
  prev_sdreq<=sdreq;prev_breq<=breq;
  if(bv)begin if(bdata!==bmp_byte(baddr,bbytes))$fatal(1,"BMP routed byte mismatch");bbytes=bbytes+1;end
  if(be)begin
   if(bbytes!=512)$fatal(1,"BMP byte count%0d",bbytes);
   bbytes=0;breq<=0;bgap=1;baddr<=baddr+1;b_sectors=b_sectors+1;
   if(last_bmp_end!=0&&cycle-last_bmp_end>max_bmp_gap)max_bmp_gap=cycle-last_bmp_end;last_bmp_end=cycle;
  end else if(bgap!=0)bgap=bgap-1;else breq<=1;
  if(ae)a_sectors=a_sectors+1;
  if(uf||of||err||ax||bx)$fatal(1,"audio flow fault UF%b OF%b ERR%b",uf,of,err);
 end
 integer popped=0,received=0,lv,rv,audio_cycle=0,last_valid=-1,delta,min_level=2047,max_level=0,valid_checks=0;
 time first_pcm_time=0;
 always@(posedge ac)if(!ar&&media.fifo_pop)begin
  if(popped>=FRAMES)$fatal(1,"too many PCM pops");
  lv=$signed(pcm[popped][31:16]);rv=$signed(pcm[popped][15:0]);
  expected_l[popped]=lv*256;expected_r[popped]=rv*256;popped=popped+1;
  if(first_pcm_time==0)first_pcm_time=$time;
 end
 always@(negedge ac)if(!ar)begin
  audio_cycle=audio_cycle+1;
  if(popped>0)begin if(level<min_level)min_level=level;if(level>max_level)max_level=level;end
  if(valid)begin
   if(last_valid>=0)begin delta=audio_cycle-last_valid;if(delta!=520&&delta!=521)$fatal(1,"48k cadence delta%0d",delta);valid_checks=valid_checks+1;end
   last_valid=audio_cycle;
   if(received<popped)begin
    if(left!==expected_l[received]||right!==expected_r[received])$fatal(1,"actual PCM%0d got%h/%h expected%h/%h",received,left,right,expected_l[received],expected_r[received]);
    received=received+1;
   end else if(left!==0||right!==0)$fatal(1,"nonzero outside accepted PCM");
  end
  if(received==FRAMES)begin
   if(scan_checks!=3||popped!=FRAMES||uf||of||err||eof||peak==0)$fatal(1,"final audio flags/counters");
   if(b_sectors<100||a_sectors<17||max_sector>MAX_SECTOR_CLOCKS||min_sector<36613)$fatal(1,"transport/fairness coverage");
   $display("TEST_PASS real_delivery_audio_load PCM4096_exact_including_leadingzeros 100MHz_25MHz PCM48k cadencechecks%0d noUF_OF_ERROR noEOFclaim scanCompareChecks%0d audioGrants%0d audioSectors%0d bmpSectors%0d maxAudioGrantWait%0d maxBMPGrantWait%0d maxBMPCompletionGap%0d sectorCycles%0d..%0d FIFO%0d..%0d peak%0d firstPCM_ns%0d lastPCM_ns%0d total_sys_cycles%0d",valid_checks,scan_checks,a_requests,a_sectors,b_sectors,max_await,max_bwait,max_bmp_gap,min_sector,max_sector,min_level,max_level,peak,first_pcm_time,$time,cycle);$finish;
  end
 end
 initial begin
  $readmemh("delivery_card.hex",card);$readmemh("delivery_pcm.hex",pcm);
  repeat(10)@(negedge sc);rst=0;ar=0;enable=1;
 end
 initial begin#110000000;$fatal(1,"audio load watchdog received%0d popped%0d sectors%0d/%0d",received,popped,a_sectors,b_sectors);end
endmodule
