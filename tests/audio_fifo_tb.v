`timescale 1ns/1ps
module audio_fifo_tb;
reg wc=0,rc=0;always #5 wc=~wc;always #13 rc=~rc;
reg wr=1,rr=1,we=0,re=0;reg[31:0]wd=0;wire[31:0]rd;wire full,empty;wire[5:0]level;
integer i;
audio_async_fifo #(.ADDRESS_BITS(5)) dut(wc,wr,we,wd,full,level,rc,rr,re,rd,empty);
initial begin
 repeat(4)@(negedge wc);wr=0;rr=0;
 for(i=0;i<32;i=i+1)begin @(negedge wc);we=1;wd=32'h12340000+i;end
 @(negedge wc);we=0;
 if(!full||level!=32)$fatal(1,"FIFO full boundary level=%0d",level);
 we=1;wd=32'hdeadbeef;@(negedge wc);we=0;
 repeat(4)@(negedge rc);
 for(i=0;i<32;i=i+1)begin
  if(empty)$fatal(1,"FIFO early empty at %0d",i);
  re=1;@(negedge rc);
  if(rd!=32'h12340000+i)$fatal(1,"FIFO order %0d data %h",i,rd);
 end
 re=0;if(!empty)$fatal(1,"FIFO empty boundary");
 repeat(4)@(negedge wc);if(level!=0||full)$fatal(1,"CDC read pointer did not settle");
 // Wrap both binary pointers and verify signed payload remains unmodified.
 for(i=0;i<20;i=i+1)begin @(negedge wc);we=1;wd=32'h80007fff+i;end
 @(negedge wc);we=0;repeat(4)@(negedge rc);
 for(i=0;i<20;i=i+1)begin re=1;@(negedge rc);if(rd!=32'h80007fff+i)$fatal(1,"wrap order %0d",i);end
 re=0;if(!empty)$fatal(1,"wrap empty");
 $display("TEST_PASS asynchronous FIFO: full/empty, overflow suppression, pointer CDC, ordered data and pointer wrap");$finish;
end
endmodule
