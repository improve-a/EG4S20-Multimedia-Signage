`timescale 1ns/1ps
// Runs the actual frozen adapter, not a Python transcription or HDMI IP model.
// Synthetic ready is observed ONLY by the checker: this DUT has no ready input.
module tb;
 reg clk=0, rst=1, vs=0, de=0;
 reg [23:0] rgb=0;
 reg synthetic_ready=1;
 wire av,au,al; wire [23:0] data;
 video_rgb_to_axis_640x480 dut(clk,rst,vs,de,rgb,au,av,al,data);
 always #20 clk=~clk;
 integer beats=0,users=0,lasts=0,stalls=0,changed_after_stall=0;
 reg previous_stall=0; reg [23:0] previous_data=0;
 always @(posedge clk) begin
  #1;
  if(rst)begin previous_stall=0;previous_data=0;end
  else begin
   if(previous_stall && av && data!=previous_data)
    changed_after_stall=changed_after_stall+1;
   if(av)begin
    if(data!==beats+1)begin $display("SOURCE_SEQUENCE_ERROR got=%d expected=%d",data,beats+1);$fatal(1);end
    beats=beats+1;users=users+au;lasts=lasts+al;
    if(al !== ((beats%640)==0))begin $display("LAST_ERROR beat=%d",beats);$fatal(1);end
    if(!synthetic_ready)stalls=stalls+1;
   end
   previous_stall=av&&!synthetic_ready;previous_data=data;
  end
 end
 integer row,x;
 initial begin
  repeat(4)@(negedge clk);rst=0;vs=1;
  repeat(5)@(negedge clk);
  for(row=0;row<2;row=row+1)begin
   for(x=0;x<640;x=x+1)begin
    @(negedge clk);de=1;rgb=row*640+x+1;
    synthetic_ready=!(row==0 && x>=100 && x<104);
   end
   @(negedge clk);de=0;rgb=0;synthetic_ready=1;
   repeat(160)@(negedge clk);
  end
  repeat(3)@(negedge clk);
  if(beats!=1280 || users!=1 || lasts!=2 || stalls!=4 || changed_after_stall!=4)$fatal(1,"unexpected observed behavior");
  $display("ACTUAL_RTL_OBSERVATION_PASS beats=%0d users=%0d lasts=%0d synthetic_stalls=%0d data_changes_after_stall=%0d",beats,users,lasts,stalls,changed_after_stall);
  $display("BOUNDARY: validates free-running adapter behavior; NOT an actual HDMI receiver failure or AXI protocol correctness PASS.");
  $finish;
 end
endmodule
