`timescale 1ns/1ps
module exhibit_control_tb;
reg clk=0;always #5 clk=~clk;
reg rst=1,k2=1,k3=1,k4=1,wr=0,ack=0,panels_available=1;
wire cm,commit,cc,ct,reverse_candidate;wire[1:0]candidate;wire[2:0]cp,dp;wire[15:0]period_ms;
integer loads=0,manuals=0,cycles=0,commits=0;reg was_commit=0;
sd_card_bmp #(.CLK_FREQ_HZ(1000),.DEBOUNCE_MS(5),.LONG_PRESS_MS(40),.ENABLE_EXHIBIT(1)) dut(
.clk(clk),.rst(rst),.key_next(k2),.key_auto(k4),.key_pause_mute(k3),
.bmp_width(16'd640),.bmp_height(16'd480),.content_mode(cm),
.write_finish_toggle(wr),.display_commit_ack_toggle(ack),.commit_toggle(commit),
.disp_buf_idx(candidate),.storage_fault_async(1'b0),.write_req_ack(1'b0),.SD_MISO(1'b1),
.panel_active(1'b0),.panel_req(1'b0),.panel_addr(32'd0),.compare_panels_ready(panels_available),.candidate_page(cp),.candidate_reverse(reverse_candidate),.candidate_compare(cc),.committed_page(dp),.committed_toggle(ct),
.interval_milliseconds(period_ms));
always @(posedge clk)begin #1;cycles=cycles+1;
if(dut.load_start_pulse)loads=loads+1;
if(dut.key_next_press)manuals=manuals+1;
if(!rst && ct!=was_commit)begin commits=commits+1;was_commit=ct;end
end
task tick;input integer n;begin repeat(n)@(negedge clk);end endtask
task tap2;begin k2=0;tick(12);k2=1;tick(12);end endtask
task previous;begin k2=0;k4=0;tick(12);k2=1;tick(12);k4=1;tick(12);end endtask
task hold2;begin k2=0;tick(80);k2=1;tick(12);end endtask
task check;input integer idx;begin tick(3);
if(dut.load_idx!==idx || dut.load_sector!==24704+idx*1920)
$fatal(1,"load idx expected%0d got%0d",idx,dut.load_idx);
end endtask
task finish_load;reg old;begin
while(dut.load_start_pulse)tick(1);old=commit;
dut.bmp_read_m0.load_done=1;dut.bmp_read_m0.ready=1;tick(1);dut.bmp_read_m0.load_done=0;wr=~wr;tick(10);

end endtask
task acknowledge;begin ack=commit;tick(8);end endtask
integer i,base_cycles,base_loads;reg [2:0]held_candidate;reg held_compare;reg [1:0]held_toggle;
initial begin
 tick(3);rst=0;tick(25);check(0);
 if(dut.img_found_count!=8 || !dut.auto_mode_out || period_ms!=5400)$fatal(1,"six pages /8slot /default period");
 if(dut.page_ready!=0)$fatal(1,"incomplete source advertised");
 finish_load;tick(5);
 if(dut.page_ready!=1 || cp!=0 || !dut.commit_pending || commits!=0)$fatal(1,"first ready /early commit");
 // Background writer1 cannot change the held candidate0 before actual ACK.
 check(1);if(cp!=0)$fatal(1,"background loading changed candidate");acknowledge;
 for(i=1;i<6;i=i+1)begin check(i);finish_load;tick(5);end
 if(dut.page_ready!=63 || loads!=6)$fatal(1,"six immutable pages not cached");
 // Six pages form one normal group and wrap5->0. NoSD traffic after preloading.
 for(i=1;i<=6;i=i+1)begin tap2;tick(4);
  if(cp!=i%6)$fatal(1,"candidate metadata expected%0d got%0d",i%6,cp);
  acknowledge;if(dp!=i%6)$fatal(1,"committed metadata");
 end
 if(loads!=6)$fatal(1,"cached navigation rereadSD");
 // Candidate remains owned. Rapid presses accumulate only latest desired page.
 tap2;held_candidate=cp;tap2;tap2;
 if(dp!=0 || cp!=held_candidate || !dut.commit_pending)$fatal(1,"late ACK candidate ownership");
 acknowledge;tick(5);if(cp!=3)$fatal(1,"latest request not selected");acknowledge;
 if(dp!=3)$fatal(1,"latest request not committed");
 // Compare uses current page and only ready paired sources, no historical group.
 hold2;tick(5);if(!cc || cp!=3 || !cm)$fatal(1,"comparison candidate");
 hold2;if(cc!=1 || cp!=3)$fatal(1,"candidate compare changed beforeACK");
 acknowledge;tick(5);if(cc)$fatal(1,"latest compare toggle not submitted");acknowledge;
 if(loads!=6)$fatal(1,"compare rereadSD");
 wait(dut.exhibit_elapsed_ms==16'd100);base_cycles=cycles;base_loads=loads;
 tick(5298);if(dut.commit_pending)$fatal(1,"early autoplay");
 tick(8);if(!dut.commit_pending || cp!=4)$fatal(1,"5400ms deadline missed");
 tick(1800);if(dut.exhibit_elapsed_ms<1700)$fatal(1,"ACK reset period");acknowledge;
 if(dut.exhibit_elapsed_ms<1700 || loads!=6)$fatal(1,"commit added transfertime/reloaded");
 // Previous retains explicit direction even when fast mergedrequests skipneighbours.
 previous;tick(5);if(cp!=3 || !reverse_candidate)$fatal(1,"previous from4to3");
 previous;previous;if(cp!=3 || !reverse_candidate)$fatal(1,"previous candidate ownership");
 acknowledge;tick(5);if(cp!=1 || !reverse_candidate)$fatal(1,"mergedprevious lostdirection");acknowledge;
 previous;tick(5);if(cp!=0 || !reverse_candidate)$fatal(1,"previous1to0");acknowledge;
 previous;tick(5);if(cp!=5 || !reverse_candidate)$fatal(1,"previous0to5wrap");acknowledge;
 tap2;tick(5);if(cp!=0 || reverse_candidate)$fatal(1,"next5to0wrapdirection");acknowledge;
 // Request page2 before its resources are ready. Page0/1 mustnot create staleevents.
 rst=1;wr=0;ack=0;tick(4);rst=0;tick(25);check(0);
 tap2;tap2;if(dut.desired_page!=2)$fatal(1,"queuedlatestbeforefirstload");
 finish_load;tick(5);if(dut.commit_pending)$fatal(1,"committedwrongreadytarget0");check(1);
 finish_load;tick(5);if(dut.commit_pending)$fatal(1,"committedwrongreadytarget1");check(2);
 finish_load;tick(5);if(!dut.commit_pending || cp!=2)$fatal(1,"late target2notreleased");acknowledge;
 panels_available=0;hold2;tick(20);
 if(dut.commit_pending || cc)$fatal(1,"comparisoncommittedbeforeprotectedpanelsready");
 panels_available=1;tick(5);if(!dut.commit_pending || !cc || cp!=2)$fatal(1,"panelreadydidnotreleasecompare");
 $display("TEST_PASS exhibit_control sixpages8slots immutable_cache background_load manual_auto real_commit late_ready fast_press_wrap compare_metadata5400ms protectedpanelsreadygate previousnextwrap explicitmergeddirection");$finish;
end
initial begin #2000000;$fatal(1,"timeout");end
endmodule
module bmp_read #(parameter ENABLE_SCALE=0) (
  input [1:0] scale_mode,
  input clk,rst,scan_start,
  output reg ready,
  input [31:0] scan_start_sector,scan_max_sector,
  input [3:0] scan_target_count,
  output reg scan_done,scan_found_valid,
  output reg [31:0] scan_found_sector,
  output reg [3:0] scan_found_total,
  input load_start,load_abort,
  input [31:0] load_sector,
  output reg load_done,
  output reg [3:0] error_code,
  input sd_init_done,
  output [3:0] state_code,
  input [15:0] bmp_width,bmp_height,
  output write_req,
  input write_req_ack,
  output sd_sec_read,
  output [31:0] sd_sec_read_addr,
  input [7:0] sd_sec_read_data,
  input sd_sec_read_data_valid,sd_sec_read_end,sd_sec_read_error,
  output bmp_data_wr_en,
  output [23:0] bmp_data
);
  assign state_code=4'd1;
  assign write_req=0; assign sd_sec_read=0; assign sd_sec_read_addr=0;
  assign bmp_data_wr_en=0; assign bmp_data=0;
  integer scan_phase=0;
  reg inject_scan_error=0;
  always @(posedge clk) begin
    if(rst) begin
      scan_phase<=0; scan_done<=0; scan_found_valid<=0; scan_found_sector<=0;
      scan_found_total<=0; ready<=1; load_done<=0; error_code<=0;
    end else begin
      scan_found_valid<=0;
      if(scan_start) begin ready<=0; scan_phase<=1; end
      else if(scan_phase>=1 && scan_phase<=8) begin
        scan_found_valid<=1;
        scan_found_sector<=24704+(scan_phase-1)*1920;
        scan_found_total<=scan_phase;
        scan_phase<=scan_phase+1;
      end else if(scan_phase==9) begin
        scan_done<=1; ready<=1; scan_phase<=10;
        if(inject_scan_error) error_code<=3;
      end
      if(load_start) begin ready<=0; error_code<=0; end
    end
  end
endmodule
module sd_card_top (
  input clk,rst,
  output SD_nCS,SD_DCLK,SD_MOSI,
  input SD_MISO,
  output sd_init_done,sd_init_error,
  output [3:0] sd_error_code,
  input sd_sec_read,
  input [31:0] sd_sec_read_addr,
  output [7:0] sd_sec_read_data,
  output sd_sec_read_data_valid,sd_sec_read_end,sd_sec_read_error,
  input sd_sec_write,
  input [31:0] sd_sec_write_addr,
  input [7:0] sd_sec_write_data,
  output sd_sec_write_data_req,sd_sec_write_end
);
  assign sd_init_done=~rst; assign sd_init_error=0; assign sd_error_code=0;
  assign SD_nCS=1; assign SD_DCLK=0; assign SD_MOSI=1;
  assign sd_sec_read_data=0; assign sd_sec_read_data_valid=0;
  assign sd_sec_read_end=0; assign sd_sec_read_error=0;
  assign sd_sec_write_data_req=0; assign sd_sec_write_end=0;
endmodule
