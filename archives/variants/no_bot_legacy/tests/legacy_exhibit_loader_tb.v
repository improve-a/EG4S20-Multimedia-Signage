`timescale 1ns/1ps
// Actual loader pixels against an independently prepared BMP-coordinate oracle.
module legacy_exhibit_loader_tb;
 parameter PAGE=0,DUAL=0,ZOOM=0,FOCUS=0,MODE=0,PERIOD=16,HEADER_BYTE=28;
 reg clk=0;always#5 clk=~clk;
 reg rst=1,start=0,abort=0,initialized=1,ack=0;
 reg[31:0]left=100,right=5000;reg[2:0]page=PAGE,focus=FOCUS;reg dual=DUAL;reg[1:0]zoom=ZOOM;
 wire ready,busy,done,wr,pv,req;wire[3:0]error;wire[23:0]pixel;wire[31:0]addr;
 reg[7:0]data=0;reg valid=0,ending=0,sd_error=0;
 legacy_exhibit_loader #(.TIMEOUT_CYCLES(5000),.PIXEL_PERIOD(PERIOD)) dut(
 .clk(clk),.rst(rst),.start(start),.abort(abort),.sector_left(left),.sector_right(right),.page(page),.dual(dual),.zoom(zoom),.focus(focus),.sd_init_done(initialized),
 .ready(ready),.busy(busy),.done(done),.error(error),.write_req(wr),.write_req_ack(ack),.pixel_valid(pv),.pixel(pixel),
 .sector_req(req),.sector_addr(addr),.sector_data(data),.sector_valid(valid),.sector_end(ending),.sector_error(sd_error));
 reg[7:0]lm[0:922111],rm[0:461311];reg[23:0]gold[0:307199];
 reg[2047:0]lf,rf,gf,df;integer fd=0;
 integer cycle=0,pixels=0,last_pixel=-100000,sectors=0,bidx=0,offset=0,cooldown=0,ack_phase=0,ack_wait=0;
 integer left_len=0,right_len=0,expected_sectors=0;reg active=0,selected_right=0,write_started=0,write_released=0;
 reg[31:0]held_addr=0;integer row_loads=0;
 always@(negedge clk)begin
  valid=0;ending=0;sd_error=0;
  if(rst)begin active=0;cooldown=0;ack=0;ack_phase=0;ack_wait=0;end
  else begin
   if(ack_phase==0&&wr)begin ack_phase=1;ack_wait=4;end
   else if(ack_phase==1)begin
    if(ack_wait==0)begin ack=1;ack_phase=2;ack_wait=5;write_started=1;end else ack_wait=ack_wait-1;
   end else if(ack_phase==2&&MODE!=8)begin
    if(ack_wait==0)begin ack=0;ack_phase=3;write_released=1;end else ack_wait=ack_wait-1;
   end
   if(cooldown!=0)cooldown=cooldown-1;
   else if(!active&&req)begin
    active=1;bidx=0;held_addr=addr;selected_right=addr>=5000;
    offset=(addr-(selected_right?5000:100))*512;sectors=sectors+1;
    if(offset<0||offset+512>(selected_right?right_len:left_len))$fatal(1,"sectoroutsideacceptedBMP addr%0d",addr);
   end else if(active&&MODE!=4)begin
    if(addr!==held_addr||!req)$fatal(1,"requestchangedbeforesectorend");
    if(MODE==3&&bidx==30)begin sd_error=1;active=0;cooldown=4;end
    else if(cycle%7!=0)begin
     if(bidx<((MODE==2||(MODE==13&&offset!=0))?511:(MODE==7)?513:512))begin
      valid=1;data=selected_right?rm[offset+(bidx%512)]:lm[offset+(bidx%512)];
      if((MODE==1||(MODE==11&&selected_right))&&offset==0&&bidx==HEADER_BYTE)data=data^8'h01;
      bidx=bidx+1;
      // Alternate same-cycle and following-cycle end delivery.
      if(bidx==512&&MODE!=2&&MODE!=7&&!(MODE==13&&offset!=0)&&sectors%2==0)begin ending=1;active=0;cooldown=4;end
     end else begin ending=1;active=0;cooldown=4;end
    end
   end
  end
 end
 always@(posedge clk)if(!rst)begin
  cycle=cycle+1;
  if(pv)begin
   if(!write_started||!write_released||ack)$fatal(1,"pixelbeforeACKrelease");
   if(cycle-last_pixel<PERIOD)$fatal(1,"pixelpacing interval%0d",cycle-last_pixel);last_pixel=cycle;
   if(pixels>=307200||pixel!==gold[pixels])$fatal(1,"pixel%0d got%h expected%h page%0d dual%0d zoom%0d focus%0d",pixels,pixel,gold[pixels],PAGE,DUAL,ZOOM,FOCUS);
   if(fd)$fwrite(fd,"%06x\n",pixel);pixels=pixels+1;
  end
  if(done)begin
   if(MODE!=0&&MODE!=9)$fatal(1,"unexpecteddone");
   if(pixels!=307200)$fatal(1,"pixelcount%0d",pixels);
   if(sectors!=expected_sectors)$fatal(1,"rowreuse_sectorcount got%0d expected%0d",sectors,expected_sectors);
   if(fd)$fclose(fd);
   $display("TEST_PASS legacy_loader page%0d dual%0d zoom%0d focus%0d pixels%0d sectors%0d cycles%0d",PAGE,DUAL,ZOOM,FOCUS,pixels,sectors,cycle);$finish;
  end
  if(error!=0&&!busy)begin
   if(MODE==0||MODE==9)$fatal(1,"loadererror%0d",error);
   case(MODE)
    1,11:if(error!=1)$fatal(1,"headercode%0d",error);
    2,7,13:if(error!=2)$fatal(1,"sectorcode%0d",error);
    3:if(error!=3)$fatal(1,"SDcode%0d",error);
    4,8:if(error!=4)$fatal(1,"timeoutcode%0d",error);
    5,6,10,12:if(error!=5)$fatal(1,"abortcode%0d",error);
   endcase
   if(done)$fatal(1,"erroralsofinished");
   $display("TEST_PASS legacy_loader_rejection mode%0d error%0d pixels%0d sectors%0d",MODE,error,pixels,sectors);$finish;
  end
 end
 initial begin
  if(!$value$plusargs("left=%s",lf)||!$value$plusargs("right=%s",rf)||!$value$plusargs("gold=%s",gf)||!$value$plusargs("left_len=%d",left_len)||!$value$plusargs("right_len=%d",right_len)||!$value$plusargs("expected_sectors=%d",expected_sectors))$fatal(1,"fixtureargs");
  $readmemh(lf,lm,0,left_len-1);$readmemh(rf,rm,0,right_len-1);$readmemh(gf,gold);
  if($value$plusargs("dump=%s",df))begin fd=$fopen(df,"w");if(!fd)$fatal(1,"dumpopen");end
  repeat(5)@(negedge clk);rst=0;wait(ready);@(negedge clk);start=1;@(negedge clk);start=0;
  if(MODE==5||MODE==6)begin wait(valid&&bidx==100);@(negedge clk);if(MODE==5)abort=1;else initialized=0;end
  if(MODE==9)begin wait(busy);@(negedge clk);left=999999;right=999998;page=5;zoom=0;focus=5;dual=!DUAL;end
  if(MODE==12)begin wait(ending);abort=1;end
  if(MODE==10)begin wait(pixels>=200);@(negedge clk);abort=1;end
 end
 initial begin#200000000;$fatal(1,"watchdog pixels%0d state%0d",pixels,dut.state);end
endmodule
