`timescale 1ns/1ps
module exhibit_keys_tb;
reg clk=0;always#5 clk=~clk;
reg rst=1,k2=1,k3=1,k4=1;
wire[2:0]mode,focus;wire[1:0]scale;wire[15:0]ms;wire cmp,paused,muted,auto_mode;integer nexts=0,prevs=0,cmpchanges=0;
wire next_pulse,prev_pulse,cmpchange;
media_controls #(.CLK_FREQ_HZ(1000),.DEBOUNCE_MS(5),.LONG_PRESS_MS(40),.ENABLE_EXHIBIT(1))dut(
.clk(clk),.rst(rst),.key_next(k2),.key_auto(k4),.key_pause_mute(k3),.next_pulse(next_pulse),.prev_pulse(prev_pulse),
.content_mode(cmp),.content_mode_changed(cmpchange),.mode(mode),.zoom_focus(focus),.scale_mode(scale),
.interval_milliseconds(ms),.paused(paused),.muted(muted),.auto_mode(auto_mode));
always@(posedge clk)begin#1;if(next_pulse)nexts=nexts+1;if(prev_pulse)prevs=prevs+1;if(cmpchange)cmpchanges=cmpchanges+1;end
task tick;input integer n;begin repeat(n)@(negedge clk);end endtask
task tap2;begin k2=0;tick(12);k2=1;tick(12);end endtask
task hold2;begin k2=0;tick(70);k2=1;tick(12);end endtask
task tap4;begin k4=0;tick(12);k4=1;tick(12);end endtask
task hold4;begin k4=0;tick(70);k4=1;tick(12);end endtask
integer i;
initial begin
 tick(3);rst=0;tick(8);if(!auto_mode || ms!=5400)$fatal(1,"defaults");
 tap2;hold2;if(nexts!=1 || !cmp || cmpchanges!=1)$fatal(1,"next/compareexclusive");
 // Holding a chord consumes both single-keylongs; staggeredrelease emits onlyonce.
 k2=0;k4=0;tick(80);k2=1;tick(12);
 if(prevs!=0 || nexts!=1 || !auto_mode || !cmp || mode!=0)$fatal(1,"chord leakedbeforedualrelease");
 k4=1;tick(12);if(prevs!=1 || nexts!=1 || cmpchanges!=1 || !auto_mode || mode!=0)$fatal(1,"chord exclusivity");
 repeat(3)hold4;if(mode!=3)$fatal(1,"intervalmode");
 tap2;if(ms!=5500)$fatal(1,"interval+0.1s");tap4;if(ms!=5400)$fatal(1,"interval-0.1s");
 repeat(3)hold4;if(mode!=6)$fatal(1,"zoommode");
 tap2;if(scale!=1)$fatal(1,"2x");tap2;if(scale!=2)$fatal(1,"3x");tap2;if(scale!=0)$fatal(1,"1xwrap");
 tap4;if(scale!=2)$fatal(1,"zoomdecrement");
 for(i=1;i<=6;i=i+1)begin hold2;if(focus!=i%6 || scale!=2)$fatal(1,"focuslongexclusive");end
 if(nexts!=1 || cmpchanges!=1)$fatal(1,"zoomcreatedpageevent");
 k3=0;tick(12);k3=1;tick(12);if(!paused || muted)$fatal(1,"pause");
 k3=0;tick(70);k3=1;tick(12);if(!paused || !muted)$fatal(1,"mute");
 $display("TEST_PASS exhibit_keys physicalKEY2_KEY4_KEY3 previous_chord_stagger_longconsumed exact0.1s focus6 zoom123 long_shortexclusive pause_mute");$finish;
end
endmodule
