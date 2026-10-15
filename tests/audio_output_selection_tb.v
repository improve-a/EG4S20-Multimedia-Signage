`timescale 1ns/1ps
module audio_output_selection_tb;
reg clk=0;always #20 clk=~clk;
reg rst=1,tv=0;reg[23:0]tl=24'h800001,tr=24'h7fffff,wl=0,wr=0;
reg[3:0]status=1,volume=8;wire av,selected;wire[23:0]left,right;
integer i,checks=0;
audio_output_mux dut(clk,rst,tv,tl,tr,wl,wr,status,volume,av,left,right,selected);
function[23:0]scaled;
 input[23:0]p;input[3:0]vol;integer gain,value;
 begin gain=vol>8?8:vol;value=$signed(p)*gain;
 scaled=value>=0?value/8:-((-value+7)/8);
 end
endfunction
task check;
 input sel;input[23:0]expected_l,expected_r;
 begin @(posedge clk);#1;
  if(selected!==sel||av!==tv||left!==expected_l||right!==expected_r)$fatal(1,"mux status=%h vol=%0d sel=%0d outputs %h/%h expected %h/%h",status,volume,selected,left,right,expected_l,expected_r);
  checks=checks+1;@(negedge clk);
 end
endtask
initial begin
 check(0,scaled(tl,volume),scaled(tr,volume));rst=0;
 // Entire legal and out-of-range volume domain, signed floor and saturation.
 for(i=0;i<16;i=i+1)begin volume=i;tv=i%2;check(0,scaled(tl,volume),scaled(tr,volume));end
 // An early paused scan is not evidence that a WAV file exists.
 status=4;repeat(8)begin tv=~tv;check(0,scaled(tl,volume),scaled(tr,volume));end
 status=4'hb;repeat(8)begin tv=~tv;check(0,scaled(tl,volume),scaled(tr,volume));end
 // Real prefill silence selects WAV; later PCM is already volume-scaled.
 status=2;wl=0;wr=0;check(1,0,0);
 status=3;wl=24'hc00000;wr=24'h400000;volume=0;check(1,wl,wr);
 status=4;check(1,wl,wr);
 status=5;wl=0;wr=0;check(1,0,0);
 status=4'he;check(1,0,0);status=4'hb;check(1,0,0);status=0;check(1,0,0);
 rst=1;volume=4;check(0,scaled(tl,volume),scaled(tr,volume));rst=0;status=1;check(0,scaled(tl,volume),scaled(tr,volume));
 // Direct PLAY/EOF entries also establish a WAV source independently of PAUSE.
 status=3;check(1,wl,wr);rst=1;check(0,scaled(tl,volume),scaled(tr,volume));rst=0;
 status=5;check(1,wl,wr);
 $display("TEST_PASS actual audio_output_mux: %0d checks, early PAUSE4 then NO_WAV keeps tone, prefill/PLAY/EOF selection, sticky silence on EOF/error, reset recovery, signed gain volume0..15 clamp, WAV gain bypass, valid passthrough",checks);$finish;
end
endmodule
