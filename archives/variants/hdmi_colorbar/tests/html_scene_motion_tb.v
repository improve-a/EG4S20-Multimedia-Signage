`timescale 1ns/1ps
module html_scene_motion_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,frame_start=0,page_event=0,page_reverse=0,i_valid=0,old_layer=0;
 reg [4:0] tag=0;reg [1:0] kind=0;reg [2:0] data_index=0;
 wire valid;wire[4:0] tagout;wire signed[17:0] xo;wire signed[12:0] yo;
 wire[12:0] scale,inv;wire[7:0] alpha;wire[6:0] age;wire active;
 html_scene_motion dut(.clk(clk),.rst(rst),.frame_start(frame_start),.page_event(page_event),
  .page_reverse(page_reverse),.i_valid(i_valid),.query_tag(tag),.layer_kind(kind),.old_layer(old_layer),
  .data_index(data_index),.o_valid(valid),.query_tag_out(tagout),.x_offset_q8(xo),.y_offset_q8(yo),
  .scale_q12(scale),.inv_scale_q12(inv),.alpha(alpha),.frame_age(age),.active(active));
 integer fd,queries=0,checks=0,rev,f,k,j;
 reg[1:0] vq=0;reg[31:0] mq[0:1];
 always @(posedge clk)begin
  if(rst)begin vq=0;mq[0]=0;mq[1]=0;end
  else begin
   vq={vq[0],i_valid&&!frame_start};mq[1]=mq[0];mq[0]={9'd0,page_reverse,age,old_layer,kind,data_index,tag};
   #1;
   if(valid!==vq[1])$fatal(1,"motion two-stage query alignment");
   if(valid)begin
    if(tagout!==mq[1][4:0])$fatal(1,"motion query tag alignment");
    $fdisplay(fd,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",mq[1][18],mq[1][17:11],mq[1][10],mq[1][9:8],mq[1][7:5],tagout,xo,yo,scale,inv,alpha);
    queries=queries+1;
   end
   checks=checks+1;
  end
 end
 task step;begin @(posedge clk);#2;@(negedge clk);end endtask
 task query_frame;
 begin
  for(k=0;k<22;k=k+1)begin
   old_layer=k>=11;tag=k; j=k%11;
   kind=j<3 ? j : 3;data_index=j>=3 ? j-3 : 0;
   i_valid=1;step;
  end
  i_valid=0;repeat(3)step;
 end endtask
 initial begin
  fd=$fopen("motion_actual.csv","w");if(!fd)$fatal(1,"CSVopen");
  $fdisplay(fd,"reverse,age,old,kind,index,tag,x_q8,y_q8,scale_q12,inverse_q12,alpha");
  repeat(4)step;rst=0;repeat(2)step;
  if(age!==127||active)$fatal(1,"initial steady state");query_frame;
  // Pending event waits for the shared actualACK rather than a pixel clock.
  page_event=1;page_reverse=1;step;page_event=0;repeat(5)step;
  if(age!==127||active)$fatal(1,"motion advanced before commitACK");
  frame_start=1;step;frame_start=0;step;
  if(age!==0||!active)$fatal(1,"pending commit did not startage0");
  for(rev=0;rev<2;rev=rev+1)begin
   page_reverse=rev;page_event=1;frame_start=1;i_valid=1;step;
   page_event=0;frame_start=0;i_valid=0;step;
   if(age!==0)$fatal(1,"same-clock event+ACK must startage0");
   for(f=0;f<128;f=f+1)begin
    if(age!==f||active!==(f<93))$fatal(1,"frame-age/lifecycle mismatch f%0d got%0d",f,age);
    query_frame;
    frame_start=1;step;frame_start=0;step;
   end
   if(age!==127)$fatal(1,"age must saturate");
  end
  if(queries!=5654)$fatal(1,"query count %0d",queries);
  $fclose(fd);$display("TEST_PASS html_scene_motion two-stage5654queries,framecommit,pendingevent,reverse,age93cleanup checks%0d",checks);$finish;
 end
 initial begin #1000000;$fatal(1,"motionwatchdog");end
endmodule
