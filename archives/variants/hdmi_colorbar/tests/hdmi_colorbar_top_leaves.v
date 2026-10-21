`timescale 1ns/1ps
// External/protected leaves only. Never initializes expected video data.
module system_clocks(input refclk,reset,output reg extlock,output reg clk0_out,clk1_out,clk2_out);
 initial begin extlock=0;clk0_out=0;clk1_out=0;clk2_out=0;end
 always#5 clk0_out=~clk0_out;always#12.5 clk1_out=~clk1_out;initial begin#6.25;forever#12.5 clk2_out=~clk2_out;end
 initial begin#1000;extlock=1;end
endmodule
module video_clocks(input refclk,reset,output reg extlock,output reg clk0_out,clk1_out);
 initial begin extlock=0;clk0_out=0;clk1_out=0;end
 always#20 clk0_out=~clk0_out;always#4 clk1_out=~clk1_out;initial begin#1000;extlock=1;end
endmodule
// Both external media/memory leaves stay unavailable: no valid image exists.
module sd_card_top #(parameter SPI_LOW_SPEED_DIV=248,INIT_TIMEOUT_CYCLES=200000000,RESPONSE_TIMEOUT_BYTES=65535,TOKEN_TIMEOUT_BYTES=65535,SPI_HIGH_SPEED_DIV=2)(
 input clk,rst,output SD_nCS,SD_DCLK,SD_MOSI,input SD_MISO,output sd_init_error,sd_sec_read_error,output[3:0]sd_error_code,output sd_init_done,
 input sd_sec_read,input[31:0]sd_sec_read_addr,output[7:0]sd_sec_read_data,output sd_sec_read_data_valid,sd_sec_read_end,
 input sd_sec_write,input[31:0]sd_sec_write_addr,input[7:0]sd_sec_write_data,output sd_sec_write_data_req,sd_sec_write_end);
 assign SD_nCS=1;assign SD_DCLK=0;assign SD_MOSI=1;assign sd_init_error=0;assign sd_sec_read_error=0;assign sd_error_code=0;assign sd_init_done=0;
 assign sd_sec_read_data=0;assign sd_sec_read_data_valid=0;assign sd_sec_read_end=0;assign sd_sec_write_data_req=0;assign sd_sec_write_end=0;
endmodule
module sdram(input Clk,Clk_sft,Rst,output Sdr_init_done,Sdr_init_ref_vld,Sdr_busy,
 input App_wr_en,input[20:0]App_wr_addr,input[3:0]App_wr_dm,input[31:0]App_wr_din,input App_rd_en,input[20:0]App_rd_addr,output Sdr_rd_en,output[31:0]Sdr_rd_dout);
 assign Sdr_init_done=0;assign Sdr_init_ref_vld=0;assign Sdr_busy=0;assign Sdr_rd_en=0;assign Sdr_rd_dout=0;
endmodule
module hdmi_1_4b_transmitter_core_wrapper #(parameter DEVICE="EG",HTOTAL=800,HSA=96,HFP=16,HBP=48,HACTIVE=640,VTOTAL=525,VSA=2,VFP=10,VBP=33,VACTIVE=480,VIDEO_VIC=1,VIDEO_TPG="Disable",VIDEO_FORMAT="RGB",AUDIO_SAMPLE_RATE="48K",IIC_SCL_DIV=250)(
 input I_pixel_clk,I_rst,I_edid_read_trig,output O_edid_read_valid,output[7:0]O_edid_read_data,
 input I_axis_s_user,I_axis_s_valid,I_axis_s_last,input[23:0]I_axis_s_data,output O_axis_s_ready,
 input I_audio_valid,input[23:0]I_audio_left_data,I_audio_right_data,input I_acr_valid,input[19:0]I_acr_cts,I_acr_n,
 output O_video_locked,O_ddc_scl,inout IO_ddc_sda,output[9:0]O_ch0_tmds_data,O_ch1_tmds_data,O_ch2_tmds_data,O_clk_tmds_data);
 // No protected video locking, packetization, TMDS or PHY behavior is claimed.
 assign O_edid_read_valid=I_edid_read_trig;assign O_edid_read_data=0;assign O_axis_s_ready=1;assign O_video_locked=0;assign O_ddc_scl=1;assign IO_ddc_sda=1'bz;
 assign O_ch0_tmds_data=0;assign O_ch1_tmds_data=0;assign O_ch2_tmds_data=0;assign O_clk_tmds_data=0;
endmodule
module hdmi_phy_wrapper #(parameter DEVICE="EG")(
 input I_pixel_clk,I_serial_clk,I_rst,input[9:0]I_tmds_channel_0,I_tmds_channel_1,I_tmds_channel_2,I_tmds_channel_clk,output O_tmds_ch0_p,O_tmds_ch1_p,O_tmds_ch2_p,O_tmds_clk_p);
 assign O_tmds_ch0_p=0;assign O_tmds_ch1_p=0;assign O_tmds_ch2_p=0;assign O_tmds_clk_p=0;
endmodule
