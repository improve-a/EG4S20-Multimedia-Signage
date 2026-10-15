`timescale 1ns/1ps
module pll_frequency_tb;
 reg refclk=0,reset=1,monitor=0;
 always #10 refclk=~refclk;
 wire sd,mem,shift,pixel,serial,syslock,vidlock;
 system_clocks sp(.refclk(refclk),.reset(reset),.clk0_out(sd),.clk1_out(mem),.clk2_out(shift),.extlock(syslock));
 video_clocks vp(.refclk(refclk),.reset(reset),.clk0_out(pixel),.clk1_out(serial),.extlock(vidlock));
 integer cs=0,cm=0,ch=0,cp=0,cv=0,i;
 time pixel_edge;
 time ts=0,tm=0,th=0,tp=0,tv=0,phase_start,phase_end;
 function time ticks;input realtime ns;begin ticks=$rtoi(ns*1000.0+0.5);end endfunction
 task period_check;input time current,previous,expected;begin
  if(current-previous != expected)$fatal(1,"period mismatch measured_ps=%0d expected=%0d",current-previous,expected);
 end endtask
 always @(posedge sd) if(monitor)begin if(cs>0)period_check(ticks($realtime),ts,10000);ts=ticks($realtime);cs=cs+1;end
 always @(posedge mem)if(monitor)begin if(cm>0)period_check(ticks($realtime),tm,25000);tm=ticks($realtime);cm=cm+1;end
 always @(posedge shift)if(monitor)begin if(ch>0)period_check(ticks($realtime),th,25000);th=ticks($realtime);ch=ch+1;end
 always @(posedge pixel)if(monitor)begin
  if(cp>0)period_check(ticks($realtime),tp,40000);tp=ticks($realtime);cp=cp+1;pixel_edge=tp;
  #0.001;if(tv != pixel_edge)$fatal(1,"pixel/serial phase differs pixel_ps=%0d serial_ps=%0d",pixel_edge,tv);
 end
 always @(posedge serial)if(monitor)begin if(cv>0)period_check(ticks($realtime),tv,8000);tv=ticks($realtime);cv=cv+1;end
 initial begin
  #105 reset=0;wait(syslock===1'b1 && vidlock===1'b1);#1000;monitor=1;
  for(i=0;i<100;i=i+1)begin
   @(posedge mem);phase_start=ticks($realtime);@(posedge shift);phase_end=ticks($realtime);
   if(phase_end-phase_start != 12500)$fatal(1,"memory180 phase measured_ps=%0d",phase_end-phase_start);
  end
  #10000;
  if(!syslock || !vidlock || cp<200 || cs<1000 || cm<400 || ch<400 || cv<1000)$fatal(1,"lock/count coverage failure %0d %0d %0d %0d %0d",cs,cm,ch,cp,cv);
  monitor=0;reset=1;#100;if(syslock!==0 || vidlock!==0)$fatal(1,"lock did not clear after reset");
  reset=0;wait(syslock===1 && vidlock===1);#1000;cs=0;cm=0;ch=0;cp=0;cv=0;monitor=1;#10000;
  if(cp<200 || cs<900 || cm<350 || ch<350 || cv<1100)$fatal(1,"post-reset clock coverage insufficient");
  $display("TEST_PASS pll_frequency vendor_public_EG4_compat_model NOCOMP VCO1000 sd100 mem40_shift180 pixel25 serial125 pixel_serial_aligned reset_relock samples=%0d/%0d/%0d/%0d/%0d",cs,cm,ch,cp,cv);$finish;
 end
 initial begin #100000;$fatal(1,"PLL lock/frequency watchdog");end
endmodule
