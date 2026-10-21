`timescale 1ns/1ps
// Loaded-memory segment: actual ext_full_005 sequential256 reader and generated
// FIFO, production VGA timing/video_delay, transition and final no-Bot output.
// SDRAM response is ordered10cycle stimulus. SD/loader is verified separately.
module no_bot_legacy_scanout_tb #(parameter FRAMES=8,PAGE=0,ZOOM=0,DUAL=0,FOCUS=0,ANIMATE=0,NEXT_PAGE=1,NEXT_ZOOM=0,NEXT_DUAL=0,NEXT_FOCUS=0,MODEL_LOAD_CYCLES=75000000,STATIC_CAPTION=0,FIXTURE_ROOT=".",CASE_NAME="home");
 reg mc=0,vc=0,sc=0;always #12.5 mc=~mc;always #20 vc=~vc;always #5 sc=~sc;
 reg rst=1;reg request_toggle=ANIMATE?0:1;reg cover_request=ANIMATE?1:0;wire cover_ack;
 reg[15:0]real_peaks[0:255];reg[7:0]peak_index=0;reg previous_raw_ack=0;
 reg[11:0]candidate={1'b0,FOCUS[2:0],ZOOM[1:0],DUAL[0],PAGE[2:0],2'd0};wire raw_req,raw_ack,mem_req,mem_ack;wire[11:0]front;wire commit_ack;
 wire hs,vs,de,rd_en,app_rd,app_wr;wire[20:0]addr,wa;wire[31:0]fifo_data,wd;wire[3:0]dm;wire fifo_fault;
 reg[31:0]memory[0:614399];reg[9:0]valid_pipe=0;reg[31:0]data_pipe[0:9];integer j,reads=0,responses=0,memcycles=0,burst=0,consumed=0,min_fifo=511,max_fifo=0,writes=0,max_write_fifo=0;
 reg refresh=0;integer refresh_left=0,last_refresh=0,refreshes=0;
 reg write_req=0,write_en=0;reg[31:0]write_pixel=0;wire write_ack,write_finish;reg[23:0]write_payload[0:307199];reg wrote_complete=0;time load_start_time=0,load_end_time=0;
 wire dh,dv,dd,th,tv,td,oh,ov,od;wire[23:0]drgb,trgb,rgb;wire forwarded,transition_busy;
 reg rawprev=0,commitprev=0,valid_display=0;wire event_page=commit_ack^commitprev;
 wire[50:0]cfg={4'd4,4'd0,1'b0,1'b0,1'b1,8'd0,4'd8,front[7:6],2'd1,1'b1,8'd5,3'd2,9'd0,3'd0};
 video_timing_data timing(.video_clk(vc),.rst(rst),.read_req(raw_req),.read_req_ack(raw_ack),.hs(hs),.vs(vs),.de(de));
 display_commit #(.BUFFER_BITS(12),.REQUIRE_INITIAL_COMMIT(1)) commit_dut(.video_clk(vc),.rst(rst),.raw_read_req(raw_req),.raw_read_ack(raw_ack),.mem_read_req(mem_req),.mem_read_ack(mem_ack),.commit_toggle_async(forwarded),.candidate_async(candidate),.fault_async(fifo_fault),.active_buf(front),.commit_ack_toggle(commit_ack));
 frame_read_write reader(.rst(rst),.mem_clk(mc),.Sdr_init_done(1'b1),.Sdr_init_ref_vld(refresh),.Sdr_busy(refresh),.App_rd_en(app_rd),.App_rd_addr(addr),.Sdr_rd_en(valid_pipe[9]),.Sdr_rd_dout(data_pipe[9]),.read_clk(vc),.read_req(mem_req),.read_req_ack(mem_ack),.read_finish(),.read_addr_0(21'd0),.read_addr_1(21'd307200),.read_addr_2(21'd0),.read_addr_3(21'd0),.read_addr_index(front[1:0]),.read_len(21'd307200),.read_en(rd_en),.read_data(fifo_data),.App_wr_en(app_wr),.App_wr_addr(wa),.App_wr_din(wd),.App_wr_dm(dm),.write_clk(sc),.write_req(write_req),.write_req_ack(write_ack),.write_finish(write_finish),.write_addr_0(21'd0),.write_addr_1(21'd307200),.write_addr_2(21'd0),.write_addr_3(21'd0),.write_addr_index(2'd1),.write_len(21'd307200),.write_en(write_en),.write_data(write_pixel),.display_valid_video(valid_display),.fifo_fault(fifo_fault));
 video_delay delay(.video_clk(vc),.rst(rst),.read_en(rd_en),.read_data(fifo_data[31:8]),.hs(hs),.vs(vs),.de(de),.hs_r(dh),.vs_r(dv),.de_r(dd),.vout_data(drgb));
 video_transition #(.COVER_BEFORE_LOAD(ANIMATE),.CLOSE_STEP(ANIMATE?54:32),.OPEN_STEP(ANIMATE?36:32),.MASK_COLOR(24'h151615)) transition(.clk(vc),.rst(rst),.i_hs(dh),.i_vs(dv),.i_de(dd),.i_rgb(valid_display?drgb:24'd0),.enable(valid_display),.mode(ANIMATE?2'd1:2'd0),.cover_request_toggle_async(cover_request),.cover_ack_toggle(cover_ack),.frame_start(raw_req&&!rawprev),.candidate_toggle_async(request_toggle),.display_fault_async(fifo_fault),.commit_ack_toggle(commit_ack),.forwarded_commit_toggle(forwarded),.o_hs(th),.o_vs(tv),.o_de(td),.o_rgb(trgb),.transition_busy(transition_busy));
 html_video_overlay overlay(.clk(vc),.rst(rst),.i_hs(th),.i_vs(tv),.i_de(td),.i_rgb(trgb),.config_data(cfg),.page_event(event_page),.page_index(front[4:2]),.dual_enable(front[5]),.page_reverse(front[11]),.focus(front[10:8]),.audio_peak(real_peaks[peak_index]),.audio_status(4'd2),.o_hs(oh),.o_vs(ov),.o_de(od),.o_rgb(rgb));
 always@(posedge mc)begin
  if(rst)begin valid_pipe<=0;end else begin
   memcycles=memcycles+1;valid_pipe<={valid_pipe[8:0],app_rd};
   for(j=9;j>0;j=j-1)data_pipe[j]<=data_pipe[j-1];
   if(app_rd)begin
    if(addr!==front[1:0]*307200+reads%307200)$fatal(1,"sequential acceptedaddress index%0d got%0d",reads,addr);
    data_pipe[0]<=memory[addr];reads=reads+1;
   end
   if(valid_pipe[9])responses=responses+1;
   if(responses-consumed>max_fifo)max_fifo=responses-consumed;
   if(responses-consumed>511)$fatal(1,"actualFIFO usable511overrun");
   if(app_wr)begin
    if(!ANIMATE||front[1:0]!=0||app_rd)$fatal(1,"writer touchedfront orread/write overlap");
    if(wa!==307200+(479-writes/640)*640+writes%640||wd!=={write_payload[writes],8'd0})$fatal(1,"actualwriter acceptedword%0d address%0d data%h expected%h",writes,wa,wd,write_payload[writes]);
    memory[wa]<=wd;writes=writes+1;
   end
   if(ANIMATE)begin
    if(refresh)begin if(refresh_left<=1)refresh<=0;else refresh_left=refresh_left-1;end
    else if(memcycles-last_refresh>3100&&!app_rd&&!app_wr&&!reader.O_rd_busy&&!reader.O_wr_busy)begin refresh<=1;refresh_left=20;last_refresh=memcycles;refreshes=refreshes+1;end
    if(reader.rdusedw>max_write_fifo)max_write_fifo=reader.rdusedw;
   end
   if(fifo_fault)$fatal(1,"actualFIFO fault");
  end
 end
 reg[2:0]syncq[0:27];integer k,sync_checks=0,px=0,py=0,pixels=0,frames=0,fd=0,sourcechecks=0,final_steady=0,initial_steady=0;
 reg oldde=0,oldvs=0,previous_dd=0,previous_dv=0;integer dx=0,dy=0;time first,last,previous_first=0;reg[2047:0]filename;
 always@(posedge vc)begin
  if(rst)begin rawprev<=0;commitprev<=0;valid_display<=0;for(k=0;k<28;k=k+1)syncq[k]=0;end
  else begin
   rawprev<=raw_req;commitprev<=commit_ack;previous_raw_ack<=raw_ack;if(raw_ack&&!previous_raw_ack)peak_index<=peak_index+1'b1;if(commit_ack)valid_display<=1;
   for(k=27;k>0;k=k-1)syncq[k]=syncq[k-1];syncq[0]={hs,vs,de};
   if(rd_en&&valid_display)begin
    if(reader.rd_empty)$fatal(1,"actualreadFIFOunderflow");consumed=consumed+1;
    if(consumed%307200>512&&consumed%307200<306688&&responses-consumed<min_fifo)min_fifo=responses-consumed;
   end
   #1;
   if({oh,ov,od}!==syncq[27])$fatal(1,"sequential finalvideo28stage alignment");sync_checks=sync_checks+1;
   if(dv&&!previous_dv)begin dx=0;dy=0;end
   previous_dv=dv;
   if(dd&&valid_display)begin
    if(drgb!==memory[front[1:0]*307200+dy*640+dx][31:8])$fatal(1,"sequential delayedRGB x%0d y%0d got%h expected%h",dx,dy,drgb,memory[front[1:0]*307200+dy*640+dx][31:8]);
    sourcechecks=sourcechecks+1;if(dx==639)dx=0;else dx=dx+1;
   end
   if(previous_dd&&!dd)dy=dy+1;previous_dd=dd;
   if(ov&&!oldvs)begin
    px=0;py=0;pixels=0;
    if(STATIC_CAPTION)begin
     overlay.osd.swap_age=31;overlay.osd.swap_values=overlay.osd.SWAP_STEADY;overlay.osd.palette_loading=0;overlay.osd.palette_valid0=0;overlay.osd.swap_palette_ready=1;
     overlay.osd.typed_count=127;overlay.osd.typing_delay=0;overlay.osd.typing_phase=0;overlay.osd.event_pending=0;overlay.osd.cursor_frame=64;
    end
   end
   oldvs=ov;
   if(od&&valid_display)begin
    if(pixels==0)begin
     first=$time;if(frames>0&&first-previous_first!=16_800_000)$fatal(1,"not consecutive production frames");previous_first=first;
     $sformat(filename,"%0s/frame_%02d.ppm",FIXTURE_ROOT,frames);fd=$fopen(filename,"wb");if(!fd)$fatal(1,"cannotwriteactualRTLframe");$fwrite(fd,"P6\n640 480\n255\n");
    end
    if(^rgb===1'bx)$fatal(1,"unknown finalpixel");
    if(!transition_busy&&((py<380&&!(px>=500&&py<105))||(px>=510&&py>=105)))begin
     if(rgb!==memory[front[1:0]*307200+py*640+px][31:8])$fatal(1,"finalnoBot staticpixel x%0d y%0d",px,py);
    end
    $fwrite(fd,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);pixels=pixels+1;last=$time;
    if(px==639)begin px=0;py=py+1;end else px=px+1;
    if(pixels==307200)begin
     $fclose(fd);$display("FRAME_PASS %0d pixels307200 first%0t last%0t reads%0d responses%0d",frames,first,last,reads,responses);$fflush();frames=frames+1;
     $display("TRANSITION_STATE frame%0d phase%0d offset%0d front%0d page%0d cover%0d coverACK%0d commit%0d commitACK%0d writes%0d refreshes%0d",frames,transition.phase,transition.offset,front[1:0],front[4:2],cover_request,cover_ack,request_toggle,commit_ack,writes,refreshes);$fflush();
     if(front[1:0]==0&&!transition_busy)initial_steady=initial_steady+1;
     if(front[1:0]==1&&!transition_busy)final_steady=final_steady+1;
     if((!ANIMATE&&frames==FRAMES)||(ANIMATE&&final_steady==2))begin
      if(ANIMATE&&(!wrote_complete||writes!=307200||refreshes==0))$fatal(1,"missingactualwrite/refreshcoverage");
      $display("READ_WRITE_SCOPE writes%0d writeFIFOmax%0d refreshes%0d loadstart%0t loadend%0t source_period16sysclocks realwriterfinishqualified%0d",writes,max_write_fifo,refreshes,load_start_time,load_end_time,wrote_complete); $display("TEST_PASS LEGACY_SEQUENTIAL frames%0d finalpixels%0d sourcechecks%0d syncchecks%0d FIFOunderflow0 minFIFO%0d maxFIFO%0d production40_25MHz_16_8ms actualoutputRGB; ordered10cyclememorymodel notSDRAMhardwarequalification",frames,frames*307200,sourcechecks,sync_checks,min_fifo,max_fifo);$finish;end
    end
   end
  end
 end
 initial begin
  $readmemh({FIXTURE_ROOT,"/memory.hex"},memory);
  $readmemh({FIXTURE_ROOT,"/real_wav_peaks.hex"},real_peaks);
  if(ANIMATE)$readmemh({FIXTURE_ROOT,"/second_loader_payload.hex"},write_payload);
  repeat(10)@(negedge vc);rst=0;
  if(ANIMATE)begin
   wait(cover_ack==1);@(negedge sc);request_toggle=1;
   wait(initial_steady>=8);@(negedge sc);cover_request=0;
   wait(cover_ack==0);load_start_time=$time;
   @(negedge sc);write_req=1;wait(write_ack);@(negedge sc);write_req=0;wait(!write_ack);repeat(16)@(negedge sc);
   for(integer n=0;n<307200;n=n+1)begin
    @(negedge sc);write_en=1;write_pixel={write_payload[n],8'd0};@(negedge sc);write_en=0;repeat(14)@(negedge sc);
   end
   wait(write_finish);if(writes!=307200)$fatal(1,"writerfinish early");wrote_complete=1;
   while($time-load_start_time<MODEL_LOAD_CYCLES*10)@(negedge sc);load_end_time=$time;
   @(negedge sc);candidate={1'b0,NEXT_FOCUS[2:0],NEXT_ZOOM[1:0],NEXT_DUAL[0],NEXT_PAGE[2:0],2'd1};request_toggle=0;
  end
 end
 initial begin #2000000000;$fatal(1,"sequential watchdog");end
endmodule
