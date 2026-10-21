`timescale 1ns/1ps
// Scoped control test: frozen raster and AXIS RTL, with a 28-cycle VS/DE
// projection of video_delay(21), transition(1), pixel_adjust(1), OSD(5).
// This does not model SDRAM, RGB, HDMI receiver, PLL or the PHY.
module tb;
 reg clk=0,rst=1;
 always #20 clk=~clk;
 wire hs,vs,de,req;
 video_timing_data timing(clk,rst,req,1'b1,hs,vs,de);
 reg [27:0] vpipe=0,dpipe=0;
 always @(posedge clk)
  if(rst)begin vpipe<=0;dpipe<=0;end
  else begin vpipe<={vpipe[26:0],vs};dpipe<={dpipe[26:0],de};end
 wire user,valid,last;wire [23:0] data;
 video_rgb_to_axis_640x480 axis(clk,rst,vpipe[27],dpipe[27],24'h123456,user,valid,last,data);
 integer cycle=0,sof=-1,row_start=-1,last_end=-1000;
 integer frames=0,rows=0,pixels=0,x=0,total_rows=0;
 integer normal_collisions=0,late_collisions=0,row_checks=0,frame_checks=0;
 reg prev=0;
 reg nominal_ready,late_ready;
 always @(negedge clk) if(!rst)begin
  cycle=cycle+1;
  // Synthetic sink: ready falls only AFTER TLAST.
  // Case A returns before the next row. Case B returns four pixels late.
  nominal_ready=!(cycle>last_end && cycle<=last_end+160);
  late_ready=!(cycle>last_end && cycle<=last_end+164);
  if(valid&&!nominal_ready)normal_collisions=normal_collisions+1;
  if(valid&&!late_ready)late_collisions=late_collisions+1;
  if((user||last)&&!valid)$fatal(1,"qualifier without valid");
  if(valid)begin
   if(!prev)begin
    x=0;
    if(!user && row_start>=0)begin
     if(cycle-row_start!=800)$fatal(1,"line_space %0d",cycle-row_start);
     row_checks=row_checks+1;
    end
    row_start=cycle;
   end
   if(user)begin
    if(prev||x!=0)$fatal(1,"SOF position");
    if(sof>=0)begin
     if(cycle-sof!=420000 || rows!=480 || pixels!=307200)
      $fatal(1,"frame contract delta%0d rows%0d pixels%0d",cycle-sof,rows,pixels);
     frame_checks=frame_checks+1;
    end
    sof=cycle;frames=frames+1;rows=0;pixels=0;
   end
   if(last!==(x==639))$fatal(1,"TLAST position %0d",x);
   if(last)begin rows=rows+1;total_rows=total_rows+1;last_end=cycle;end
   pixels=pixels+1;x=x+1;
  end else if(prev&&x!=640)$fatal(1,"line_length %0d",x);
  prev=valid;
  if(frames==4)begin
   if(normal_collisions!=0||late_collisions!=3*479*4)$fatal(1,"ready probe %0d/%0d",normal_collisions,late_collisions);
   $display("UNIT_SIM_PASS frame_checks=%0d line_space_checks=%0d complete_rows=%0d line_length=640 line_space=800 frame_cycles=420000",frame_checks,row_checks,total_rows);
   $display("READY_PROBE nominal_collisions=%0d late_ready_collisions=%0d; synthetic sink only, not evidence real HDMI deasserts ready this long",normal_collisions,late_collisions);
   $finish;
  end
 end
 initial begin repeat(5)@(negedge clk);rst=0;#60000000;$fatal(1,"timeout");end
endmodule
