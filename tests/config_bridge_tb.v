`timescale 1ns/1ps
module config_bridge_tb;
reg sc=0,dc=0;always #5 sc=~sc;initial begin #3;forever #20 dc=~dc;end
reg sr=1,dr=1,frame=0;reg [46:0] source={7'h55,8'h00,8'hff,8'h00,8'hff,8'h00};
wire [46:0] dest;
frame_config_bridge #(.WIDTH(47),.RESET_VALUE({7'h55,8'h00,8'hff,8'h00,8'hff,8'h00})) dut(sc,sr,source,dc,dr,frame,dest);
integer cycles=0,updates=0,k;reg [46:0] old_dest={7'h55,8'h00,8'hff,8'h00,8'hff,8'h00};reg sampled_frame;
always @(negedge dc)begin cycles=cycles+1;frame=(cycles%27)==0;end
always @(posedge dc)begin
 sampled_frame=frame;#1;
 if(!dr)begin
  if(dest!=old_dest && !sampled_frame)$fatal(1,"configuration changed inside frame");
  if(dest[46:40]!==7'h55 || dest[39:32]!==dest[23:16] || dest[39:32]!==dest[7:0] || dest[39:32]!==~dest[31:24] || dest[39:32]!==~dest[15:8])$fatal(1,"torn bundle %h",dest);
  if(dest!=old_dest)updates=updates+1;
 end
 old_dest=dest;
end
initial begin
 #100;@(negedge sc);sr=0;dr=0;
 // Updates intentionally occur faster than mailbox acknowledgement. Atomic
 // snapshots may skip intermediate values but must never contain torn fields.
 for(k=1;k<=250;k=k+1)begin
  @(negedge sc);source={7'h55,k[7:0],~k[7:0],k[7:0],~k[7:0],k[7:0]};
  if(k%9==0)repeat(7)@(negedge sc);
 end
 @(negedge sc);source={7'h55,8'h55,8'haa,8'h55,8'haa,8'h55};
 repeat(240)@(negedge dc);
 if(dest!=={7'h55,8'h55,8'haa,8'h55,8'haa,8'h55})$fatal(1,"final snapshot not delivered %h",dest);
 if(updates<2)$fatal(1,"insufficient updates %0d",updates);
 $display("TEST_PASS config_bridge %0d destination cycles %0d atomic frame commits",cycles,updates);$finish;
end
endmodule
