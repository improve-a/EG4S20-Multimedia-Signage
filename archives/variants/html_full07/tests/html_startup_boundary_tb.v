`timescale 1ns/1ps
module html_startup_boundary_tb #(parameter REQUIRE=1);
 reg vc=0,mc=0;always #20 vc=~vc;always #12.5 mc=~mc;
 reg rst=1,raw_req=0;
 reg[7:0]sd_data=0;reg sd_valid=0,sd_end=0;wire mode_valid,layer_mode,loader_active,loader_ready,loader_error,sector_req,write_req;wire[5:0]page_ready;wire[31:0]sector_addr,write_data;wire[20:0]write_base,write_len;wire write_en;
 reg[7:0]header[0:511];integer byte_number;reg[1:0]mode_sync=0;
 always@(posedge mc)if(rst)mode_sync<=0;else mode_sync<={mode_sync[0],layer_mode};
 html_scene_loader loader(.clk(vc),.rst(rst),.enable(1'b1),.sector0(32'd100),.sector1(32'd200),.sector2(32'd300),.sector3(32'd400),.sector4(32'd500),.sector5(32'd600),.active(loader_active),.ready(loader_ready),.error(loader_error),.page_ready(page_ready),.mode_valid(mode_valid),.layer_mode(layer_mode),.sector_req(sector_req),.sector_addr(sector_addr),.sector_data(sd_data),.sector_valid(sd_valid),.sector_end(sd_end),.sector_error(1'b0),.write_req(write_req),.write_req_ack(1'b0),.write_en(write_en),.write_data(write_data),.write_base(write_base),.write_len(write_len),.write_finish_toggle(1'b0));
wire raw_ack,mem_req;reg mem_ack=0;wire[4:0]view;wire commit_ack;
 // No commit, no page_ready, no display_valid at startup. Production display_commit
 // still forwards each timing request. ReaderACK boundedmodel only in this proof.
 display_commit #(.BUFFER_BITS(5),.REQUIRE_INITIAL_COMMIT(REQUIRE))c(vc,rst,raw_req,raw_ack,mem_req,mem_ack,1'b0,5'd0,1'b0,view,commit_ack);
 reg[2:0]reqsync=0;always@(posedge mc)if(rst)begin reqsync<=0;mem_ack<=0;end else begin reqsync<={reqsync[1:0],mem_req};mem_ack<=reqsync[2];end
 wire re,ready,response,busy,fault;wire[20:0]addr;wire[31:0]pixel;reg[9:0]rv=0;integer n=0,phase=0;
 html_layer_memory_bridge b(.mem_clk(mc),.rst(rst),.video_read_req(mem_req),.read_accept_mem(mem_ack),.active_view(view),.zoom(2'd0),.transition_mode(2'd0),.focus(3'd0),.panels_ready(1'b0),.layer_resources_enabled(mode_sync[1]),.write_busy_mem(1'b0),.mem_ready(1'b1),.refresh_active(1'b0),.raw_read_en(ready),.read_en(re),.read_addr(addr),.response(rv[9]),.memory_data(32'hffffffff),.pixel_data(pixel),.logical_ready(ready),.logical_response(response),.busy(busy),.fault(fault));
 always@(posedge mc)begin
 if(rst)rv<=0;else begin rv<={rv[8:0],re};if(re)begin if(phase==0&&addr[1:0]!=0)$fatal(1,"unaligned physical group");phase=(phase+1)%4;n=n+1;end else if(phase!=0)$fatal(1,"interrupted group");end
 end
 initial begin $readmemh("startup_header.hex",header);repeat(5)@(negedge vc);rst=0;wait(sector_req);@(negedge vc);for(byte_number=0;byte_number<512;byte_number=byte_number+1)begin sd_data=header[byte_number];sd_valid=1;@(negedge vc);end sd_valid=0;sd_end=1;@(negedge vc);sd_end=0;wait(layer_mode);repeat(10)@(negedge vc);if(!write_req||page_ready!=0||loader_error)$fatal(1,"bad loader startupboundary");raw_req=1;wait(raw_ack);raw_req=0;if(REQUIRE)begin repeat(100)@(negedge mc);if(fault||n!=0||commit_ack!=0||page_ready!=0||!write_req||loader_error)$fatal(1,"startup gated boundary failed");$display("TEST_PASS actual HFXL loader mode detected, writer pending page_ready0; timing rawACK consumed with physicalreads0 stickyfault0 before first pendingcommit");end else begin
 wait(fault);#1;if(commit_ack!==0||n==0||b.engine.local_fault!==1||page_ready!=0||!write_req||!layer_mode||loader_error)$fatal(1,"unexpected cause");$display("REPRODUCED default path unsafe for HFXL startup: physicalreads%0d engine_local_fault%0d stickyfault%0d",n,b.engine.local_fault,fault);end
 $finish;end
 initial begin #2000000;$fatal(1,"startup reproduction timeout");end
endmodule
