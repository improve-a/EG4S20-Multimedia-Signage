`timescale 1ns/1ps
// Actual reset_sync and frame_read_write; FIFO boundary stubs below do not
// model storage. fault50_extract is copied byte-for-byte from current top.
module timing_reset_fault_tb;
 reg c50=0,cs=0,cm=0,cv=0,arst=0;
 always #10 c50=~c50;
 initial begin #1;forever #5 cs=~cs;end
 initial begin #3;forever #12.5 cm=~cm;end
 initial begin #7;forever #20 cv=~cv;end
 wire sr,mr,vr;reset_sync s(cs,arst,sr),m(cm,arst,mr),v(cv,arst,vr);
 reg we=0,re=0,dv=0,sdr_valid=0;
 wire safety;wire[2:0]fs;
 frame_read_write dut(.rst(arst),.mem_clk(cm),.write_clk(cs),.read_clk(cv),
 .Sdr_init_done(1'b0),.Sdr_init_ref_vld(1'b0),.Sdr_busy(1'b0),
 .write_req(1'b0),.read_req(1'b0),.write_en(we),.read_en(re),
 .display_valid_video(dv),.Sdr_rd_en(sdr_valid),.Sdr_rd_dout(32'd0),
 .write_data(32'd0),.read_source_ready(1'b0),.read_source_busy(1'b0),
 .read_source_physical_busy(1'b0),.write_linear(1'b0),.fifo_fault(safety),.fault_sources(fs),
 .read_addr_0(21'd0),.read_addr_1(21'd0),.read_addr_2(21'd0),.read_addr_3(21'd0),
 .write_addr_0(21'd0),.write_addr_1(21'd0),.write_addr_2(21'd0),.write_addr_3(21'd0),
 .read_addr_index(2'd0),.write_addr_index(2'd0),.read_len(21'd0),.write_len(21'd0));
 reset_contract p0(cs,arst,sr,dut.write_reset),p1(cm,arst,mr,dut.mem_reset),p2(cv,arst,vr,dut.read_reset);
 reg scene=0,panel=0,tag=0;reg[3:0]state=4'd6;
 wire[3:0]display_state;wire[5:0]observed_meta,observed_sync;
 wire[5:0]sources={scene,panel,tag,fs};
 fault50_extract f(c50,arst,scene,panel,tag,fs,state,display_state,observed_meta,observed_sync);
 reg legacy0=0,legacy1=0;integer checks=0,resets=0,sticky_checks=0,latency_checks=0;
 // Differential oracle: prior scalar2FF OR pipeline, independently driven by
 // actual fault outputs. New vector pipeline must retain exact sampled latency.
 always @(posedge c50 or posedge arst)begin
  if(arst)begin legacy0<=0;legacy1<=0;end
  else begin legacy0<=|sources;legacy1<=legacy0;end
  #0.002;
  if(display_state!==(legacy1?4'ha:state))$fatal(1,"fault aggregation cycle/priority mismatch t=%0t got=%h old=%b",$time,display_state,legacy1);
  if(safety!==(fs[2]|fs[1]|fs[0]))$fatal(1,"existing frame safety OR changed");
  checks=checks+1;
 end
 task pulse_reset(input real hold_ns,input real release_wait);
 begin
  #1.3;arst=1;resets=resets+1;
  #0.002;if({sr,mr,vr,dut.write_reset,dut.mem_reset,dut.read_reset}!==6'b111111)$fatal(1,"async assertion missed");
  #(hold_ns);arst=0;#(release_wait);
  if({sr,mr,vr,dut.write_reset,dut.mem_reset,dut.read_reset}!==6'b000000)$fatal(1,"reset release incomplete");
 end endtask
 integer i;
 initial begin
  pulse_reset(4.7,100.1);
  // Varied subcycle phases and reassert before a slowclock has released.
  for(i=0;i<9;i=i+1)begin
   #(i*1.17);pulse_reset(0.11+i*0.37,90.3);
  end
  #2.1;arst=1;resets=resets+1;#0.13;arst=0;#6.2;arst=1;resets=resets+1;#0.19;arst=0;#100;
  // Explicit2edge destination latency for each nonframe fault and all together.
  for(i=0;i<4;i=i+1)begin
   @(negedge c50);case(i)0:scene=1;1:panel=1;2:tag=1;3:begin scene=1;panel=1;tag=1;end endcase
   @(posedge c50);#0.003;if(display_state!==state)$fatal(1,"fault asserted too early");
   @(posedge c50);#0.003;if(display_state!==4'ha)$fatal(1,"fault asserted too late");latency_checks=latency_checks+1;
   @(negedge c50);scene=0;panel=0;tag=0;
   @(posedge c50);#0.003;if(display_state!==4'ha)$fatal(1,"fault dropped too early");
   @(posedge c50);#0.003;if(display_state!==state)$fatal(1,"fault failed to drop");
  end
  // Drive the actual producer predicates, rather than force fault registers.
  @(negedge cs);force dut.wr_full=1;we=1;
  @(posedge cs);#0.003;we=0;release dut.wr_full;
  if(fs!==3'b001||!safety)$fatal(1,"write overflow source mapping");
  repeat(6)@(posedge c50);#0.003;if(fs!==1||display_state!==4'ha)$fatal(1,"write overflow not sticky");sticky_checks=sticky_checks+1;
  pulse_reset(0.4,100);
  @(negedge cv);force dut.rd_empty=1;dv=1;re=1;
  @(posedge cv);#0.003;dv=0;re=0;release dut.rd_empty;
  if(fs!==3'b010||!safety)$fatal(1,"read underflow source mapping");
  repeat(6)@(posedge c50);#0.003;if(fs!==2||display_state!==4'ha)$fatal(1,"read underflow not sticky");sticky_checks=sticky_checks+1;
  pulse_reset(1.9,100);
  @(negedge cm);force dut.rd_full=1;sdr_valid=1;
  @(posedge cm);#0.003;sdr_valid=0;release dut.rd_full;
  if(fs!==3'b100||!safety)$fatal(1,"memory FIFO source mapping");
  repeat(6)@(posedge c50);#0.003;if(fs!==4||display_state!==4'ha)$fatal(1,"memory fault not sticky");sticky_checks=sticky_checks+1;
  // Simultaneous source assertions around unrelated clock edges accumulate.
  scene=1;panel=1;tag=1;force dut.wr_full=1;force dut.rd_empty=1;we=1;dv=1;re=1;
  #90;we=0;dv=0;re=0;release dut.wr_full;release dut.rd_empty;
  if(fs!==3'b111||sources!==6'b111111||display_state!==4'ha)$fatal(1,"simultaneous fault lost");
  scene=0;panel=0;tag=0;#80;if(fs!==7||!safety||display_state!==4'ha)$fatal(1,"sticky fault lost after transient cleared");
  pulse_reset(0.71,100);
  if(fs!==0||safety||display_state!==state)$fatal(1,"fault reset did not restore normal status");
  $display("TEST_PASS timing_reset_fault resets=%0d sampled_checks=%0d latency_cases=%0d sticky_sources=%0d",resets,checks,latency_checks,sticky_checks);$finish;
 end
 initial begin #20000;$fatal(1,"watchdog");end
endmodule
module reset_contract(input clock,arst,outer_reset,inner_reset);
 integer edges=0;realtime last_edge=0;reg armed=0;
 always @(posedge clock or posedge arst)begin
  if(arst)begin edges=0;armed=1;end
  else if(armed)begin edges=edges+1;last_edge=$realtime;end
  #0.001;
  if(armed&&outer_reset!==(arst||edges<2))$fatal(1,"external reset release edge contract");
  if(armed&&inner_reset!==(arst||edges<2))$fatal(1,"frame internal reset release edge contract");
 end
 always @(negedge outer_reset or negedge inner_reset)
  if(armed&&$realtime-last_edge>0.0015)$fatal(1,"reset released outside receiving posedge");
endmodule
// Storage payload and occupancy are outside this test's scope. Only boundary
// flags are injected by force at actual frame producer predicate inputs.
module wfifo_32_32_512(input clkr,clkw,rst,we,re,input[31:0]di,output empty_flag,full_flag,output[8:0]wrusedw,rdusedw,output[31:0]dout);
 assign empty_flag=0;assign full_flag=0;assign wrusedw=0;assign rdusedw=0;assign dout=0;
endmodule
module rfifo_32_32_512(input clkr,clkw,rst,we,re,input[31:0]di,output empty_flag,full_flag,output[8:0]wrusedw,rdusedw,output[31:0]dout);
 assign empty_flag=0;assign full_flag=0;assign wrusedw=0;assign rdusedw=0;assign dout=0;
endmodule
