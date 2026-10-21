`timescale 1ns/1ps
module html_panel_loader_tb;
reg clk=0;always #5 clk=~clk;
reg rst=1,enable=0;reg[7:0] sd_data=0;reg sd_valid=0,sd_end=0,sd_error=0,write_req_ack=0,write_finish_toggle=0;
reg sd_ready=1,audio_req=0;wire[7:0]sector_data;wire sector_valid,sector_end,sector_error,sd_req;wire[31:0]sd_addr;
media_sector_arbiter arb(.clk(clk),.rst(rst),.sd_ready(sd_ready),.bmp_req(sector_req),.bmp_addr(sector_addr),.bmp_data(sector_data),.bmp_valid(sector_valid),.bmp_end(sector_end),.bmp_error(sector_error),.audio_req(audio_req),.audio_addr(32'd99999),.audio_urgent(1'b1),.audio_grant(),.audio_data(),.audio_valid(),.audio_end(),.audio_error(),.sd_req(sd_req),.sd_addr(sd_addr),.sd_data(sd_data),.sd_valid(sd_valid),.sd_end(sd_end),.sd_error(sd_error));
wire active,ready,error,sector_req,write_req,write_en;wire[31:0]sector_addr,write_data;wire[20:0]write_base,write_len;
html_panel_loader #(.TIMEOUT_CYCLES(20000)) dut(.clk(clk),.rst(rst),.enable(enable),.sector1(32'd1000),.sector2(32'd2000),.sector3(32'd3000),.sector4(32'd4000),.active(active),.ready(ready),.error(error),.sector_req(sector_req),.sector_addr(sector_addr),.sector_data(sector_data),.sector_valid(sector_valid),.sector_end(sector_end),.sector_error(sector_error),.write_req(write_req),.write_req_ack(write_req_ack),.write_en(write_en),.write_data(write_data),.write_base(write_base),.write_len(write_len),.write_finish_toggle(write_finish_toggle));
reg[7:0] media[0:1001471];integer seed=13579246,words=0,acks=0,requests=0,mode=0,ack_delay=-1,finish_delay=-1;integer p,k,j,gap,bcount;reg[31:0]expected;reg checking=1;integer physical_requests=0;reg previous_sd_req=0;
always @(posedge clk)begin if(rst)begin physical_requests=0;previous_sd_req=0;end else begin if(sd_req&&!previous_sd_req)physical_requests=physical_requests+1;previous_sd_req=sd_req;end end
function integer rnd(input integer bound);integer z;begin z=$random(seed)&32'h7fffffff;rnd=z%bound;end endfunction
always @(negedge clk)begin
 write_req_ack=0;
 if(rst)begin ack_delay=-1;finish_delay=-1;end
 else begin
  if(write_req&&mode!=6)begin
   if(ack_delay<0)ack_delay=1+rnd(13);
   else if(ack_delay==0)begin write_req_ack=1;ack_delay=-2;end
   else ack_delay=ack_delay-1;
  end else ack_delay=-1;
  if(finish_delay>0)finish_delay=finish_delay-1;
  else if(finish_delay==0&&mode!=8)begin #2 write_finish_toggle=~write_finish_toggle;finish_delay=-1;end
 end
end
always @(posedge clk)if(!rst)begin
 if(write_req&&write_req_ack)begin
  if(checking&&(write_base!==1843200+acks*62464||write_len!==62464))$fatal(1,"base/len mismatch ack%0d base%0d len%0d",acks,write_base,write_len);
  acks=acks+1;
 end
 if(write_en)begin
  if(checking)begin
   p=words/62464;k=(words%62464)*4+p*250368+512;
   expected={media[k+3],media[k+2],media[k+1],media[k]};
   if(write_data!==expected)$fatal(1,"word mismatch word%0d panel%0d got%x expected%x",words,p,write_data,expected);
   if(words%62464>=62400&&write_data!==0)$fatal(1,"padding not zero");
  end
  words=words+1;if(words%62464==0)finish_delay=73+rnd(401);
 end
end
task reset_dut;begin
 @(negedge clk);rst=1;enable=0;sd_valid=0;sd_end=0;sd_error=0;write_finish_toggle=0;sd_ready=1;audio_req=0;repeat(5)@(negedge clk);words=0;acks=0;requests=0;rst=0;enable=1;
end endtask
task send_sector(input integer panel,input integer sec,input integer count,input integer bad,input integer joint_end);integer b,gi,idx;begin
 requests=requests+1;
 for(b=0;b<count;b=b+1)begin
  gi=rnd(4);repeat(gi)begin @(negedge clk);sd_valid=0;sd_end=0;end
  @(negedge clk);idx=panel*250368+sec*512+b;sd_data=media[idx];if(bad&&b==54)sd_data=8'h00;sd_valid=1;sd_end=(joint_end&&b==count-1);
 end
 @(negedge clk);sd_valid=0;sd_end=!joint_end;
 @(negedge clk);sd_end=0;
end endtask
task wait_failure;integer n;begin
 n=0;while(!error&&n<21000)begin @(negedge clk);n=n+1;end
 if(!error||ready)$fatal(1,"expected failure not seen mode%0d",mode);
 repeat(4)@(negedge clk);if(active||write_req)$fatal(1,"failure did not quiesce");
end endtask
initial begin
 $readmemh("media_prefix.hex",media);reset_dut;sd_ready=0;
 for(j=0;j<4;j=j+1)begin
  for(bcount=0;bcount<=488;bcount=bcount+1)begin
   wait(sector_req);if(sector_addr!==(j+1)*1000+bcount)$fatal(1,"sector order got%0d panel%0d index%0d",sector_addr,j,bcount);
   gap=200+rnd(301);repeat(gap)begin @(negedge clk);if(!sector_req||sector_addr!==(j+1)*1000+bcount)$fatal(1,"pending request/address not held through busy arbiter");end
   if(j==0&&bcount==0)begin
    audio_req=1;sd_ready=1;wait(sd_req);if(sd_addr!==99999)$fatal(1,"audio priority not exercised");audio_req=0;
    repeat(300)begin @(negedge clk);if(!sector_req||sector_addr!==1000)$fatal(1,"BMP request lost during audio ownership");end
    sd_end=1;@(negedge clk);sd_end=0;wait(!sd_req);wait(sd_req);
   end else begin sd_ready=1;wait(sd_req);end
   if(sd_addr!==sector_addr)$fatal(1,"arbiter request/address mismatch");
   send_sector(j,bcount,512,0,bcount%2);sd_ready=0;
  end
 end
 wait(ready||error);if(error||words!=249856||acks!=4||requests!=1956||physical_requests!=1957)$fatal(1,"full flow bad words%0d acks%0d req%0d",words,acks,requests);
 if(write_base+write_len>2097152)$fatal(1,"SDRAM overflow");
 $display("FULL_RESOURCES_PASS panels4 words%0d requests%0d",words,requests);
 checking=0;mode=1;reset_dut;wait(sd_req);send_sector(0,0,512,1,1);wait_failure;if(acks||words)$fatal(1,"bad header wrote memory");$display("BAD_HEADER_PASS");
 mode=2;reset_dut;wait(sd_req);send_sector(0,0,511,0,0);wait_failure;$display("SHORT_HEADER_PASS");
 mode=3;reset_dut;wait(sd_req);send_sector(0,0,512,0,1);wait(sd_req);send_sector(0,1,509,0,1);wait_failure;if(words!=127)$fatal(1,"short data words%0d",words);$display("SHORT_DATA_PASS");
 mode=4;reset_dut;wait(sector_req);wait_failure;$display("HEADER_TIMEOUT_PASS");
 mode=5;reset_dut;wait(sd_req);send_sector(0,0,512,0,0);wait(sd_req);sd_error=1;@(negedge clk);sd_error=0;wait_failure;$display("SECTOR_ERROR_PASS");
 mode=6;reset_dut;wait(sd_req);send_sector(0,0,512,0,0);wait_failure;$display("ACK_TIMEOUT_PASS");
 mode=7;reset_dut;wait(sd_req);send_sector(0,0,512,0,1);wait(sector_req);wait_failure;$display("DATA_TIMEOUT_PASS");
 mode=8;reset_dut;for(bcount=0;bcount<=488;bcount=bcount+1)begin wait(sd_req);send_sector(0,bcount,512,0,bcount%2);end wait_failure;$display("FINISH_TIMEOUT_PASS");
 $display("TEST_PASS html_panel_loader_tb");$finish;
end
initial begin #100000000;$fatal(1,"global timeout");end
endmodule

module html_read_tags_tb;
reg clk=0;always#5 clk=~clk;reg rst=1,request=0,packed_pixel=0,half_pixel=0,black_pixel=0,response=0;reg[31:0]memory_data=0;wire[31:0]pixel_data;wire fault;
html_read_tags dut(.*);
reg[2:0] qtag[0:4095];reg[31:0]qdata[0:4095];integer due[0:4095];integer head=0,tail=0,cycle=0,seed=672983,lastdue=0,sent=0,received=0;reg[31:0]expected;reg[15:0]pix;
function integer rnd(input integer n);integer z;begin z=$random(seed)&32'h7fffffff;rnd=z%n;end endfunction
function[31:0] expand(input[15:0]p);begin expand={{p[15:11],p[15:13]},{p[10:5],p[10:9]},{p[4:0],p[4:2]},8'd0};end endfunction
task reset_fifo;begin @(negedge clk);rst=1;request=0;response=0;repeat(4)@(negedge clk);rst=0;head=0;tail=0;cycle=0;lastdue=0;end endtask
initial begin
 reset_fifo;
 repeat(3000)begin
  @(negedge clk);cycle=cycle+1;request=(tail<2000)&&(tail-head<400)&&(rnd(4)!=0);response=(head<tail)&&(due[head]<=cycle);memory_data=response?qdata[head]:0;
  packed_pixel=rnd(2);half_pixel=rnd(2);black_pixel=(rnd(11)==0);
  if(request)begin qtag[tail]={black_pixel,half_pixel,packed_pixel};qdata[tail]={$random(seed)};lastdue=(lastdue>cycle?lastdue:cycle)+1+rnd(5);due[tail]=lastdue;tail=tail+1;end
  #1;
  if(response)begin pix=qtag[head][1]?qdata[head][31:16]:qdata[head][15:0];expected=qtag[head][2]?0:(qtag[head][0]?expand(pix):qdata[head]);if(pixel_data!==expected)$fatal(1,"tag payload/order mismatch%0d got%x expected%x",head,pixel_data,expected);head=head+1;end
  @(posedge clk);#1;if(fault)$fatal(1,"unexpected FIFO fault occupancy%0d",tail-head);
 end
 // Drain while retaining variable ordered memory latency.
 while(head<tail)begin
  @(negedge clk);cycle=cycle+1;request=0;response=due[head]<=cycle;memory_data=qdata[head];#1;
  if(response)begin pix=qtag[head][1]?qdata[head][31:16]:qdata[head][15:0];expected=qtag[head][2]?0:(qtag[head][0]?expand(pix):qdata[head]);if(pixel_data!==expected)$fatal(1,"drain mismatch");head=head+1;end
  @(posedge clk);#1;if(fault)$fatal(1,"drain fault");
 end
 $display("VARIABLE_LATENCY_PASS requests%0d responses%0d",tail,head);
 reset_fifo;
 repeat(512)begin @(negedge clk);request=1;response=0;packed_pixel=0;end
 @(negedge clk);request=0;#1;if(fault)$fatal(1,"legal full depth fault");
 // Full simultaneous push/pop is legal; count remains512.
 request=1;response=1;@(negedge clk);request=0;response=0;#1;if(fault)$fatal(1,"full simultaneous fault");
 request=1;@(negedge clk);request=0;#1;if(!fault)$fatal(1,"overflow undiagnosed");$display("OVERFLOW_DIAGNOSTIC_PASS");
 reset_fifo;@(negedge clk);response=1;@(negedge clk);response=0;#1;if(!fault)$fatal(1,"underflow undiagnosed");$display("UNDERFLOW_DIAGNOSTIC_PASS");
 $display("TEST_PASS html_read_tags_tb");$finish;
end
initial begin #1000000;$fatal(1,"tag test timeout");end
endmodule
