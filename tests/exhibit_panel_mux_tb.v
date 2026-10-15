`timescale 1ns/1ps
module exhibit_panel_mux_tb;
reg clk=0;always#5 clk=~clk;
reg rst=1,active=0,preq=0,areq=0;
wire[7:0]pdata,adata;wire pv,pe,px,av,ae,ax,agrant;
reg[7:0]data=0;reg sv=0,se=0,sx=0;
integer pbytes=0,abytes=0,pends=0,aends=0,busy=0,pos=0,requestcount=0;
reg[31:0]held;reg wasaudio;reg transport_checks=1;
sd_card_bmp #(.CLK_FREQ_HZ(1000),.ENABLE_EXHIBIT(1),.ENABLE_AUDIO(1),.DEBOUNCE_MS(5))dut(
.clk(clk),.rst(rst),.key_next(1'b1),.key_auto(1'b1),.key_pause_mute(1'b1),.bmp_width(16'd640),.bmp_height(16'd480),
.write_finish_toggle(1'b0),.display_commit_ack_toggle(1'b0),.storage_fault_async(1'b0),.write_req_ack(1'b0),.SD_MISO(1'b1),
.panel_active(active),.panel_req(preq),.panel_addr(32'd600),.panel_data(pdata),.panel_valid(pv),.panel_end(pe),.panel_error(px),
.compare_panels_ready(1'b0),.audio_sector_req(areq),.audio_sector_addr(32'd900),.audio_sector_urgent(1'b1),
.audio_sector_grant(agrant),.audio_sector_data(adata),.audio_sector_valid(av),.audio_sector_end(ae),.audio_sector_error(ax));
always@(negedge clk)begin
 sv=0;se=0;
 if(!rst)begin
  if(busy==0 && dut.physical_req)begin held=dut.physical_addr;pos=0;busy=1;requestcount=requestcount+1;end
  else if(busy==1)begin
   if(!dut.physical_req || dut.physical_addr!=held)$fatal(1,"transactionpreempted");
   if(pos<512)begin sv=1;data=pos[7:0]^(held==600?8'h50:8'ha0);pos=pos+1;end
   else begin se=1;busy=2;end
  end else if(busy==2 && !dut.physical_req)busy=0;
 end
end
always@(posedge clk)if(!rst && transport_checks)begin
 if(agrant)areq<=0;
 if(pv)begin if(pdata!==(pbytes[7:0]^8'h50))$fatal(1,"panelbyte");pbytes=pbytes+1;end
 if(av)begin if(adata!==(abytes[7:0]^8'ha0))$fatal(1,"audiobyte");abytes=abytes+1;end
 if(pe)begin pends=pends+1;preq<=0;end
 if(ae)aends=aends+1;
 if(active && (dut.sd_sec_read_data_valid || dut.sd_sec_read_end || dut.sd_sec_read_error))$fatal(1,"panelresponsesleakedintobmp");
 if(px || ax)$fatal(1,"unexpectederror");
end
initial begin
 force dut.physical_data=data;force dut.physical_valid=sv;force dut.physical_end=se;force dut.physical_error=sx;
 repeat(4)@(negedge clk);rst=0;
 // Cacheownership is modeledcomplete; onlythearbiterandnewpanelmuxarerealhere.
 force dut.page_ready=6'b111111;force dut.load_busy=0;force dut.scan_done=1;
 active=1;preq=1;areq=1;
 wait(pends==1 && aends==1);repeat(10)@(negedge clk);
 if(pbytes!=512 || abytes!=512 || requestcount!=2)$fatal(1,"sectorcount/order");
 // Response bundle is registered together only on the BMP path. Panel
 // responses remain direct; ownership switches occur after idle sector drain.
 transport_checks=0;active=0;repeat(2)@(negedge clk);
 force dut.bmp_client_data=8'h3c;force dut.bmp_client_valid=1;
 force dut.bmp_client_end=1;force dut.bmp_client_error=1;
 #1;if(dut.sd_sec_read_data_valid || dut.sd_sec_read_end || dut.sd_sec_read_error || pv)$fatal(1,"BMPnotregistered");
 @(posedge clk);#1;
 if(!dut.sd_sec_read_data_valid || !dut.sd_sec_read_end || !dut.sd_sec_read_error || dut.sd_sec_read_data!==8'h3c || pv)$fatal(1,"BMPbundlealignment");
 @(negedge clk);force dut.bmp_client_data=8'hf1;force dut.bmp_client_valid=0;
 force dut.bmp_client_end=0;force dut.bmp_client_error=0;
 #1;if(!dut.sd_sec_read_data_valid || !dut.sd_sec_read_end || !dut.sd_sec_read_error || dut.sd_sec_read_data!==8'h3c)$fatal(1,"BMPbundlehold");
 @(posedge clk);#1;
 if(dut.sd_sec_read_data_valid || dut.sd_sec_read_end || dut.sd_sec_read_error || dut.sd_sec_read_data!==8'hf1)$fatal(1,"BMPbundleclear");
 @(negedge clk);active=1;force dut.bmp_client_data=8'ha5;force dut.bmp_client_valid=1;
 force dut.bmp_client_end=1;force dut.bmp_client_error=1;
 #1;if(!pv || !pe || !px || pdata!==8'ha5)$fatal(1,"paneldirectbundle");
 @(posedge clk);#1;if(dut.sd_sec_read_data_valid || dut.sd_sec_read_end || dut.sd_sec_read_error)$fatal(1,"panelBMPisolationregistered");
 release dut.bmp_client_data;release dut.bmp_client_valid;release dut.bmp_client_end;release dut.bmp_client_error;
 $display("TEST_PASS exhibit_panel_mux existingphysicalSDarbiter audio512panel512 isolation stableLBA nosecondreader BMPbundle1cycle data_valid_end_error paneldirect");$finish;
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
