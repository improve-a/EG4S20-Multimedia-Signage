`timescale 1ns/1ps
module exhibit_resource_mode_tb;
reg clk=0;always#5 clk=~clk;reg rst=1,k2=1,wr=0,ack=0,mode_valid=0,layer_mode=0;
reg[5:0]ready=63;wire[5:0]pages;wire catalog,commit,valid,done;wire[2:0]candidate,committed;
integer loads=0,events=0;reg seen=0;
sd_card_bmp #(.CLK_FREQ_HZ(1000),.DEBOUNCE_MS(5),.LONG_PRESS_MS(40),.ENABLE_EXHIBIT(1),.ENABLE_LAYER_RESOURCES(1))dut(
.clk(clk),.rst(rst),.key_next(k2),.key_auto(1'b1),.key_pause_mute(1'b1),.bmp_width(16'd640),.bmp_height(16'd480),
.write_finish_toggle(wr),.display_commit_ack_toggle(ack),.commit_toggle(commit),.storage_fault_async(1'b0),.write_req_ack(1'b0),.SD_MISO(1'b1),
.panel_active(1'b0),.panel_req(1'b0),.panel_addr(32'd0),.compare_panels_ready(1'b0),.resource_page_ready(ready),
.resource_mode_valid(mode_valid),.resource_layer_mode(layer_mode),.resource_catalog_ready(catalog),.page_ready(pages),.cache_preload_done(done),
.candidate_page(candidate),.committed_page(committed),.display_valid(valid));
always@(posedge clk)begin #1;if(dut.load_start_pulse)loads=loads+1;end
task tick;input integer n;begin repeat(n)@(negedge clk);end endtask
task tap;begin k2=0;tick(12);k2=1;tick(12);end endtask
task compare;begin k2=0;tick(70);k2=1;tick(12);end endtask
task check;input integer i;begin tick(3);if(dut.load_idx!=i||dut.load_sector!=24704+i*1920)$fatal(1,"ordinaryfallbackorder");end endtask
task finish;begin while(dut.load_start_pulse)tick(1);dut.bmp_read_m0.load_done=1;dut.bmp_read_m0.ready=1;tick(1);dut.bmp_read_m0.load_done=0;wr=~wr;tick(12);end endtask
integer i;
initial begin
 tick(4);rst=0;tick(25);if(!catalog)$fatal(1,"catalogmustprecedeprobe");tap;tap;tick(100);
 if(loads!=0||pages!=0||valid||dut.commit_pending||dut.desired_page!=2)$fatal(1,"unresolvedmodeadvertised");
 mode_valid=1;layer_mode=0;tick(8);check(0);if(loads!=1||pages!=0)$fatal(1,"plainmodewrongreadyprovider");
 finish;check(1);if(pages!=1||dut.commit_pending)$fatal(1,"plainready0target2");
 finish;check(2);if(pages!=3||dut.commit_pending)$fatal(1,"plainready1target2");
 finish;tick(4);if(!dut.commit_pending||candidate!=2||valid)$fatal(1,"plaintarget2notreleased");
 for(i=3;i<6;i=i+1)begin check(i);finish;end
 if(pages!=63||loads!=6||!done||candidate!=2||valid)$fatal(1,"plain6cacheorcandidateownership");
 ack=commit;tick(8);if(committed!=2||!valid)$fatal(1,"plainACK");
 compare;tick(8);if(!dut.commit_pending||!dut.exhibit_candidate_compare||candidate!=2||loads!=6)$fatal(1,"plaincompareblockedbypanels");ack=commit;tick(8);
 // A resolved HFXL pack uses external finished writes; it never starts BMP.
 rst=1;ack=0;wr=0;mode_valid=0;layer_mode=1;tick(4);loads=0;rst=0;tick(35);
 if(!catalog||loads||pages||dut.commit_pending||valid)$fatal(1,"earlylayerflagsbeforemode");
 mode_valid=1;tick(8);if(loads||pages!=63||!dut.commit_pending||candidate!=0||valid)$fatal(1,"resolvedlayerprovider");
 ack=commit;tick(8);if(!valid||committed!=0)$fatal(1,"layerACK");
 $display("TEST_PASS exhibit_resource_mode lateprobe blocksloadcommit catalogbeforeprobe plainBMPfallback6pages sourceANDwritefinish targetready actualACK layeredexternalready noordinaryload");$finish;
end
initial begin #1000000;$fatal(1,"timeout");end
endmodule
module bmp_read #(parameter ENABLE_SCALE=0,ENABLE_HFXL=0) (
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
