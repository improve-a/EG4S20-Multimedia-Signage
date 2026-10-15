`timescale 1ns/1ps
module content_modes_tb;
reg clk=0; always #5 clk=~clk;
reg rst=1,k2=1,k3=1,k4=1,wr=0,ack=0;
wire cm,commit; wire [1:0] candidate;
integer loads=0,steps=0,switches=0;
reg waiting_ack=0, saved_commit=0; reg [1:0] saved_candidate=0;
sd_card_bmp #(.CLK_FREQ_HZ(1000),.DEBOUNCE_MS(5),.LONG_PRESS_MS(40),
.ENABLE_CONTENT_MODES(1),.AUTO_PERIOD_SECONDS(1)) dut(
.clk(clk),.rst(rst),.key_next(k2),.key_auto(k4),.key_pause_mute(k3),
.bmp_width(16'd640),.bmp_height(16'd480),.content_mode(cm),
.write_finish_toggle(wr),.display_commit_ack_toggle(ack),.commit_toggle(commit),
.disp_buf_idx(candidate),.storage_fault_async(1'b0),.write_req_ack(1'b0),.SD_MISO(1'b1));
always @(posedge clk) begin #1;
if(rst) waiting_ack=0;
else begin
 if(dut.load_start_pulse && dut.display_valid && dut.write_buf_idx==dut.front_buf_idx)
 $fatal(1,"load overwrote owned front buffer");
 if(waiting_ack && dut.commit_pending && (candidate!==saved_candidate || commit!==saved_commit))
 $fatal(1,"candidate changed while awaiting display acknowledgement");
 if(!dut.commit_pending)waiting_ack=0;
 else if(!waiting_ack)begin waiting_ack=1;saved_candidate=candidate;saved_commit=commit;end
end
if(dut.load_start_pulse)loads=loads+1;
if(dut.key_next_press)steps=steps+1;
if(dut.content_mode_changed)switches=switches+1;
end
 task tick;input integer n;begin repeat(n)@(negedge clk);end endtask
 task tap;begin k2=0;tick(12);k2=1;tick(12);end endtask
 task hold;begin k2=0;tick(80);k2=1;tick(12);end endtask
 task check;input integer idx;begin
 tick(3);if(dut.load_idx!==idx || dut.load_sector!==24704+idx*1920)
 $fatal(1,"index/sector expected %0d got %0d/%0d",idx,dut.load_idx,dut.load_sector);
 end endtask
 task finish_load;reg old;begin
 while(dut.load_start_pulse)tick(1);
 old=commit;dut.bmp_read_m0.load_done=1;dut.bmp_read_m0.ready=1;tick(1);
 dut.bmp_read_m0.load_done=0;wr=~wr;tick(10);
 if(commit==old)$fatal(1,"missing commit");
 end endtask
 task acknowledge;begin ack=commit;tick(8);end endtask
initial begin
 tick(3);rst=0;tick(25);check(0);
 if(dut.img_found_count!=8)$fatal(1,"capacity8 scan count");
 finish_load;acknowledge;
 tap;check(1);finish_load;acknowledge;
 tap;check(0);
 // Switch during source load. No abort, no premature candidate change.
 hold;if(!cm || steps!=2 || switches!=1 || loads!=3)$fatal(1,"long gesture or busy switch");
 finish_load;
 // Switch back while old candidate waits for display ack; preserve ownership.
 hold;if(cm || steps!=2 || switches!=2 || loads!=3 || !dut.commit_pending)
 $fatal(1,"pending commit ownership/long exclusivity");
 // Two switches before releasing the owned commit coalesce to latest daily mode.
 hold;hold;
 if(cm || loads!=3 || switches!=4)$fatal(1,"rapid toggles did not preserve latest mode/ownership");
 acknowledge;check(0);finish_load;acknowledge;
 hold;check(2);finish_load;acknowledge;
 tap;check(3);finish_load;acknowledge;
 tap;check(4);finish_load;acknowledge;
 tap;check(5);finish_load;acknowledge;
 tap;check(2);finish_load;acknowledge;
 // Auto stays inside emergency group and daily group after switch.
 k4=0;tick(12);k4=1;tick(12);tick(1010);check(3);finish_load;acknowledge;
 hold;check(0);finish_load;acknowledge;
 tick(1010);check(1);finish_load;acknowledge;
 tick(1010);check(0);
 $display("TEST_PASS content_modes_tb capacity8 daily_manual emergency_manual daily_auto emergency_auto busy_switch pending_commit long_exclusive");$finish;
end
initial begin #1000000;$fatal(1,"timeout");end
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
