`timescale 1ns/1ps
module hdmi_colorbar_top_tb;
 reg clk=0,rst_n=0;always#10 clk=~clk;
 wire[5:0]seg_sel;wire[7:0]seg_data;wire hc,h0,h1,h2,ddc,cs,sclk,mosi;tri sda;
 top dut(.clk(clk),.rst_n(rst_n),.key1(1'b1),.key2(1'b1),.key3(1'b1),.seg_sel(seg_sel),.seg_data(seg_data),.HDMI_CLK_P(hc),.HDMI_D0_P(h0),.HDMI_D1_P(h1),.HDMI_D2_P(h2),.HDMI_DDC_SCL(ddc),.HDMI_DDC_SDA(sda),.sd_ncs(cs),.sd_dclk(sclk),.sd_mosi(mosi),.sd_miso(1'b1));
 wire ide=dut.u_video_rgb_to_axis_640x480.I_de;
 wire ivs=dut.u_video_rgb_to_axis_640x480.I_vs;
 wire[23:0]irgb=dut.u_video_rgb_to_axis_640x480.I_rgb;
 wire av=dut.u_hdmi_1_4b_transmitter_core_wrapper.I_axis_s_valid;
 wire au=dut.u_hdmi_1_4b_transmitter_core_wrapper.I_axis_s_user;
 wire al=dut.u_hdmi_1_4b_transmitter_core_wrapper.I_axis_s_last;
 wire[23:0]ad=dut.u_hdmi_1_4b_transmitter_core_wrapper.I_axis_s_data;
 reg previous_ide=0,previous_av=0,previous_hs=0,previous_vs=0,seen_sof=0;
 reg[23:0]previous_rgb=0;
 integer cycle=0,source_x=0,line_x=0,frame_pixels=0,frame_lines=0,frame_lasts=0,frames=0,sof_cycle=0;
 integer hs_fall=-1,vs_fall=-1,hperiods=0,vperiods=0,hwidths=0,vwidths=0,source_checks=0,axis_checks=0,different_from_fx=0,audio_ticks=0;
 integer bars[0:7];integer i;
 function[23:0]expected;
 input integer x;
 begin case(x/80)
  0:expected=24'hffffff;1:expected=24'hffff00;2:expected=24'h00ffff;3:expected=24'h00ff00;
  4:expected=24'hff00ff;5:expected=24'hff0000;6:expected=24'h0000ff;default:expected=24'h000000;
 endcase end endfunction
 initial begin
  for(i=0;i<8;i=i+1)bars[i]=0;
  repeat(10)@(negedge clk);rst_n=1;
  wait(dut.sys_lock_sync[1]&&dut.video_lock_sync[1]&&!dut.button_reset50);
  // Only shorten the startup counter. No clock/reset/video signal is forced.
  @(negedge clk);dut.rst_cnt=20'd999995;
 end
 always@(negedge dut.video_clk)begin
  if(dut.video_rst)begin previous_ide=0;previous_av=0;previous_rgb=0;previous_hs=0;previous_vs=0;end
  else begin
   cycle=cycle+1;
   if(dut.display_valid!==0||dut.sd_card_write_en!==0||dut.App_wr_en!==0||dut.Sdr_rd_en!==0)$fatal(1,"imagebecameavailable");
   if(ide!==dut.fx_de||ivs!==dut.fx_vs||irgb!==dut.diagnostic_rgb)$fatal(1,"actualadapterinputmiswired");
   if(av!==previous_ide||ad!==previous_rgb)$fatal(1,"actualadapteronecyclecontract");
   if(ide)begin
    if(!previous_ide)source_x=0;
    if(source_x>=640||irgb!==expected(source_x))$fatal(1,"actualsourceRGB x%0d got%h expected%h",source_x,irgb,expected(source_x));
    if(irgb!==dut.fx_rgb)different_from_fx=different_from_fx+1;
    source_checks=source_checks+1;source_x=source_x+1;
   end else if(previous_ide&&source_x!=640)$fatal(1,"sourcelinewidth%0d",source_x);
   if(previous_hs&&!dut.fx_hs)begin if(hs_fall>=0)begin if(cycle-hs_fall!=800)$fatal(1,"nativeHtotal%0d",cycle-hs_fall);hperiods=hperiods+1;end hs_fall=cycle;end
   if(!previous_hs&&dut.fx_hs&&hs_fall>=0)begin if(cycle-hs_fall!=96)$fatal(1,"nativeHsyncwidth%0d",cycle-hs_fall);hwidths=hwidths+1;end
   if(previous_vs&&!dut.fx_vs)begin if(vs_fall>=0)begin if(cycle-vs_fall!=420000)$fatal(1,"nativeVtotal%0d",cycle-vs_fall);vperiods=vperiods+1;end vs_fall=cycle;end
   if(!previous_vs&&dut.fx_vs&&vs_fall>=0)begin if(cycle-vs_fall!=1600)$fatal(1,"nativeVsyncwidth%0d",cycle-vs_fall);vwidths=vwidths+1;end
   if((au||al)&&!av)$fatal(1,"qualifierwithoutvalid");
   if(av)begin
    if(!previous_av)line_x=0;
    if(au)begin
     if(line_x!=0)$fatal(1,"SOFnotfirstcolumn");
     if(seen_sof)begin
      if(frame_pixels!=307200||frame_lines!=480||frame_lasts!=480||cycle-sof_cycle!=420000)$fatal(1,"framecontract P%0d L%0d LAST%0d total%0d",frame_pixels,frame_lines,frame_lasts,cycle-sof_cycle);
      for(i=0;i<8;i=i+1)if(bars[i]!=38400)$fatal(1,"colorcount bar%0d count%0d",i,bars[i]);
      frames=frames+1;$display("FRAME_PASS %0d pixels%0d lines%0d eachcolor38400 total420000",frames,frame_pixels,frame_lines);
      if(frames==2)begin
       if(hperiods<1000||vperiods<1||hwidths<1000||vwidths<1||different_from_fx==0)$fatal(1,"missingnativeortopcoverage");
       $display("TEST_PASS HDMI_COLORBAR_ACTUAL_TOP frames2 exactpixels614400 sourcechecks%0d axischecks%0d Hperiods%0d Vperiods%0d Hwidth96%0d Vwidth1600%0d independentRGB%0d audioticks%0d TFnotready SDRAMnotready; protectedHDMI/PHYnotqualified",source_checks,axis_checks,hperiods,vperiods,hwidths,vwidths,different_from_fx,audio_ticks);$finish;
      end
     end
     seen_sof=1;sof_cycle=cycle;frame_pixels=0;frame_lines=0;frame_lasts=0;for(i=0;i<8;i=i+1)bars[i]=0;
    end
    if(!seen_sof)$fatal(1,"pixelsbeforeSOF");
    if(au!==(frame_pixels==0)||al!==(line_x==639))$fatal(1,"SOForTLASTposition");
    if(line_x>=640||ad!==expected(line_x))$fatal(1,"actualHDMIinputRGB x%0d got%h",line_x,ad);
    bars[line_x/80]=bars[line_x/80]+1;frame_pixels=frame_pixels+1;axis_checks=axis_checks+1;
    if(al)begin frame_lines=frame_lines+1;frame_lasts=frame_lasts+1;end line_x=line_x+1;
   end else if(previous_av&&line_x!=640)$fatal(1,"axislinewidth%0d",line_x);
   if(dut.audio_valid)audio_ticks=audio_ticks+1;
   previous_ide=ide;previous_rgb=irgb;previous_av=av;previous_hs=dut.fx_hs;previous_vs=dut.fx_vs;
  end
 end
 initial begin#60000000;$fatal(1,"diagnosticwatchdog frames%0d",frames);end
endmodule
