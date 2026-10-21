`timescale 1ns/1ps
module html_integration_timing_tb #(parameter REQUIRE=1);
 reg vc=0,mc=0,sc=0;always#20 vc=~vc;always#12.5 mc=~mc;always#5 sc=~sc;
 reg rst=1,commit_toggle=0,fault=0;reg[4:0]candidate=5'd1;
 wire req,ack,mreq,hs,vs,de;reg mack=0;wire[4:0]view;wire cack;
 video_timing_data timing(vc,rst,req,ack,hs,vs,de);
 display_commit #(.BUFFER_BITS(5),.REQUIRE_INITIAL_COMMIT(REQUIRE))dut(vc,rst,req,ack,mreq,mack,commit_toggle,candidate,fault,view,cack);
 reg[20:0]vs_delay=0;reg req_previous=0,vs_previous=0;wire dvs=vs_delay[20];
 always@(posedge vc)if(rst)begin vs_delay<=0;req_previous<=0;vs_previous<=0;end else begin vs_delay<={vs_delay[19:0],vs};req_previous<=req;vs_previous<=dvs;end
 reg[4:0]src_config=5'b10110;wire[4:0]new_config,old_config;
 frame_config_bridge #(.WIDTH(5))fixed_bridge(sc,rst,src_config,vc,rst,req&&!req_previous,new_config);
 frame_config_bridge #(.WIDTH(5))old_bridge(sc,rst,src_config,vc,rst,dvs&&!vs_previous,old_config);
 reg[4:0]new_meta=0,new_sync=0,old_meta=0,old_sync=0;reg[4:0]new_memory=0,old_memory=0;
 reg[2:0]mreq_sync=0;reg previous_mack=0;integer waitcount=0,mem_transactions=0,req_count=0,clk_count=0,ack_clock=0;
 always@(posedge mc)begin
 if(rst)begin new_meta<=0;new_sync<=0;old_meta<=0;old_sync<=0;new_memory<=0;old_memory<=0;mreq_sync<=0;mack<=0;waitcount<=0;previous_mack<=0;end
 else begin
 new_meta<=new_config;new_sync<=new_meta;old_meta<=old_config;old_sync<=old_meta;mreq_sync<={mreq_sync[1:0],mreq};previous_mack<=mack;
 if(!mreq_sync[2])begin mack<=0;waitcount<=0;end else if(waitcount==20)mack<=1;else waitcount<=waitcount+1;
 if(mack&&!previous_mack)begin new_memory<=new_sync;old_memory<=old_sync;mem_transactions=mem_transactions+1;ack_clock=clk_count;$display("ACTUAL_ACK n%0d videoCycle%0d cfgNew%0d cfgOld%0d",mem_transactions,clk_count,new_sync,old_sync);end
 end end
 always@(posedge vc)begin clk_count=clk_count+1;if(!rst&&req&&!req_previous)begin req_count=req_count+1;$display("TIMING_REQ n%0d cycle%0d",req_count,clk_count);end end
 task step;begin @(negedge vc);end endtask
 initial begin
 repeat(5)step;rst=0;step;
 timing.color_bar_m0.h_cnt=0;timing.color_bar_m0.v_cnt=8;timing.color_bar_m0.vs_reg=1;timing.color_bar_m0.vs_reg_d0=1;timing.video_vs_d0=1;timing.video_vs_d1=1;vs_delay=21'h1fffff;vs_previous=1;
 // Source snapshot settles before first real negative VS request.
 wait(req_count==1);wait(ack);wait(!req);repeat(20)step;
 if(REQUIRE&&mem_transactions!=0)$fatal(1,"startup request reachedmemory before pendingcommit");
 if(!REQUIRE&&mem_transactions!=1)$fatal(1,"default legacy request wasblocked");
 wait(dvs==0);wait(dvs==1);repeat(8)step;
 if(!REQUIRE)begin
 if(new_memory!==src_config||old_memory!==0||old_config!==src_config)$fatal(1,"configuration issue not reproduced");
 $display("REPRODUCED first frame imageConfig%0d oldBadge%0d; fixed imageConfig%0d badge%0d",old_memory,old_config,new_memory,new_config);
 end
 // A pending commit arrives after the skipped startup boundary. It must not
 // start memory in the middle of this frame. It is accepted at next real request.
 commit_toggle=1;candidate=5'd18;repeat(100)step;
 if(cack!==0||(REQUIRE&&mem_transactions!=0))$fatal(1,"midframe firstcommit started read");
 wait(req_count==2);wait(cack==1);repeat(15)step;
 if(view!==18||new_memory!==src_config||mem_transactions!=(REQUIRE?1:2))$fatal(1,"first pendingcommit/config failed");
 wait(!req);wait(!mack);wait(req_count==3);wait(ack);repeat(15)step;
 if(mem_transactions!=(REQUIRE?2:3)||view!==18||cack!==1)$fatal(1,"initialized ordinary frame failed");
 $display("TEST_PASS REQUIRE%0d real640x480negativeVS config_capture_beforeACK firstcommit_midframe_deferred initialized_normal_requests requests%0d memtransactions%0d",REQUIRE,req_count,mem_transactions);$finish;
 end
 initial begin #40000000;$fatal(1,"timing review watchdog");end
endmodule
