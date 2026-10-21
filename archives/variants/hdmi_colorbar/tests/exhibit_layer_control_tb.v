`timescale 1ns/1ps
module exhibit_layer_control_tb;
reg clk=0;always#5 clk=~clk;reg rst=1,k2=1,k4=1,ack=0,panels=0;reg[5:0]ready=0;
wire commit,reverse_candidate,compare_candidate,committed_toggle,valid,catalog,done;
wire[2:0]candidate,committed;wire[5:0]pages;
wire[31:0]s0,s1,s2,s3,s4,s5;integer loads=0,events=0;reg seen=0;
sd_card_bmp #(.CLK_FREQ_HZ(1000),.DEBOUNCE_MS(5),.LONG_PRESS_MS(40),.ENABLE_EXHIBIT(1),.ENABLE_LAYER_RESOURCES(1))dut(
.clk(clk),.rst(rst),.key_next(k2),.key_auto(k4),.key_pause_mute(1'b1),.bmp_width(16'd640),.bmp_height(16'd480),
.write_finish_toggle(1'b0),.display_commit_ack_toggle(ack),.commit_toggle(commit),.storage_fault_async(1'b0),.write_req_ack(1'b0),.SD_MISO(1'b1),
.panel_active(1'b0),.panel_req(1'b0),.panel_addr(32'd0),.compare_panels_ready(panels),
.candidate_page(candidate),.candidate_reverse(reverse_candidate),.candidate_compare(compare_candidate),.committed_page(committed),.committed_toggle(committed_toggle),
.display_valid(valid),.resource_page_ready(ready),.resource_mode_valid(1'b1),.resource_layer_mode(1'b1),.resource_catalog_ready(catalog),.page_ready(pages),.cache_preload_done(done),
.resource_sector0(s0),.resource_sector1(s1),.resource_sector2(s2),.resource_sector3(s3),.resource_sector4(s4),.resource_sector5(s5));
always@(posedge clk)begin #1;
 if(dut.load_start_pulse)loads=loads+1;
 if(!rst&&committed_toggle!=seen)begin events=events+1;seen=committed_toggle;end
 if(loads!=0)$fatal(1,"layer mode started ordinary BMP load");
end
task tick;input integer n;begin repeat(n)@(negedge clk);end endtask
task tap2;begin k2=0;tick(12);k2=1;tick(12);end endtask
task tap4;begin k4=0;tick(12);k4=1;tick(12);end endtask
task prev;begin k2=0;k4=0;tick(12);k2=1;tick(12);k4=1;tick(12);end endtask
task compare;begin k2=0;tick(70);k2=1;tick(12);end endtask
task complete;begin ack=commit;tick(8);end endtask
reg held;integer before_event;
initial begin
 tick(4);if(catalog||pages||valid)$fatal(1,"resetadvertisedresource");rst=0;tick(25);
 if(!catalog||s0!=24704||s1!=26624||s2!=28544||s3!=30464||s4!=32384||s5!=34304)$fatal(1,"sixsectorcatalog");
 tap4;tap2;tap2;if(dut.desired_page!=2||dut.commit_pending||valid)$fatal(1,"earlyrequestedtarget");
 ready=1;tick(8);if(pages!=1||dut.commit_pending||valid)$fatal(1,"ready0wrongtarget");
 ready=3;tick(8);if(pages!=3||dut.commit_pending||valid)$fatal(1,"ready1wrongtarget");
 ready=7;tick(8);if(!dut.commit_pending||candidate!=2||valid||events!=0)$fatal(1,"late2firstcandidate");held=commit;
 tap2;tap2;ready=15;tick(20);
 if(candidate!=2||commit!=held||dut.desired_page!=4||valid||events!=0)$fatal(1,"candidatechangedbeforeACK");
 complete;tick(8);if(committed!=2||!valid||events!=1||dut.commit_pending)$fatal(1,"ACK2orunready4");
 ready=31;tick(8);if(candidate!=4||!dut.commit_pending||committed!=2||events!=1)$fatal(1,"late4candidate");held=commit;
 ready=63;tick(20);if(!done||pages!=63||commit!=held||candidate!=4||committed!=2||events!=1)$fatal(1,"allreadychangedheldcandidate");
 complete;if(committed!=4||events!=2)$fatal(1,"ACK4");
 prev;tick(8);if(candidate!=3||!reverse_candidate||!dut.commit_pending)$fatal(1,"previouslayerpage");complete;
 before_event=events;compare;tick(20);if(dut.commit_pending||compare_candidate||events!=before_event)$fatal(1,"comparebeforepanels");
 panels=1;tick(8);if(!dut.commit_pending||!compare_candidate||candidate!=3)$fatal(1,"panelreadylatecompare");complete;
 if(committed!=3||events!=before_event+1||loads!=0)$fatal(1,"layercompareACK");
 $display("TEST_PASS exhibit_layer_control sixLBAcatalog externalreadysequential late0_1_2target noBMPload immutablecandidate actualACKonlyevents rapidrequest previous comparepanelgate");$finish;
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
