`timescale 1ns/1ps
module exhibit_interval_tb;
reg clk=0;always#5 clk=~clk;reg rst=1,k2=1,k4=1;
wire[15:0]ms;wire[7:0]seconds;wire[3:0]fraction;wire[2:0]mode;
media_controls #(.CLK_FREQ_HZ(1000),.DEBOUNCE_MS(5),.LONG_PRESS_MS(40),.ENABLE_EXHIBIT(1))dut(
.clk(clk),.rst(rst),.key_next(k2),.key_auto(k4),.key_pause_mute(1'b1),.interval_milliseconds(ms),.interval_seconds(seconds),.interval_fraction(fraction),.mode(mode));
task tick;input integer n;begin repeat(n)@(negedge clk);end endtask
task tap2;begin k2=0;tick(12);k2=1;tick(12);end endtask
task tap4;begin k4=0;tick(12);k4=1;tick(12);end endtask
task hold4;begin k4=0;tick(70);k4=1;tick(12);end endtask
integer i,expected;
initial begin
 tick(4);rst=0;tick(8);repeat(3)hold4;if(mode!=3)$fatal(1,"intervalmode");expected=5400;
 for(i=0;i<110;i=i+1)begin tap2;expected=expected<15000?expected+100:15000;
 if(ms!=expected || seconds!=expected/1000 || fraction!=(expected%1000)/100)$fatal(1,"up carry/floor ms%0d sec%0d expected%0d",ms,seconds,expected);end
 for(i=0;i<150;i=i+1)begin tap4;expected=expected>1000?expected-100:1000;
 if(ms!=expected || seconds!=expected/1000 || fraction!=(expected%1000)/100)$fatal(1,"down borrow/floor ms%0d sec%0d expected%0d",ms,seconds,expected);end
 rst=1;tick(4);rst=0;tick(8);if(ms!=5400 || seconds!=5 || fraction!=4)$fatal(1,"resetfraction");
 $display("TEST_PASS exhibit_interval260updowncases exact100ms whole_secondcarryborrow saturation1000_15000 reset no_runtime_divider");$finish;
end
endmodule
