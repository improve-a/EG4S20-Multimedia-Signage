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
module sd_card_top #(parameter SPI_LOW_SPEED_DIV=248,INIT_TIMEOUT_CYCLES=200000000,RESPONSE_TIMEOUT_BYTES=65535,TOKEN_TIMEOUT_BYTES=65535,SPI_HIGH_SPEED_DIV=2)(
 input clk,rst,output SD_nCS,SD_DCLK,SD_MOSI,input SD_MISO,output sd_init_error,sd_sec_read_error,output[3:0]sd_error_code,output reg sd_init_done,
 input sd_sec_read,input[31:0]sd_sec_read_addr,output reg[7:0]sd_sec_read_data,output reg sd_sec_read_data_valid,sd_sec_read_end,
 input sd_sec_write,input[31:0]sd_sec_write_addr,input[7:0]sd_sec_write_data,output sd_sec_write_data_req,sd_sec_write_end);
 reg[7:0]block[0:511];integer card,got,seek_result,init_count=0,index=0,state=0,sectors=0;reg[31:0]latched_lba=0;
 assign SD_nCS=state==0;assign SD_DCLK=0;assign SD_MOSI=1;assign sd_init_error=0;assign sd_sec_read_error=0;assign sd_error_code=0;assign sd_sec_write_data_req=0;assign sd_sec_write_end=0;
 initial begin sd_init_done=0;sd_sec_read_data=0;sd_sec_read_data_valid=0;sd_sec_read_end=0;card=$fopen("card.img","rb");if(!card)$fatal(1,"offlinecardimageopen");end
 always@(posedge clk)begin
  sd_sec_read_data_valid<=0;sd_sec_read_end<=0;
  if(rst)begin sd_init_done<=0;init_count=0;state=0;index=0;end
  else begin
   if(!sd_init_done)begin if(init_count==63)sd_init_done<=1;else init_count=init_count+1;end
   if(sd_sec_write)$fatal(1,"unexpectedSDwrite; image model is readonly");
   case(state)
    0:if(sd_init_done&&sd_sec_read)begin
     latched_lba=sd_sec_read_addr;seek_result=$fseek(card,sd_sec_read_addr*512,0);if(seek_result!=0)$fatal(1,"cardseekLBA%0d",sd_sec_read_addr);
     got=$fread(block,card);if(got!=512)$fatal(1,"cardsectorLBA%0d bytes%0d",sd_sec_read_addr,got);index=0;state=1;sectors=sectors+1;
     if(sectors<=3||sectors%2048==0)$display("LEAF_SD_READ sectorcount%0d LBA%0d first%02h%02h%02h%02h time%0t",sectors,latched_lba,block[0],block[1],block[2],block[3],$time);
    end
    1:begin sd_sec_read_data<=block[index];sd_sec_read_data_valid<=1;if(index==511)state=2;else index=index+1;end
    2:begin sd_sec_read_end<=1;state=3;end
    3:if(!sd_sec_read)state=0;
   endcase
  end
 end
endmodule
module sdram(input Clk,Clk_sft,Rst,output reg Sdr_init_done,output Sdr_init_ref_vld,Sdr_busy,
 input App_wr_en,input[20:0]App_wr_addr,input[3:0]App_wr_dm,input[31:0]App_wr_din,input App_rd_en,input[20:0]App_rd_addr,output Sdr_rd_en,output[31:0]Sdr_rd_dout);
 reg[31:0]memory[0:614399];reg[9:0]valid_pipe=0;reg[319:0]data_pipe=0;
 reg refresh_pending=0,refresh_active=0;integer init_count=0,cycles=0,refresh_left=0,refresh_count=0,request_count=0,reads=0,writes=0,responses=0,i;
 assign Sdr_init_ref_vld=refresh_pending||refresh_active;assign Sdr_busy=refresh_active;assign Sdr_rd_en=valid_pipe[9];assign Sdr_rd_dout=data_pipe[319:288];
 initial begin Sdr_init_done=0;end
 initial for(i=0;i<614400;i=i+1)memory[i]=32'hdeadbeef;
 always@(posedge Clk)begin
  if(Rst)begin Sdr_init_done<=0;init_count=0;valid_pipe<=0;data_pipe<=0;cycles=0;refresh_pending<=0;refresh_active<=0;end
  else begin
   if(!Sdr_init_done)begin if(init_count==63)Sdr_init_done<=1;else init_count=init_count+1;end
   cycles=cycles+1;valid_pipe<={valid_pipe[8:0],App_rd_en};data_pipe<={data_pipe[287:0],App_rd_en?memory[App_rd_addr]:32'd0};
   if(valid_pipe[9])responses=responses+1;
   if(cycles%601==0)begin if(refresh_pending||refresh_active)$fatal(1,"refreshscheduleoverlap");refresh_pending<=1;request_count=request_count+1;end
   if(refresh_active)begin if(App_rd_en||App_wr_en||valid_pipe!=0)$fatal(1,"memoryacceptedopduringrefresh");if(refresh_left==1)begin refresh_active<=0;refresh_left=0;end else refresh_left=refresh_left-1;end
   else if(refresh_pending&&!App_rd_en&&!App_wr_en&&valid_pipe==0)begin refresh_pending<=0;refresh_active<=1;refresh_left=20;refresh_count=refresh_count+1;end
   if(App_rd_en&&App_wr_en)$fatal(1,"readwritecollision");
   if(App_rd_en)begin if(App_rd_addr>=614400)$fatal(1,"readaddr%0d",App_rd_addr);reads=reads+1;end
   if(App_wr_en)begin if(App_wr_addr>=614400||App_wr_dm!=0)$fatal(1,"writeaddr/mask%0d/%h",App_wr_addr,App_wr_dm);memory[App_wr_addr]<=App_wr_din;writes=writes+1;end
  end
 end
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
