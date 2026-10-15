`timescale 1ns/1ps
module video_refresh_tb;
reg clk=0;always #4 clk=~clk;reg rst=1,req=0,refresh=0;wire rack,wack,re,we,rf,wf,rb,wb,rclear,wclear;wire[20:0]ra,wa;
integer rcount=0,wcount=0,hold_count=0;reg injected=0,prev_re=0,prev_we=0;
frame_fifo_read #(.BURST_SIZE(256)) rd(.rst(rst),.mem_clk(clk),.Sdr_init_done(1'b1),.Sdr_init_ref_vld(refresh),.Sdr_busy(refresh),.Sdr_rd_en(1'b0),.App_wr_busy(1'b0),.O_rd_busy(rb),.App_rd_en(re),.App_rd_addr(ra),.read_req(req),.read_req_ack(rack),.read_finish(rf),.read_addr_0(21'd0),.read_addr_1(21'd0),.read_addr_2(21'd0),.read_addr_3(21'd0),.read_addr_index(2'd0),.read_len(21'd256),.fifo_aclr(rclear),.wrusedw(10'd0));
frame_fifo_write #(.BURST_SIZE(256),.WRITE_V_FLIP(0)) wr(.rst(rst),.mem_clk(clk),.Sdr_init_done(1'b1),.Sdr_init_ref_vld(refresh),.Sdr_busy(refresh),.App_rd_busy(1'b0),.O_wr_busy(wb),.App_wr_en(we),.App_wr_addr(wa),.write_req(req),.write_req_ack(wack),.write_finish(wf),.write_addr_0(21'd0),.write_addr_1(21'd0),.write_addr_2(21'd0),.write_addr_3(21'd0),.write_addr_index(2'd0),.write_len(21'd256),.fifo_aclr(wclear),.rdusedw(10'd400));
always @(posedge clk)if(!rst)begin
 // Adversarial but legal timing: IP begins refresh after CHECK saw idle,
 // before the registered first App enable reaches the IP interface.
 if(!injected && rd.state==2 && wr.state==2)begin refresh<=1;injected<=1;hold_count<=0;end
 else if(refresh)begin hold_count<=hold_count+1;if(hold_count==10)refresh<=0;end
 if(((re&&!prev_re)||(we&&!prev_we)) && refresh)$fatal(1,"first App beat collides with refresh rd=%b wr=%b",re,we);
 if(re)begin if(ra!=rcount)$fatal(1,"read address skipped");rcount=rcount+1;end
 if(we)begin if(wa!=wcount)$fatal(1,"write address skipped");wcount=wcount+1;end
 prev_re<=re;prev_we<=we;
end
initial begin
 repeat(5)@(negedge clk);rst=0;req=1;wait(rack&&wack);@(negedge clk);req=0;
 wait(rcount==256 && wcount==256);repeat(20)@(negedge clk);
 if(!injected||rcount!=256||wcount!=256)$fatal(1,"incomplete refresh case");
 $display("TEST_PASS video_refresh first-beat stall, then 256 contiguous beats each controller");$finish;
end
initial begin #100000;$fatal(1,"refresh test timeout rd=%0d wr=%0d",rcount,wcount);end
endmodule
