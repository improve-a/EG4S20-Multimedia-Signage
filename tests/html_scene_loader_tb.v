`timescale 1ns/1ps
module html_scene_loader_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,enable=0,ack=0,valid=0,ending=0,sd_error=0,finish_toggle=0;
 reg [7:0] data=0;
 wire active,ready,error,req,wreq,we,mode_valid,layer_mode;wire [5:0] page_ready;
 wire [31:0] address,wdata;wire [20:0] base,len;
 reg [31:0] s0=17;
 integer c=0,cycles=0,grant=0,byte_i=0,gap=0,p=0,sector_i=0,origin=0;
 integer ack_wait=0,ack_tail=0,word_count=0,page_count=0,finish_wait=0,all_words=0;
 integer request_count=0,expected_word,header_words;
 reg busy=0,is_header=0;reg [31:0] locked_addr;
 reg [7:0] h[0:511];integer k;
 html_scene_loader #(.TIMEOUT_CYCLES(400),
 .BASE_WORDS({21'd5120,21'd4096,21'd3072,21'd2048,21'd1024,21'd0}),
 .LENGTH_WORDS({6{21'd1024}})) dut(
 .clk(clk),.rst(rst),.enable(enable),.sector0(s0),.sector1(32'd10017),.sector2(32'd20017),
 .sector3(32'd30017),.sector4(32'd40017),.sector5(32'd50017),
 .active(active),.ready(ready),.error(error),.page_ready(page_ready),.mode_valid(mode_valid),.layer_mode(layer_mode),
 .sector_req(req),.sector_addr(address),.sector_data(data),.sector_valid(valid),.sector_end(ending),.sector_error(sd_error),
 .write_req(wreq),.write_req_ack(ack),.write_en(we),.write_data(wdata),.write_base(base),.write_len(len),.write_finish_toggle(finish_toggle));
 task put32;input integer a;input [31:0] v;begin
  h[a]=v[7:0];h[a+1]=v[15:8];h[a+2]=v[23:16];h[a+3]=v[31:24];
 end endtask
 task header;input integer page;begin
  for(k=0;k<512;k=k+1)h[k]=0;
  h[0]=8'h42;h[1]=8'h4d;put32(2,926208);put32(10,512);put32(14,40);put32(18,640);put32(22,480);
  h[26]=1;h[28]=24;put32(80,32'h4c584648);h[84]=1;h[86]=32;put32(88,922112);put32(92,4096);
  put32(96,page*1024);h[100]=page;h[102]=6;put32(104,32'h003adc1b);
  if(c==17)begin put32(80,0);put32(10,54);put32(18,320);put32(22,240);put32(2,230454);end
  if(c==18)h[0]=0;
  case(c)1:h[84]=2;2:put32(104,0);3:put32(96,256);4:begin put32(92,8192);put32(2,930304);end endcase
 end endtask
 function [31:0] payload;input integer page,word;begin
  payload=32'h9e3779b9^(page*32'h10204080)^word;
  case(word)
   0:payload=(c==5)?0:32'h4c584648;
   1:payload=1;2:payload=1024;3:payload=(page==0)?9:(page==5)?10:12;
   4:payload=64;5:payload=8;7:payload=214;10:payload=640;11:payload=480;
   13:payload=32'h003adc1b;14:payload=(c==6)?256:page*1024;15:payload=(c==7)?6:page;
  endcase
  // Every required payload-header field has an independent rejection case.
  if((c==19&&word==1)||(c==20&&word==2)||(c==21&&word==3)||
     (c==22&&word==4)||(c==23&&word==5)||(c==24&&word==7)||
     (c==25&&word==10)||(c==26&&word==11)||(c==27&&word==13))payload=payload^32'h80000001;
 end endfunction
 always @(negedge clk)begin
  valid=0;ending=0;sd_error=0;
  if(!rst)begin
   cycles=cycles+1;
   if(wreq)begin
    ack_wait=ack_wait+1;
    if(ack_wait==70)begin
     if(base!==page_count*1024||len!==1024)$fatal(1,"wrong write metadata");
     word_count=0;if(c!=13)ack=1;
    end
   end else if(ack)begin ack_tail=ack_tail+1;if(ack_tail==9)begin ack=0;ack_tail=0;ack_wait=0;end end
   if(finish_wait>0)begin
    finish_wait=finish_wait-1;
    if(finish_wait==0&&c!=15)begin finish_toggle=~finish_toggle;page_count=page_count+1;end
   end
   if(!busy&&req)begin
    grant=grant+1;
    if(grant==13)begin
     locked_addr=address;busy=1;byte_i=0;gap=0;request_count=request_count+1;
     p=(c==16)?0:address/10000;origin=(c==16)?s0:17+p*10000;is_header=(address==origin);
     sector_i=address-origin-1801;
     if(!is_header&&(sector_i<0||sector_i>=8))$fatal(1,"bad payload LBA %0d",address);
     if(!is_header&&ack)$fatal(1,"payload starts before ACK release");
     header(p);
    end
   end
   if(busy)begin
    if(address!==locked_addr)$fatal(1,"LBA changed while held");
    if((c==10&&is_header)||(c==11&&!is_header))begin sd_error=1;busy=0;end
    else if(!((c==12&&is_header)||(c==14&&!is_header)))begin
     if(gap==0)begin
      if(is_header)data=h[byte_i];
      else begin expected_word=payload(p,sector_i*128+byte_i/4);data=(expected_word>>(8*(byte_i%4)))&255;end
      valid=1;byte_i=byte_i+1;gap=byte_i%3;
      header_words=((c==8&&is_header)||(c==9&&!is_header))?511:512;
      if(byte_i==header_words)begin ending=1;busy=0;grant=0;end
     end else gap=gap-1;
    end
   end
  end
 end
 always @(posedge clk)if(!rst)begin
  if(we)begin
   if(wdata!==payload(page_count,word_count))$fatal(1,"case%0d page%0d word%0d data",c,page_count,word_count);
   if(word_count>=1024)$fatal(1,"too many payload words");
   word_count=word_count+1;all_words=all_words+1;
   if(word_count==1024)finish_wait=37+page_count*17;
  end
  if(page_ready & ~((1<<page_count)-1))$fatal(1,"page ready before physical write completion");
 end
 initial begin
  for(c=0;c<28;c=c+1)begin
   @(posedge clk);#1;rst=1;enable=0;ack=0;valid=0;ending=0;sd_error=0;finish_toggle=0;
   s0=(c==16)?32'hfffffc00:17;
   busy=0;cycles=0;grant=0;ack_wait=0;ack_tail=0;word_count=0;page_count=0;finish_wait=0;request_count=0;
   repeat(7)@(posedge clk);#1;rst=0;enable=1;
   while(!ready&&!error&&!(mode_valid&&!layer_mode)&&cycles<150000)begin @(posedge clk);#1;end
   if(c==0)begin
    if(!ready||error||!mode_valid||!layer_mode||page_ready!=63||page_count!=6||request_count!=54)$fatal(1,"six page load incomplete");
   end else if(c==17)begin
    if(!mode_valid||layer_mode||ready||error||active||page_ready||request_count!=1||word_count||wreq)$fatal(1,"ordinary BMP did not select legacy adaptive mode");
   end else if(!error||ready||page_ready!=0)$fatal(1,"case%0d did not reject incomplete resources",c);
   repeat(10)@(posedge clk);#1;
   if(req||wreq||active)$fatal(1,"transaction held after terminal state");
  end
  $display("TEST_PASS scene loader 6 ready-after-write pages, %0d checked words, 26 malformed/transport/timeout cases plus ordinary adaptive-BMP fallback",all_words);$finish;
 end
endmodule
