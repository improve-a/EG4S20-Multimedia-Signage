`timescale 1ns/1ps
module html_group_aperture_tb;
parameter FRAME_COUNT=768;
reg mc=0,vc=0;always#12.5 mc=~mc;always#20 vc=~vc;
reg rst=1,rawreq=0,toggle=0;reg[4:0]candidate=1;reg[20:0]length=FRAME_COUNT;
reg[1:0]zoom=0,transition=0;reg[2:0]focus=0;
wire rawack,mreq,mack,rdack,raw,physical,finish,readbusy,clear,fault,logical_ready,logical_response,bridge_busy;
wire[4:0]view;wire[20:0]rawaddr,addr;wire[31:0]pixel;
reg[1:0]ack_sync=0;
always@(posedge vc)if(rst)ack_sync<=0;else ack_sync<={ack_sync[0],rdack};
assign mack=ack_sync[1];
display_commit #(.BUFFER_BITS(5))commit(vc,rst,rawreq,rawack,mreq,mack,toggle,candidate,1'b0,view,acktoggle);
reg refresh=0,writing=0;reg[9:0]used=0;
reg[9:0]rv=0;reg[31:0]mempipe[0:9];
wire[31:0]memory_data=mempipe[9];wire response=rv[9];
frame_fifo_read #(.BURST_SIZE(256),.READ_DRAIN_CYCLES(13),.ENABLE_SOURCE_READY(1))reader(
.source_ready(logical_ready),.source_busy(bridge_busy),.rst(rst),.mem_clk(mc),.Sdr_init_done(1'b1),.Sdr_init_ref_vld(refresh),.Sdr_busy(refresh),
.Sdr_rd_en(logical_response),.App_wr_busy(writing),.O_rd_busy(readbusy),.App_rd_en(raw),.App_rd_addr(rawaddr),
.read_req(mreq),.read_req_ack(rdack),.read_finish(finish),.read_addr_0(21'd0),.read_addr_1(21'd0),
.read_addr_2(21'd0),.read_addr_3(21'd0),.read_addr_index(2'd0),.read_len(length),.fifo_aclr(clear),.wrusedw(used));
html_memory_bridge bridge(.mem_clk(mc),.rst(rst),.video_read_req(mreq),.read_accept_mem(rdack),
.active_view(view),.zoom(zoom),.transition_mode(transition),.focus(focus),.panels_ready(1'b1),
.write_busy_mem(writing),.mem_ready(1'b1),.refresh_active(refresh),.logical_ready(logical_ready),.logical_response(logical_response),.busy(bridge_busy),
.raw_read_en(raw),.read_en(physical),.read_addr(addr),.response(response),.memory_data(memory_data),.pixel_data(pixel),.fault(fault));
integer test_width=640,test_old=0,test_reverse=0,coverage=0,golden[0:63];reg aperture_test=0,negative=0;
integer cycles=0,frame_start_cycle=0,physical_count=0,logical_count=0,total=0,groups=0,frames=0,i;
integer x=0,y=0,modelpage=1,modeldual=0,z=1,fx=0,cx=0,cy=0,panx=0,pany=0,mx,my,p,expectedaddr;
integer phase=0,base=0,modeladdr=0,refresh_count=0,write_count=0,writes=0;
reg[31:0]expectedword;reg[15:0]c565;reg[31:0]expectedpixel;
reg injected=0;reg[31:0]rng=32'h8720d819;
function[31:0]memory_word;input integer a;begin memory_word={16'hf800^a[15:0],16'h07e0^a[15:0]};end endfunction
function[23:0]expand;input[15:0]c;begin expand={{c[15:11],c[15:13]},{c[10:5],c[10:9]},{c[4:0],c[4:2]}};end endfunction
always@(negedge mc)if(!rst)begin rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};used=rng[4:0]==0?10'd400:10'd0;end
always@(posedge mc)begin
 cycles=cycles+1;
 if(rst)begin rv<=0;refresh<=0;writing<=0;phase=0;end
 else begin
  if(bridge.frame_latch)begin
   frame_start_cycle=cycles;x=0;y=0;logical_count=0;physical_count=0;
   modelpage=view[2:0];modeldual=view[3];z=zoom+1;fx=focus;
   case(fx)
    0:begin cx=modelpage==0?435:448;cy=modelpage==0?192:173;end
    1:begin cx=320;cy=240;end
    2:begin cx=160;cy=240;end
    3:begin cx=480;cy=240;end
    4:begin cx=320;cy=120;end
    default:begin cx=320;cy=360;end
   endcase
   panx=cx*z-320;if(panx<0)panx=0;if(panx>640*(z-1))panx=640*(z-1);
   pany=cy*z-240;if(pany<0)pany=0;if(pany>480*(z-1))pany=480*(z-1);
  end
  // Adversarial first-beat refresh: starts after the scheduler reserved its
  // first group, before the physical IP sees its first enable.
  if(!injected && bridge.take_job && !bridge.issue_active)begin refresh<=1;injected<=1;refresh_count<=0;end
  else if(refresh)begin refresh_count<=refresh_count+1;if(refresh_count==19)refresh<=0;end
  else if(!bridge.busy && !readbusy && rng[10:0]==0)begin refresh<=1;refresh_count<=0;end
  if(writing)begin if(write_count==7)begin writing<=0;write_count<=0;end else write_count<=write_count+1;end
  else if(!bridge.busy && !readbusy && !refresh && rng[4:0]==0)begin writing<=1;write_count<=0;writes=writes+1;end
  for(i=9;i>0;i=i-1)mempipe[i]<=mempipe[i-1];rv<={rv[8:0],physical};
  if(physical)begin
   if(writing)$fatal(1,"physical read/writecollision");
   if(phase==0)begin
    if(addr[1:0]!=0 || refresh)$fatal(1,"unaligned/refreshgroupfirst");
    base=addr;groups=groups+1;
   end
   // The IP ignores the supplied address on beats1..3.
   modeladdr=base+phase;mempipe[0]<=memory_word(modeladdr);
   phase=(phase+1)%4;physical_count=physical_count+1;
  end else if(phase!=0)$fatal(1,"physicalgroupnotfourcontinuousbeats");
  if(raw!==logical_response)$fatal(1,"logicalrequestlost");
  if(logical_response)begin
   mx=(x+panx)/z;my=(y+pany)/z;p=modelpage;
   if(aperture_test && (test_reverse ? mx>=test_width : mx<640-test_width))p=test_old;
   if(modeldual)begin
    case(p)1:p=mx>=320?2:1;2:p=mx>=320?1:2;3:p=mx>=320?4:3;4:p=mx>=320?3:4;default:p=mx>=320?2:1;endcase
    if(my<384)expectedaddr=1843200+(p-1)*62464+my*160+(mx%320)/2;
    else expectedaddr=1843200+(p-1)*62464+61440+((my-384)/4)*40+(mx%320)/8;
   end else expectedaddr=p*307200+my*640+mx;
   expectedword=memory_word(expectedaddr);expectedpixel=expectedword;
   if(modeldual)begin c565=(my<384?(mx%2):((mx/4)%2))?expectedword[31:16]:expectedword[15:0];expectedpixel={expand(c565),8'd0};end
   if(pixel!==expectedpixel)begin $display("TRACE view%0d mapperpage%0d oldpage%0d apactive%b width%0d dir%b slot%0d srctag%0d offset%0d ref%0d",view,bridge.mapper.page_l,bridge.mapper.old_page,bridge.mapper.aperture_active,bridge.mapper.aperture_width,bridge.mapper.reverse_l,bridge.head_slot,bridge.cache_tag[bridge.head_slot],bridge.head[1:0],bridge.references[bridge.head_slot]);$fatal(1,"logicalRGB got%h expected%h logical%0d sourceaddr%0d",pixel,expectedpixel,logical_count,expectedaddr);end
   logical_count=logical_count+1;total=total+1;
   if(x==639)begin x=0;y=y+1;end else x=x+1;
  end
  #1;if(fault&&!negative)$fatal(1,"cachefault queued%0d jobs%0d outstanding%0d returns%0d",bridge.queued,bridge.jobs_count,bridge.outstanding,bridge.return_count);
 end
end
task frame;input[4:0]nextview;input[1:0]zz;input[2:0]ff;
begin
 @(negedge vc);candidate=nextview;zoom=zz;focus=ff;toggle=~toggle;repeat(4)@(negedge vc);rawreq=1;
 wait(rawack);if(view!==nextview)$fatal(1,"candidate_not_committed");@(negedge vc);rawreq=0;wait(finish);wait(!bridge_busy);repeat(5)@(negedge mc);
 if(logical_count!=length)$fatal(1,"logicalcount%0d expected%0d",logical_count,length);
 if(length==307200 && (bridge.issued!=307200 || bridge.outstanding!=0 || bridge.queued!=0))$fatal(1,"fullframeoverfetch");
 if(length==307200 && !nextview[3] && zz==0 && physical_count!=307200)$fatal(1,"normalphysicalbandwidth%0d",physical_count);
 if(nextview[3] && physical_count>=length)$fatal(1,"packedbandwidthnotreduced%0d",physical_count);

 frames=frames+1;
end endtask
integer n;
initial begin
 golden[0]=0;
 golden[1]=0;
 golden[2]=0;
 golden[3]=1;
 golden[4]=2;
 golden[5]=3;
 golden[6]=4;
 golden[7]=5;
 golden[8]=7;
 golden[9]=9;
 golden[10]=12;
 golden[11]=15;
 golden[12]=18;
 golden[13]=22;
 golden[14]=26;
 golden[15]=31;
 golden[16]=36;
 golden[17]=42;
 golden[18]=49;
 golden[19]=56;
 golden[20]=65;
 golden[21]=75;
 golden[22]=86;
 golden[23]=98;
 golden[24]=113;
 golden[25]=129;
 golden[26]=149;
 golden[27]=172;
 golden[28]=199;
 golden[29]=231;
 golden[30]=268;
 golden[31]=309;
 golden[32]=352;
 golden[33]=391;
 golden[34]=426;
 golden[35]=455;
 golden[36]=480;
 golden[37]=501;
 golden[38]=519;
 golden[39]=535;
 golden[40]=548;
 golden[41]=560;
 golden[42]=570;
 golden[43]=580;
 golden[44]=588;
 golden[45]=595;
 golden[46]=601;
 golden[47]=607;
 golden[48]=612;
 golden[49]=616;
 golden[50]=620;
 golden[51]=624;
 golden[52]=627;
 golden[53]=630;
 golden[54]=632;
 golden[55]=634;
 golden[56]=635;
 golden[57]=637;
 golden[58]=638;
 golden[59]=639;
 golden[60]=639;
 golden[61]=640;
 golden[62]=640;
 golden[63]=640;
 repeat(5)@(negedge mc);rst=0;
 frame(5'b00010,0,0);
 transition=1;aperture_test=1;test_old=2;test_reverse=0;
 for(n=0;n<64;n=n+1)begin test_width=golden[n];coverage=coverage|(1<<((640-test_width)%4));frame(5'b00001,0,0);end
 test_old=1;test_reverse=1;
 for(n=0;n<64;n=n+1)begin test_width=golden[n];frame(5'b10000,0,0);end
 if(coverage!=15)$fatal(1,"aperturealignmentcoverage%h",coverage);
 // A new frame arrives during an old logical256pixelburst. ActualACK must
 // wait for all outstandingphysicalreturns before flushing speculativeentries.
 aperture_test=0;transition=0;
 @(negedge vc);candidate=3;toggle=~toggle;repeat(4)@(negedge vc);rawreq=1;
 wait(rawack);@(negedge vc);rawreq=0;
 wait(logical_count>=128);wait(!rawack);
 @(negedge vc);candidate=4;toggle=~toggle;repeat(4)@(negedge vc);rawreq=1;
 wait(rawack);@(negedge vc);rawreq=0;
 wait(finish);wait(!bridge_busy);repeat(5)@(negedge mc);
 if(modelpage!=4 || logical_count!=768)$fatal(1,"rapidframeflush");
 negative=1;force bridge.response=1'b1;@(negedge mc);release bridge.response;repeat(2)@(negedge mc);
 if(!fault)$fatal(1,"unsolicitedphysicalresponsenotdiagnosed");
 $display("TEST_PASS html_group_aperture logical%0d all4cutoffalignments forwardreverse oldnewAPUG011groups rapidframecommit safeACKflush stickyunsolicitedresponsefault",total);$finish;
end
initial begin #100000000;$fatal(1,"timeout");end
endmodule
