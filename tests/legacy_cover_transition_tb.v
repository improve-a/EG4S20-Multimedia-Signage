`timescale 1ns/1ps
// Accelerated frame-state unit: each frame contains one real640pixel line.
// Production12/18 counts and exactpixels, not production bandwidth or preview.
module legacy_cover_transition_tb;
 reg clk=0;always#5 clk=~clk;
 reg rst=1,hs=0,vs=0,de=0,enable=1,frame_start=0,candidate=0,ack=0,cover_req=0,fault=0;
 reg[1:0]mode=1;reg[23:0]src=0;wire cover_ack,forwarded,oh,ov,od,busy;wire[23:0]rgb;
 video_transition #(.COVER_BEFORE_LOAD(1),.CLOSE_STEP(54),.OPEN_STEP(36),.MASK_COLOR(24'h151615))dut(.clk(clk),.rst(rst),.i_hs(hs),.i_vs(vs),.i_de(de),.i_rgb(src),.enable(enable),.mode(mode),.frame_start(frame_start),.candidate_toggle_async(candidate),.commit_ack_toggle(ack),.display_fault_async(fault),.cover_request_toggle_async(cover_req),.cover_ack_toggle(cover_ack),.forwarded_commit_toggle(forwarded),.o_hs(oh),.o_vs(ov),.o_de(od),.o_rgb(rgb),.transition_busy(busy));
 integer x,k,pass,checks=0,frames=0,wanted_offset;reg[23:0]base=24'h650000,expected;reg recognized;
 task step;begin @(posedge clk);#1;if({oh,ov,od}!=={hs,vs,de})$fatal(1,"coverunit oneclock sync");checks=checks+1;@(negedge clk);end endtask
 task idle;input integer count;begin de=0;repeat(count)step;end endtask
 task boundary;begin de=0;frame_start=1;step;frame_start=0;vs=1;step;vs=0;step;frames=frames+1;end endtask
 task line;input integer offset,slide;begin
  for(x=0;x<640;x=x+1)begin
   de=1;src=base+x;expected=x<offset?24'h151615:base+x-(slide?offset:0);
   @(posedge clk);#1;if(rgb!==expected||{oh,ov,od}!=={hs,vs,de})$fatal(1,"coverunit pixel frame%0d x%0d phase%0d offset%0d got%h expected%h",frames,x,dut.phase,offset,rgb,expected);checks=checks+1;@(negedge clk);
  end
  de=0;step;
 end endtask
 initial begin
  idle(5);rst=0;idle(5);
  for(pass=0;pass<2;pass=pass+1)begin
   if(pass==0)begin cover_req=1;mode=1;idle(5);end
   else begin wait(dut.phase==1);mode=1;end // queuedrequest captured prior mode2
   if(dut.phase!=1||dut.offset!=0)$fatal(1,"missing queued/startcover");
   for(k=1;k<=12;k=k+1)begin
    boundary;wanted_offset=k*54;if(wanted_offset>640)wanted_offset=640;
    if(dut.offset!=wanted_offset||cover_ack!==(k==12?cover_req:!cover_req))$fatal(1,"12framefullcover/ACKcount");
    if(forwarded!==ack)$fatal(1,"candidate published beforeload");line(wanted_offset,pass);
   end
   if(dut.phase!=4)$fatal(1,"fullcover must WAIT_LOAD");
   repeat(3)begin boundary;line(640,pass);if(dut.phase!=4||dut.offset!=640||forwarded!==ack)$fatal(1,"loadwait must remaincovered");end
   candidate=~candidate;idle(5);
   if(forwarded!==candidate||dut.phase!=2)$fatal(1,"completedload candidate notforwarded");
   repeat(3)begin boundary;line(640,pass);if(dut.phase!=2||dut.offset!=640)$fatal(1,"opened before actualmatchingACK");end
   ack=candidate;base=base+24'h010000;idle(3);
   boundary;line(640,pass);if(dut.phase!=2||!dut.reveal_armed||dut.offset!=640)$fatal(1,"firstpostACKframe mustarmstaycovered");
   for(k=1;k<=18;k=k+1)begin
    boundary;wanted_offset=640-k*36;if(wanted_offset<0)wanted_offset=0;
    if(dut.offset!=wanted_offset)$fatal(1,"18framerevealcount got%0d expected%0d",dut.offset,wanted_offset);
    if(pass==0&&k==3)begin mode=2;cover_req=0;end // hold onequeuedrequest throughoutOPEN
    line(wanted_offset,pass);
    if(k<18&&dut.phase!=3)$fatal(1,"reveal didnotfinish18frames");
   end
   if(pass==0)begin idle(5);if(cover_ack!=1||dut.phase!=1)$fatal(1,"queued cover acceptedearly/lost");end
   else if(busy||dut.phase!=0)$fatal(1,"final reveal stillbusy");
  end
  // Fault before ACK, after first covered ACK-frame, and late ACK near boundary.
  for(pass=0;pass<3;pass=pass+1)begin
   rst=1;step;cover_req=0;candidate=0;ack=0;fault=0;rst=0;idle(5);cover_req=1;mode=1;idle(5);
   repeat(12)boundary;candidate=1;idle(5);
   if(dut.phase!=2||dut.offset!=640)$fatal(1,"faultsetup notWAITACK");
   if(pass==0)begin fault=1;idle(4);ack=1;end
   if(pass==1)begin ack=1;idle(3);boundary;line(640,0);fault=1;idle(4);end
   if(pass==2)begin
    // ACK one clock after boundary: no early arm/open; next full boundary arms.
    boundary;ack=1;idle(3);if(dut.reveal_armed)$fatal(1,"lateACK armedwithoutboundary");
    boundary;line(640,0);if(!dut.reveal_armed||dut.phase!=2)$fatal(1,"lateACKfirstframe notcovered");
    boundary;line(604,0);if(dut.phase!=3)$fatal(1,"lateACKsecondboundary didnotOPEN");
    fault=1;idle(4);
   end
   repeat(3)begin boundary;line(640,0);if(dut.phase!=2||dut.offset!=640||dut.reveal_armed)$fatal(1,"stickyFIFO faultallowedreveal");end
  end
  // Active unmasked pixel at fault recognition: no one-pixel leakage from old IDLE.
  rst=1;step;cover_req=0;candidate=0;ack=0;fault=0;rst=0;idle(5);cover_req=1;idle(5);
  repeat(12)boundary;candidate=1;idle(5);ack=1;idle(3);boundary;repeat(18)boundary;
  if(dut.phase!=0||dut.offset!=0)$fatal(1,"recognitionpixel setup notIDLE");
  de=1;src=24'habcdef;fault=1;
  repeat(8)begin
   @(posedge clk);recognized=dut.display_fault_sync[1];#1;
   if(recognized && rgb!==24'h151615)$fatal(1,"fault recognition leaked oldphase pixel%h",rgb);
   if(!recognized && rgb!==src)$fatal(1,"prefaultpixel unexpected");
   @(negedge clk);
  end
  de=0;rst=1;step;
  if(cover_ack||forwarded||{oh,ov,od,rgb}!==0)$fatal(1,"coverreset");
  $display("TEST_PASS legacyCOVER1 production12close_18open,WAIT_LOADmask,delayedACKmask,queuedcoverafterreveal,lockedwipe_thenactualslide,640pixelrows,RBGsync,reset postACKcoveredqualification,faultBeforeACK_faultAfterACK_faultDuringOPEN_lateACK checks%0d shortframes%0d NOTproductioncadence",checks,frames);$finish;
 end
 initial begin #4000000;$fatal(1,"coverunitwatchdog phase%0d",dut.phase);end
endmodule
