`timescale 1ns/1ps
// Real pixel timing/read FIFO/controller/address mapper/video/OSD/Bot path.
// Only the encrypted SDRAM physical core is replaced by an ordered bounded-
// latency user-interface model. No HDMI PHY, SD-card, board or timing signoff.
module html_display_chain_tb;
 reg mem_clk=0,video_clk=0;
 always #12.5 mem_clk=~mem_clk; // inherited40MHz user memory clock
 always #20 video_clk=~video_clk; // inherited25MHz =>59.5238095Hz
 reg rst=1,fault_reset=0;
 wire memory_rst=rst|fault_reset;
 reg refresh=0;
 reg [4:0] active_view=0;
 reg [1:0] zoom=0,transition_mode=0;
 reg [2:0] focus=0;
 reg allow_requests=1,display_valid=0;
 reg page_event=0,commit_pending=1;
 wire signed [1:0] direction=active_view[4]?-2'sd1:2'sd1;
 wire timing_req,timing_ack,read_accept,read_finish;
 wire hs,vs,de,read_enable,raw_read_enable,mapped_read_enable;
 wire [20:0] raw_addr,mapped_addr;
 wire [31:0] fifo_data,mapped_response;
 wire fifo_fault,map_fault,logical_ready,logical_response,bridge_busy,write_busy_mem;
 wire write_cmd;wire [20:0] write_addr;wire [31:0] write_data;wire [3:0] write_mask;
 reg [31:0] memory[0:2093055];
 // Ordered SDRAM model. Only first address of each4-beat group is honored.
 reg [31:0] response_data[0:511];
 integer response_due[0:511],response_start[0:511];
 reg [8:0] response_wp=0,response_rp=0;
 reg [9:0] response_count=0;
 reg [1:0] physical_phase=0;
 reg [20:0] physical_base=0;
 integer current_group_latency=5,last_response_due=0,physical_groups=0;
 reg inject_response=0;
 integer mem_cycle=0;
 wire normal_memory_response=response_count!=0&&response_due[response_rp]<=mem_cycle;
 wire memory_response=inject_response|normal_memory_response;
 wire [31:0] memory_data=inject_response?32'h12345600:response_data[response_rp];
 wire [23:0] delay_rgb,out_rgb;wire dh,dv,dd,oh,ov,od;
 wire [46:0] config_data={4'd0,1'b0,1'b0,1'b1,8'd0,4'd8,zoom,transition_mode,
                          1'b1,8'd5,3'd2,9'd0,3'd0};
 reg [15:0] real_peak[0:255];
 reg [7:0] peak_index=0;
 wire [15:0] audio_peak=real_peak[peak_index];
 video_timing_data timing(.video_clk(video_clk),.rst(rst),.read_req(timing_req),
  .read_req_ack(timing_ack),.hs(hs),.vs(vs),.de(de));
 frame_read_write #(.ENABLE_READ_SOURCE(1)) reader(.rst(memory_rst),.mem_clk(mem_clk),.Sdr_init_done(1'b1),
  .Sdr_init_ref_vld(refresh),.Sdr_busy(refresh),
  .App_rd_en(raw_read_enable),.App_rd_addr(raw_addr),.Sdr_rd_en(logical_response),.Sdr_rd_dout(mapped_response),
  .read_clk(video_clk),.read_req(timing_req&&allow_requests),.read_req_ack(timing_ack),.read_accept_mem(read_accept),
  .read_finish(read_finish),.read_addr_0(21'd0),.read_addr_1(21'd0),.read_addr_2(21'd0),.read_addr_3(21'd0),
  .read_addr_index(2'd0),.read_len(21'd307200),.read_en(read_enable),.read_data(fifo_data),
  .App_wr_en(write_cmd),.App_wr_addr(write_addr),.App_wr_din(write_data),.App_wr_dm(write_mask),
  .write_clk(video_clk),.write_req(1'b0),.write_req_ack(),.write_finish(),
  .write_addr_0(21'd0),.write_addr_1(21'd0),.write_addr_2(21'd0),.write_addr_3(21'd0),
  .write_addr_index(2'd0),.write_len(21'd0),.write_en(1'b0),.write_data(32'd0),.write_linear(1'b0),
  .read_source_ready(logical_ready),.read_source_busy(bridge_busy),.write_busy_mem(write_busy_mem),
  .display_valid_video(display_valid),.fifo_fault(fifo_fault));
 html_memory_bridge bridge(.mem_clk(mem_clk),.rst(memory_rst),.video_read_req(timing_req),
  .read_accept_mem(read_accept),.active_view(active_view),.zoom(zoom),.transition_mode(transition_mode),.focus(focus),
  .write_busy_mem(write_busy_mem),.mem_ready(1'b1),.refresh_active(refresh),
  .logical_ready(logical_ready),.logical_response(logical_response),.busy(bridge_busy),
  .panels_ready(1'b1),.raw_read_en(raw_read_enable),.read_en(mapped_read_enable),.read_addr(mapped_addr),
  .response(memory_response),.memory_data(memory_data),.pixel_data(mapped_response),.fault(map_fault));
 video_delay delay(.video_clk(video_clk),.rst(rst),.read_en(read_enable),.read_data(fifo_data[31:8]),
  .hs(hs),.vs(vs),.de(de),.hs_r(dh),.vs_r(dv),.de_r(dd),.vout_data(delay_rgb));
 html_video_overlay overlay(.clk(video_clk),.rst(rst),.i_hs(dh),.i_vs(dv),.i_de(dd),.i_rgb(delay_rgb),
  .config_data(config_data),.page_event(page_event),.page_index(active_view[2:0]),.dual_enable(active_view[3]),
  .page_reverse(active_view[4]),.focus(focus),.audio_peak(audio_peak),.audio_status(4'd2),
  .o_hs(oh),.o_vs(ov),.o_de(od),.o_rgb(out_rgb));
 integer refresh_left=0,last_refresh=0,refresh_starts=0,refresh_min=10000,refresh_high=0;
 integer accepted=0,returned=0,logical_checks=0,bursts=0,read_index=0,frame_acks=0,j;
 reg prev_read=0,prev_accept=0,prev_refresh=0;
 reg [4:0] model_view=0,old_model_view=0;
 reg [1:0] model_zoom=0;
 reg model_aperture=0;
 integer model_age=0,model_width=640;
 reg [9:0] aperture_vector[0:63];
 reg latency_seen[5:10];
 reg normal_checks=1;
 function integer page_base;
 input integer p;
 begin page_base=(p<6?p:0)*307200;end endfunction
 function integer panel_base;
 input integer p;
 begin case(p)2:panel_base=1905664;3:panel_base=1968128;4:panel_base=2030592;default:panel_base=1843200;endcase end
 endfunction
 function integer pair_page;
 input integer p,right;
 begin case(p)
 1:pair_page=right?2:1;2:pair_page=right?1:2;3:pair_page=right?4:3;
 4:pair_page=right?3:4;default:pair_page=right?2:1;
 endcase end endfunction
 function [23:0] origin;
 input [2:0] p;input [1:0] z;
 begin
  if(z==0)origin=0;
  else if(p==0)origin=z==1?24'h44c480:24'h520704;
  else origin=z==1?24'h480350:24'h5545d4;
 end endfunction
 function [23:0] rgb565;
 input [15:0] p;
 begin rgb565={{p[15:11],p[15:13]},{p[10:5],p[10:9]},{p[4:0],p[4:2]}};end endfunction
 function [23:0] golden_location;
 input integer index;
 input [4:0] view;
 input [1:0] z;
 integer xx,yy,sx,sy,divisor,p,addr,half;
 reg [23:0] org;
 reg [4:0] selected;
 begin
  xx=index%640;yy=index/640;org=origin(view[2:0],z);divisor=z==0?1:z==1?2:3;
  sx=org[23:14]+((org[3:2]+xx)/divisor);
  sy=org[12:4]+((org[1:0]+yy)/divisor);
  selected=view;
  if(model_aperture&&(view[4]?(sx>=model_width):(sx<640-model_width)))selected=old_model_view;
  p=selected[2:0];half=0;
  if(selected[3])begin
   p=pair_page(p,sx>=320);sx=sx%320;
   if(sy<384)begin addr=panel_base(p)+sy*160+sx/2;half=sx%2;end
   else begin addr=panel_base(p)+61440+((sy-384)/4)*40+sx/8;half=(sx/4)%2;end
  end else addr=page_base(p)+sy*640+sx;
  golden_location={selected[3],half[0],1'b0,addr[20:0]};
 end endfunction
 function [23:0] expected_rgb;
 input integer index;
 input [4:0] view;input [1:0] z;
 reg [23:0] where;
 reg [31:0] word;
 begin
  where=golden_location(index,view,z);word=memory[where[20:0]];
  expected_rgb=where[23]?rgb565(where[22]?word[31:16]:word[15:0]):word[31:8];
 end endfunction
 integer physical_addr,planned_due,planned_latency,observed_latency;
 reg [23:0] logical_gold;
 always @(posedge mem_clk)begin
  if(memory_rst)begin
   response_wp<=0;response_rp<=0;response_count<=0;physical_phase<=0;physical_base<=0;
   last_response_due=0;current_group_latency=5;physical_groups=0;
   refresh<=0;refresh_left=0;last_refresh=0;mem_cycle<=0;prev_read<=0;prev_accept<=0;
   prev_refresh<=0;refresh_high=0;read_index=0;model_view=0;old_model_view=0;model_zoom=0;
   model_aperture=0;model_age=0;model_width=640;
  end else begin
   mem_cycle<=mem_cycle+1;
   if(refresh)begin
    if(refresh_left<=1)refresh<=0;else refresh_left=refresh_left-1;
   end else if(!bridge_busy&&!reader.App_rd_busy&&!reader.App_wr_busy&&mem_cycle-last_refresh>400)begin
    refresh<=1;refresh_left=20;last_refresh=mem_cycle;refresh_starts=refresh_starts+1;
   end
   if(refresh)refresh_high=refresh_high+1;
   if(!refresh&&prev_refresh)begin
    if(refresh_high<20)$fatal(1,"refresh shorter than20 cycles");
    if(refresh_high<refresh_min)refresh_min=refresh_high;refresh_high=0;
   end
   prev_refresh<=refresh;prev_read<=mapped_read_enable;prev_accept<=read_accept;
   if(read_accept&&!prev_accept)begin
    if(model_view[2:0]!=active_view[2:0]&&transition_mode!=0&&frame_acks>0)begin
     old_model_view=model_view;model_aperture=1;model_age=0;model_width=0;
    end else if(model_aperture)begin
     if(transition_mode==0||model_age>=62)begin model_aperture=0;model_width=640;end
     else begin model_age=model_age+1;model_width=aperture_vector[model_age];end
    end
    model_view=active_view;model_zoom=zoom;read_index=0;frame_acks=frame_acks+1;
   end
   if(normal_checks&&(map_fault||fifo_fault))$fatal(1,"bridge/FIFO fault map%0b fifo%0b at%0d physicalreads%0d",map_fault,fifo_fault,mem_cycle,accepted);
   if(raw_read_enable&&!logical_ready)$fatal(1,"logical reader ignores source backpressure");
   if(normal_checks&&logical_response!==raw_read_enable)$fatal(1,"logical response/accept contract changed");
   if(raw_read_enable)begin
    if(read_index>=307200)$fatal(1,"logical frame overfetch");
    logical_gold=expected_rgb(read_index,model_view,model_zoom);
    if(normal_checks&&mapped_response[31:8]!==logical_gold)
     $fatal(1,"logical source pixel frame%0d index%0d got%h expected%h",frame_acks,read_index,mapped_response[31:8],logical_gold);
    read_index=read_index+1;logical_checks=logical_checks+1;
   end
   if(write_cmd)$fatal(1,"unexpected SDRAM write in read-only display fixture");
   if(!mapped_read_enable&&physical_phase!=0)$fatal(1,"physical four-beat group interrupted");
   if(mapped_read_enable)begin
    if(physical_phase==0)begin
     if(refresh)$fatal(1,"new physical group starts during refresh");
     if(mapped_addr[1:0]!=0)$fatal(1,"physical first address is not4word aligned %0d",mapped_addr);
     physical_base<=mapped_addr;physical_addr=mapped_addr;
     current_group_latency=5+(physical_groups%6);physical_groups=physical_groups+1;
    end else physical_addr=physical_base+physical_phase;
    physical_phase<=physical_phase+1'b1;
    if(physical_addr>=2093056)$fatal(1,"SDRAM physical address exceeds allocated frames/panels");
    // A later request never overtakes an earlier response. Clamping the due
    // cycle to previous+1 preserves ordering while retaining the5..10 bound.
    planned_latency=current_group_latency;planned_due=mem_cycle+planned_latency;
    if(planned_due<=last_response_due)planned_due=last_response_due+1;
    if(planned_due-mem_cycle<5||planned_due-mem_cycle>10)$fatal(1,"model latency outside5..10");
    response_data[response_wp]<=memory[physical_addr];response_due[response_wp]<=planned_due;
    response_start[response_wp]<=mem_cycle;response_wp<=response_wp+1'b1;last_response_due=planned_due;
    accepted=accepted+1;
   end
   if(normal_memory_response)begin
    observed_latency=mem_cycle-response_start[response_rp];
    if(observed_latency<5||observed_latency>10)$fatal(1,"observed response latency%0d",observed_latency);
    latency_seen[observed_latency]=1;response_rp<=response_rp+1'b1;returned=returned+1;
   end
   case({mapped_read_enable,normal_memory_response})
    2'b10:response_count<=response_count+1'b1;
    2'b01:response_count<=response_count-1'b1;
   endcase
   if(mapped_read_enable&&response_count==512&&!normal_memory_response)$fatal(1,"SDRAM response model queue overflow");
  end
 end
 reg ack_prev=0;
 integer ack_video=0;
 always @(posedge video_clk)begin
  if(rst)begin ack_prev<=0;page_event<=0;display_valid<=0;end
  else begin
   ack_prev<=timing_ack;page_event<=0;
   if(timing_ack&&!ack_prev)begin
    ack_video=ack_video+1;display_valid<=1;peak_index<=peak_index+1'b1;
    $display("PROGRESS readerACK%0d time%0t physical%0d logical%0d",ack_video,$time,accepted,logical_checks);$fflush();
    if(commit_pending)begin page_event<=1;commit_pending<=0;end
   end
  end
 end
 //32 registered timing stages from video_timing_data output through video_delay,
 //pixel_adjust, OSD and Bot. Exact sync comparison runs even in blanking.
 reg [2:0] expected_sync[0:31];
 reg old_timing_de=0,old_timing_vs=0;
 integer timing_x=0,timing_y=0,xi[0:31],yi[0:31],q;
 integer sync_checks=0,base_pixel_checks=0,frame_pixels=0,fd=0,frame_number=0;
 integer out_vs_count=0;
 reg prev_out_vs=0,capturing=0,verify_pixels=0;
 reg [4:0] capture_view=0;
 reg [1:0] capture_zoom=0;
 reg [23:0] wanted;
 always @(posedge video_clk)begin
  if(rst)begin
   old_timing_de=0;old_timing_vs=0;timing_x=0;timing_y=0;prev_out_vs=0;
   for(q=0;q<32;q=q+1)begin expected_sync[q]=0;xi[q]=0;yi[q]=0;end
  end else begin
   if(vs&&!old_timing_vs)timing_y=0;
   else if(old_timing_de&&!de)timing_y=timing_y+1;
   if(!de||!old_timing_de)timing_x=0;else timing_x=timing_x+1;
   old_timing_de=de;old_timing_vs=vs;
   for(q=31;q>0;q=q-1)begin expected_sync[q]=expected_sync[q-1];xi[q]=xi[q-1];yi[q]=yi[q-1];end
   expected_sync[0]={hs,vs,de};xi[0]=timing_x;yi[0]=timing_y;
   #1;
   if({oh,ov,od}!==expected_sync[31])$fatal(1,"full-chain timing alignment");
   sync_checks=sync_checks+1;
   if(ov&&!prev_out_vs)begin
    out_vs_count=out_vs_count+1;
    $display("PROGRESS outputVS%0d time%0t ACK%0d physical%0d",out_vs_count,$time,ack_video,accepted);$fflush();
   end
   prev_out_vs=ov;
   if(verify_pixels&&od)begin
    if(^out_rgb===1'bx)$fatal(1,"unknown DUT pixel x%0d y%0d",xi[31],yi[31]);
    if(xi[31]>=640||yi[31]>=480)$fatal(1,"bad active geometry");
    // Static A-layer equality outside all B/C overlays. This is a data oracle,
    // not a software image renderer; every exported pixel comes from out_rgb.
    if(yi[31]<380&&!(xi[31]>=500&&yi[31]<105))begin
     wanted=expected_rgb(yi[31]*640+xi[31],capture_view,capture_zoom);
     if(out_rgb!==wanted)$fatal(1,"source RGB mismatch frame%0d x%0d y%0d got%h expected%h",frame_number,xi[31],yi[31],out_rgb,wanted);
     base_pixel_checks=base_pixel_checks+1;
    end
    if(capturing)$fwrite(fd,"%c%c%c",out_rgb[23:16],out_rgb[15:8],out_rgb[7:0]);
    frame_pixels=frame_pixels+1;
   end
  end
 end
 task seed_static_pose;
 begin
  // State fixture only; no pixels are forced. Sources and transforms still
  // execute in real DUT logic. The natural choreography has separate tests.
  overlay.osd.typed_count=127;overlay.osd.typing_delay=0;overlay.osd.typing_phase=0;
  overlay.osd.speaking=0;overlay.osd.event_pending=0;overlay.osd.cursor_frame=64;
  overlay.bot.frame_count=128;overlay.bot.breath_phase=0;overlay.bot.reaction_age=255;
  overlay.bot.blink_wait=500;overlay.bot.blink_phase=0;overlay.bot.event_pending=0;
  overlay.bot.gaze_x=0;overlay.bot.gaze_y=0;overlay.bot.gaze_vx=0;overlay.bot.gaze_vy=0;
  overlay.bot.tilt=0;overlay.bot.tilt_v=0;overlay.bot.shape=0;overlay.bot.shape_v=0;
  overlay.bot.hop=0;overlay.bot.hop_v=0;
 end endtask
 task render_view;
 input [4:0] view;
 input [1:0] magnify;
 input integer static_pose;
 input [767:0] filename;
 integer ack_before,vs_before;
 begin
  @(negedge video_clk);ack_before=ack_video;
  if(active_view!=view)commit_pending=1;
  active_view=view;zoom=magnify;capture_view=view;capture_zoom=magnify;
  wait(ack_video>ack_before);vs_before=out_vs_count;wait(out_vs_count>vs_before);
  @(negedge video_clk);
  if(static_pose)seed_static_pose;
  frame_number=frame_number+1;frame_pixels=0;verify_pixels=1;
  if(filename!="")begin
   fd=$fopen(filename,"wb");if(!fd)$fatal(1,"cannot create full-chain frame");
   $fwrite(fd,"P6\n640 480\n255\n");capturing=1;
  end
  wait(frame_pixels==307200);@(negedge video_clk);verify_pixels=0;
  if(capturing)begin capturing=0;$fclose(fd);end
  if(fifo_fault||map_fault)$fatal(1,"fault after completed visible frame");
  $display("FRAME_PASS %0s pixels%0d accepted%0d returned%0d view%h zoom%0d age%0d",filename,frame_pixels,accepted,returned,view,magnify,overlay.bot.reaction_age);$fflush();
 end endtask
 integer f;
 initial begin
  for(f=5;f<=10;f=f+1)latency_seen[f]=0;
  $readmemh("output/html_fidelity/display_vectors/memory_words.hex",memory);
  $readmemh("output/html_fidelity/display_vectors/real_wav_peaks.hex",real_peak);
  $readmemh("output/html_fidelity/display_vectors/aperture_width.hex",aperture_vector);
  $display("PROGRESS fixture loaded2093056words plus realWAV peaks");$fflush();
  repeat(10)@(negedge video_clk);rst=0;
  render_view(5'd0,2'd0,1,"output/html_fidelity/display_chain/page0.ppm");
  if($test$plusargs("smoke"))begin
   $display("DISPLAY_CHAIN_SIM_PASS smoke one full640x480 real FIFO/timing + memory model");$finish;
  end
  render_view(5'd1,2'd0,1,"output/html_fidelity/display_chain/page1.ppm");
  render_view(5'd2,2'd0,1,"output/html_fidelity/display_chain/page2.ppm");
  render_view(5'd3,2'd0,1,"output/html_fidelity/display_chain/page3.ppm");
  render_view(5'd4,2'd0,1,"output/html_fidelity/display_chain/page4.ppm");
  render_view(5'd5,2'd0,1,"output/html_fidelity/display_chain/page5.ppm");
  render_view(5'd9,2'd0,1,"output/html_fidelity/display_chain/compare_eagle_phoenix.ppm");
  render_view(5'd11,2'd0,1,"output/html_fidelity/display_chain/compare_elf_dragon.ppm");
  render_view(5'd1,2'd1,1,"output/html_fidelity/display_chain/zoom2.ppm");
  render_view(5'd1,2'd2,1,"output/html_fidelity/display_chain/zoom3.ppm");
  // A real committed page event starts aperture, gaze and caption reset together.
  transition_mode=1;
  render_view(5'd2,2'd0,0,"output/html_fidelity/display_chain/action00.ppm");
  if(overlay.osd.typed_count!=0)$fatal(1,"caption started before550ms");
  render_view(5'd2,2'd0,0,"output/html_fidelity/display_chain/action01.ppm");
  if(overlay.bot.gaze_x<=0)$fatal(1,"committed page event did not drive gaze");
  render_view(5'd2,2'd0,0,"");render_view(5'd2,2'd0,0,"");
  render_view(5'd2,2'd0,0,"");render_view(5'd2,2'd0,0,"");
  render_view(5'd2,2'd0,0,"output/html_fidelity/display_chain/action06.ppm");
  render_view(5'd2,2'd0,0,"output/html_fidelity/display_chain/action07.ppm");
  if(overlay.bot.tilt<=0)$fatal(1,"body did not follow page gaze at90ms");
  // Negative diagnostics: an unsolicited SDRAM response must trip tag fault.
  allow_requests=0;normal_checks=0;
  wait(!bridge_busy&&response_count==0&&!raw_read_enable);repeat(20)@(negedge mem_clk);
  inject_response=1;@(negedge mem_clk);inject_response=0;repeat(4)@(negedge mem_clk);
  if(!map_fault)$fatal(1,"unsolicited response not diagnosed by tag FIFO");
  // Empty the real FIFO under active-video demand and prove sticky underflow.
  fault_reset=1;repeat(10)@(negedge video_clk);fault_reset=0;
  wait(reader.rd_underflow);if(!fifo_fault)$fatal(1,"empty read not diagnosed");
  for(f=5;f<=10;f=f+1)if(!latency_seen[f])$fatal(1,"missing response latency%0d coverage",f);
  if(refresh_starts==0||refresh_min<20)$fatal(1,"no20cycle refresh coverage");
  $display("DISPLAY_CHAIN_SIM_PASS frames%0d sync_checks%0d source_pixels%0d physicalrequests%0d physicalresponses%0d refreshes%0d minimum%0d cycles logicalchecks%0d latencies5..10 FIFOunderflow/tagfaultverified",frame_number,sync_checks,base_pixel_checks,accepted,returned,refresh_starts,refresh_min,logical_checks);$finish;
 end
 initial begin #600000000;$fatal(1,"full-chain watchdog frame%0d index%0d fault%0b/%0b",frame_number,read_index,fifo_fault,map_fault);end
endmodule
