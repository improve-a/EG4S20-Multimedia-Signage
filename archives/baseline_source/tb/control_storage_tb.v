`timescale 1ns/1ps
// Controller-only integration test. Stubbed storage produces explicit protocol events;
// full SPI/BMP and SDRAM data tests are owned separately by Storage & Video.
module control_storage_tb;
  reg clk=0;
  always #5 clk=~clk;
  reg rst=1, next_key=1, auto_key=1, pause_key=1;
  reg write_toggle=0, ack_toggle=0, storage_fault=0;
  wire display_valid, muted, auto_mode, paused, commit;
  wire [1:0] write_buf, candidate;
  wire [3:0] state_code;
  integer cycles=0, loads=0, last_load_cycle=0, resume_cycle=0, phase=0;
  sd_card_bmp #(.CLK_FREQ_HZ(1000), .DEBOUNCE_MS(5), .LONG_PRESS_MS(40)) dut (
    .clk(clk),.rst(rst),.key_next(next_key),.key_auto(auto_key),.key_pause_mute(pause_key),
    .bmp_width(16'd640),.bmp_height(16'd480),.display_valid(display_valid),.state_code(state_code),
    .audio_muted(muted),.auto_mode_out(auto_mode),.paused_out(paused),
    .write_finish_toggle(write_toggle),.write_buf_idx(write_buf),.disp_buf_idx(candidate),
    .commit_toggle(commit),.display_commit_ack_toggle(ack_toggle),.storage_fault_async(storage_fault),
    .write_req(),.write_req_ack(1'b0),.write_en(),.write_data(),
    .SD_nCS(),.SD_DCLK(),.SD_MOSI(),.SD_MISO(1'b1));
  task fail; input [8*120-1:0] why;
    begin
      $display("FAIL control_storage_tb phase=%0d cycle=%0d loads=%0d: %0s",phase,cycles,loads,why);
      $display("STATE ready=%b busy=%b commit_pending=%b fault=%h next_pending=%b",dut.bmp_ready,dut.load_busy,dut.commit_pending,dut.fault_code,dut.next_req_pending);
      $fatal(1);
    end
  endtask
  task wait_cycles; input integer n; begin repeat(n) @(negedge clk); end endtask
  task wait_loads;
    input integer target;
    integer timeout;
    begin
      timeout=0;
      while(loads<target && timeout<4000) begin wait_cycles(1); timeout=timeout+1; end
      if(loads!=target) fail("load request missing/duplicated");
    end
  endtask
  task next_press; begin next_key=0; wait_cycles(12); next_key=1; wait_cycles(12); end endtask
  task pause_press; begin pause_key=0; wait_cycles(12); pause_key=1; wait_cycles(12); end endtask
  task source_done;
    begin
      // load_start is a registered request. The mock consumes it on the next
      // rising edge and only then becomes busy. Never overwrite that acceptance
      // with an earlier hierarchical completion assignment in the same cycle.
      while(dut.load_start_pulse) wait_cycles(1);
      if(dut.bmp_read_m0.ready !== 1'b0) fail("mock completed before load acceptance");
      dut.bmp_read_m0.load_done=1; dut.bmp_read_m0.ready=1;
      wait_cycles(1); dut.bmp_read_m0.load_done=0;
    end
  endtask
  task write_done; begin write_toggle=~write_toggle; wait_cycles(5); end endtask
  task wait_commit;
    input prior;
    integer timeout;
    begin
      timeout=0;
      while(commit==prior && timeout<30) begin wait_cycles(1); timeout=timeout+1; end
      if(commit==prior) fail("no commit after source and write completion");
    end
  endtask
  task acknowledge; begin ack_toggle=commit; wait_cycles(5); end endtask
  reg old_commit;
  always @(posedge clk) begin
    #1;
    if(rst) begin cycles=0; loads=0; last_load_cycle=0; end
    else begin
      cycles=cycles+1;
      if(dut.load_start_pulse) begin loads=loads+1; last_load_cycle=cycles; end
    end
  end
  initial begin
    phase=1;
    wait_cycles(3); rst=0;
    wait_loads(1); old_commit=commit;
    // The original ready signal can still be high after start. It is not completion.
    wait_cycles(20);
    if(commit!=old_commit || display_valid) fail("early ready committed incomplete first image");
    write_done;
    wait_cycles(10);
    if(commit!=old_commit) fail("write-only completion committed image");
    source_done; wait_commit(old_commit);
    if(candidate!=0 || display_valid) fail("first candidate/valid before ack incorrect");
    next_press; next_press;
    if(loads!=1 || display_valid) fail("old front freed before frame ack");
    acknowledge; wait_loads(2);
    if(!display_valid || write_buf!=1) fail("ack did not release back buffer one");
    old_commit=commit;
    source_done; wait_cycles(20);
    if(commit!=old_commit) fail("source-only completion committed image");
    write_done; wait_commit(old_commit);
    if(candidate!=1) fail("second image candidate incorrect");
    wait_cycles(30);
    if(loads!=2) fail("new load launched before second frame ack");
    acknowledge; wait_cycles(30);
    if(loads!=2) fail("busy-period key presses were not coalesced");
    auto_key=0; wait_cycles(12); auto_key=1; wait_cycles(12);
    if(!auto_mode) fail("auto mode not enabled");
    wait_cycles(1000); pause_press;
    if(!paused) fail("short press did not pause");
    wait_cycles(3500);
    if(loads!=2) fail("auto advanced while paused");
    next_press; wait_loads(3);
    if(write_buf!=0 || !paused) fail("manual paused step/back buffer incorrect");
    old_commit=commit; source_done; write_done; wait_commit(old_commit); acknowledge;
    wait_cycles(100);
    if(loads!=3 || !paused) fail("manual step resumed auto unexpectedly");
    // Record the actual pause release edge, then require a full three-second period.
    pause_key=0; wait_cycles(12); pause_key=1;
    while(paused) wait_cycles(1);
    resume_cycle=cycles;
    wait_loads(4);
    if(last_load_cycle-resume_cycle<3000 || last_load_cycle-resume_cycle>3004)
      fail("resume did not restart the complete 3-second slideshow interval");
    old_commit=commit;
    dut.bmp_read_m0.error_code=1;
    wait_cycles(10);
    if(state_code!=4'hc || commit!=old_commit || !display_valid)
      fail("bad BMP did not preserve old display with diagnostic C");
    wait_cycles(6000);
    if(loads!=4 || commit!=old_commit) fail("fault retried or changed ownership unsafely");
    // Scan may have found pictures before a final transport error. The sticky
    // error must win over scan_done/ready on that same edge, with no stray load.
    phase=2;
    dut.bmp_read_m0.inject_scan_error=1;
    rst=1; write_toggle=0; ack_toggle=0; wait_cycles(3); rst=0; wait_cycles(30);
    if(loads!=0 || state_code!=4'hd || display_valid)
      fail("scan completion error launched a load before fault latched");
    // A memory FIFO failure beats simultaneous source/write completion.
    phase=3;
    dut.bmp_read_m0.inject_scan_error=0;
    rst=1; write_toggle=0; ack_toggle=0; wait_cycles(3); rst=0;
    wait_loads(1); old_commit=commit;
    source_done; storage_fault=1; write_done; wait_cycles(10);
    if(state_code!=4'ha || commit!=old_commit || display_valid)
      fail("FIFO fault did not block completion/commit");
    storage_fault=0; wait_cycles(10);
    if(state_code!=4'ha || commit!=old_commit) fail("FIFO fault was not sticky");
    phase=4;
    rst=1; write_toggle=0; ack_toggle=0; wait_cycles(3); rst=0;
    wait_loads(1); old_commit=commit; source_done; write_done; wait_commit(old_commit); acknowledge;
    if(!display_valid || state_code==4'ha) fail("reset did not recover FIFO fault");
    // A fault arriving after a request, but before its ack, must not release
    // the old front even if a late acknowledgement subsequently arrives.
    phase=5;
    next_press; wait_loads(2);
    old_commit=commit; source_done; write_done; wait_commit(old_commit);
    old_commit=commit; storage_fault=1; wait_cycles(5); acknowledge; wait_cycles(10);
    if(state_code!=4'ha || dut.front_buf_idx!=0 || !display_valid || commit!=old_commit || loads!=2)
      fail("fault during pending commit accepted late ack or released old front");
    $display("TEST_PASS control_storage_tb source_write_both_required frame_ack back_buffer busy_coalesce pause manual_step auto_3s error_preserves_front scan_error_priority fifo_fault_blocks_commit fault_pending_ack reset_recovery");
    $finish;
  end
  initial begin #200000; fail("timeout"); end
endmodule

module bmp_read (
  input clk,rst,scan_start,
  output reg ready,
  input [31:0] scan_start_sector,scan_max_sector,
  input [2:0] scan_target_count,
  output reg scan_done,scan_found_valid,
  output reg [31:0] scan_found_sector,
  output reg [2:0] scan_found_total,
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
      else if(scan_phase>=1 && scan_phase<=3) begin
        scan_found_valid<=1;
        scan_found_sector<=24704+(scan_phase-1)*1920;
        scan_found_total<=scan_phase;
        scan_phase<=scan_phase+1;
      end else if(scan_phase==4) begin
        scan_done<=1; ready<=1; scan_phase<=5;
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
