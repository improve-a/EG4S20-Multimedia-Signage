`timescale 1ns/1ps
// Diagnostic only: real controls and wrapper, controlled already-committed
// manager state. Tests the single-cycle hierarchical key pulse mechanism.
module media_integration_key_probe_tb;
 reg clk=0,rst=1;always #5 clk=~clk;
 integer pulses=0,starts=0;
 sd_card_bmp #(.ENABLE_SCALING(1),.ENABLE_AUDIO(1)) dut(
 .clk(clk),.rst(rst),.key_next(1'b1),.key_auto(1'b1),.key_pause_mute(1'b1),
 .bmp_width(16'd640),.bmp_height(16'd480),.display_valid(),.state_code(),
 .audio_muted(),.auto_mode_out(),.paused_out(),.control_mode(),.contrast(),.brightness(),
 .interval_seconds(),.osd_enable(),.transition_mode(),.scale_mode(),.volume(),.progress(),
 .audio_sector_req(1'b0),.audio_sector_addr(32'd0),.audio_sector_urgent(1'b0),
 .audio_sector_grant(),.audio_sector_data(),.audio_sector_valid(),.audio_sector_end(),
 .audio_sector_error(),.sd_ready_out(),.write_finish_toggle(1'b0),.write_buf_idx(),.disp_buf_idx(),
 .commit_toggle(),.display_commit_ack_toggle(1'b0),.storage_fault_async(1'b0),
 .write_req(),.write_req_ack(1'b0),.write_en(),.write_data(),.SD_nCS(),.SD_DCLK(),.SD_MOSI(),.SD_MISO(1'b1));
 always @(posedge clk)if(!rst)begin
  if(dut.key_next_press)pulses=pulses+1;
  if(dut.load_start_pulse)starts=starts+1;
  $display("PROBE t=%0t key=%b next=%b start=%b busy=%b count=%0d",$time,dut.key_next_press,dut.next_req_pending,dut.load_start_pulse,dut.load_busy,dut.img_found_count);
 end
 initial begin
  repeat(5)@(negedge clk);rst=0;
  force dut.scan_done=1;force dut.bmp_ready=1;force dut.scan_kicked=1;
  force dut.img_found_count=2;force dut.first_image_committed=1;force dut.display_valid=1;
  repeat(5)@(negedge clk);
  force dut.key_next_press=1;@(negedge clk);release dut.key_next_press;
  repeat(8)@(negedge clk);
  if(pulses!=1||starts!=1)$fatal(1,"pulse probe failed pulses=%0d starts=%0d",pulses,starts);
  $display("TEST_PASS MEDIA_KEY_PROBE one hierarchical pulse reaches real wrapper");$finish;
 end
endmodule
module sd_card_top(
 input clk,rst,output SD_nCS,SD_DCLK,SD_MOSI,input SD_MISO,
 output sd_init_done,sd_init_error,output[3:0]sd_error_code,
 input sd_sec_read,input[31:0]sd_sec_read_addr,output[7:0]sd_sec_read_data,
 output sd_sec_read_data_valid,sd_sec_read_end,sd_sec_read_error,
 input sd_sec_write,input[31:0]sd_sec_write_addr,input[7:0]sd_sec_write_data,
 output sd_sec_write_data_req,sd_sec_write_end
);
 assign sd_init_done=1;assign sd_init_error=0;assign sd_error_code=0;
 assign sd_sec_read_data=0;assign sd_sec_read_data_valid=0;assign sd_sec_read_end=0;
 assign sd_sec_read_error=0;assign sd_sec_write_data_req=0;assign sd_sec_write_end=0;
 assign SD_nCS=1;assign SD_DCLK=0;assign SD_MOSI=1;
endmodule
