`timescale 1ns/1ps
// Full-frame probe bench for the legacy loader virtual-window change.
// MODE 0 : one 640x480 or 800x600 single load; every one of the 307200
//          emitted pixels is compared with the independent oracle gold file,
//          the SD sector count and the loader's internal bounds are asserted.
// MODE 20: three consecutive loads without reset (800 -> 640 -> 800).
// MODE 1..4: authored-header rejection, short sector, SD error, no write ACK.
// The bench is a byte-port model of one TF reader plus the existing
// write_req/write_req_ack handshake; it makes no card, PHY or timing claim.
module probe_bmp_loader_tb;
 parameter PAGE=0,DUAL=0,ZOOM=0,FOCUS=0,MODE=0,PERIOD=16,TIMEOUT=5000;
 parameter BAD_BYTE=28,BAD_MASK=1,RIGHT_BAD=0;
 localparam MAXLEFT=1440511;
 reg clk=0;always#5 clk=~clk;
 reg rst=1,start=0,abort=0,initialized=1,ack=0;
 reg[31:0]left=100,right=5000;
 reg[2:0]page=PAGE,focus=FOCUS;reg dual=DUAL;reg[1:0]zoom=ZOOM;
 wire ready,busy,done,wr,pv,req;wire[3:0]error;wire[23:0]pixel;wire[31:0]addr;
 reg[7:0]data=0;reg valid=0,ending=0,sd_error=0;
 legacy_exhibit_loader #(.TIMEOUT_CYCLES(TIMEOUT),.PIXEL_PERIOD(PERIOD)) dut(
 .clk(clk),.rst(rst),.start(start),.abort(abort),.sector_left(left),.sector_right(right),
 .page(page),.dual(dual),.zoom(zoom),.focus(focus),.sd_init_done(initialized),
 .ready(ready),.busy(busy),.done(done),.error(error),.write_req(wr),.write_req_ack(ack),
 .pixel_valid(pv),.pixel(pixel),.sector_req(req),.sector_addr(addr),
 .sector_data(data),.sector_valid(valid),.sector_end(ending),.sector_error(sd_error));

 reg[7:0]lm[0:MAXLEFT];
 reg[7:0]rm[0:461311];
 reg[23:0]gold[0:307199];
 reg[2047:0]lf,rf,gf,gf2,gf3,df,fx2,fx3;
 integer fd=0;
 integer cycle=0,pixels=0,last_pixel=-100000,sectors=0,bidx=0,offset=0,cooldown=0;
 integer ack_phase=0,ack_wait=0,load_index=0,loads=1,max_sector=0,max_row=0;
 integer left_len=0,right_len=0,expected=0,expected2=0,expected3=0;
 integer fx2_len=0,fx3_len=0,k=0;
 reg active=0,selected_right=0,write_started=0,write_released=0,wr_seen=0;
 reg[31:0]held_addr=0;

 // ---------------------------------------------------------------- SD model
 always@(negedge clk)begin
  valid=0;ending=0;sd_error=0;
  if(rst)begin active=0;cooldown=0;ack=0;ack_phase=0;ack_wait=0;end
  else begin
   if(ack_phase==0&&wr&&MODE!=4)begin ack_phase=1;ack_wait=4;wr_seen=1;end
   else if(ack_phase==1)begin
    if(ack_wait==0)begin ack=1;ack_phase=2;ack_wait=6;write_started=1;end else ack_wait=ack_wait-1;
   end else if(ack_phase==2)begin
    if(ack_wait==0)begin ack=0;ack_phase=3;write_released=1;end else ack_wait=ack_wait-1;
   end else if(ack_phase==3&&!wr)ack_phase=0;
   if(cooldown!=0)cooldown=cooldown-1;
   else if(!active&&req)begin
    active=1;bidx=0;held_addr=addr;selected_right=(DUAL!=0)&&(addr>=5000);
    offset=(addr-(selected_right?5000:100))*512;
    if(offset<0||offset+512>(selected_right?right_len:left_len))
     $fatal(1,"sector outside accepted BMP addr%0d lenL%0d lenR%0d",addr,left_len,right_len);
    sectors=sectors+1;
    if(addr>max_sector)max_sector=addr;
   end else if(active)begin
    if(addr!==held_addr||!req)$fatal(1,"request changed before sector end");
    if(MODE==3&&bidx==40)begin sd_error=1;active=0;cooldown=4;end
    else if(bidx<((MODE==2)?511:512))begin
     valid=1;
     data=selected_right?rm[offset+bidx]:lm[offset+bidx];
     if(MODE==1&&offset==0&&selected_right==RIGHT_BAD&&bidx==BAD_BYTE)data=data^BAD_MASK;
     bidx=bidx+1;
     if(bidx==512)begin ending=1;active=0;cooldown=6;end
    end else begin ending=1;active=0;cooldown=6;end
   end
  end
 end

 // --------------------------------------------- pixel compare and bounds
 always@(posedge clk)if(!rst)begin
  cycle=cycle+1;
  if(busy)begin
   if(dut.line_write>10'd640)$fatal(1,"line_write%0d beyond 640-entry line RAM",dut.line_write);
   if(dut.sample_x>10'd639)$fatal(1,"sample_x%0d beyond line RAM",dut.sample_x);
   if(dut.buffer_index>9'd511)$fatal(1,"buffer_index%0d beyond sector buffer",dut.buffer_index);
   if(dut.byte_position>21'd1440511)$fatal(1,"byte_position%0d beyond 800x600 file",dut.byte_position);
   if(dut.native_row_l>10'd539)$fatal(1,"native_row%0d beyond 600 rows",dut.native_row_l);
   if(dut.row_fifteen>14'd8085)$fatal(1,"row_fifteen%0d beyond 15*539",dut.row_fifteen);
   if(dut.row_offset_l>22'd1293840)$fatal(1,"row_offset%0d beyond 2400*539",dut.row_offset_l);
   if(dut.state==5'd18&&dut.native_row_l>max_row)max_row=dut.native_row_l;
  end
  if(pv)begin
   if(!write_started||!write_released||ack)$fatal(1,"pixel before ACK release load%0d ws%0d wr%0d ack%0d state%0d px%0d",load_index,write_started,write_released,ack,dut.state,pixels);
   if(cycle-last_pixel<PERIOD)$fatal(1,"pixel pacing interval%0d < %0d",cycle-last_pixel,PERIOD);
   last_pixel=cycle;
   if(pixels>=307200||pixel!==gold[pixels])
    $fatal(1,"pixel%0d got%h expected%h page%0d dual%0d zoom%0d focus%0d load%0d",
     pixels,pixel,gold[pixels],PAGE,DUAL,ZOOM,FOCUS,load_index);
   if(fd)$fwrite(fd,"%06x\n",pixel);
   pixels=pixels+1;
  end
  if(done)begin
   if(pixels!=307200)$fatal(1,"load%0d emitted%0d pixels expected307200",load_index,pixels);
   if(sectors!=expected)$fatal(1,"load%0d sectors%0d expected%0d",load_index,sectors,expected);
   if(left_len==1440512&&max_row>539)$fatal(1,"wide load max stored row%0d beyond539",max_row);
   if(left_len==1440512&&ZOOM==0&&max_row!=539)$fatal(1,"wide 1x max stored row%0d expected539",max_row);
   if(left_len!=1440512&&max_row>479)$fatal(1,"narrow load max stored row%0d beyond479",max_row);
   $display("LOAD_PASS index%0d page%0d dual%0d zoom%0d focus%0d pixels%0d sectors%0d max_sector%0d cycles%0d",
    load_index,PAGE,DUAL,ZOOM,FOCUS,pixels,sectors,max_sector,cycle);
  end
  if(error!=0&&!busy)begin
   if(MODE==0||MODE==20)$fatal(1,"unexpected loader error%0d",error);
   if(wr_seen&&MODE!=4)$fatal(1,"rejected header asserted write_req");
   if(pixels!=0)$fatal(1,"rejected header emitted%0d pixels",pixels);
   if(MODE==1&&error!=1)$fatal(1,"header error code%0d expected1",error);
   if(MODE==2&&error!=2)$fatal(1,"sector error code%0d expected2",error);
   if(MODE==3&&error!=3)$fatal(1,"SD error code%0d expected3",error);
   if(MODE==4&&error!=4)$fatal(1,"timeout code%0d expected4",error);
   $display("TEST_PASS probe_bmp_reject mode%0d error%0d sectors%0d pixels%0d",MODE,error,sectors,pixels);
   $finish;
  end
 end

 // ------------------------------------------------------------- sequencer
 initial begin
  if(!$value$plusargs("left=%s",lf)||!$value$plusargs("gold=%s",gf)||
     !$value$plusargs("left_len=%d",left_len)||!$value$plusargs("expected_sectors=%d",expected))
   $fatal(1,"fixture args");
  if(!$value$plusargs("right=%s",rf))rf=".";
  if(!$value$plusargs("right_len=%d",right_len))right_len=0;
  if(MODE==20)begin
   if(!$value$plusargs("left2=%s",fx2)||!$value$plusargs("left3=%s",fx3)||
      !$value$plusargs("left2_len=%d",fx2_len)||!$value$plusargs("left3_len=%d",fx3_len)||
      !$value$plusargs("gold2=%s",gf2)||!$value$plusargs("gold3=%s",gf3)||
      !$value$plusargs("expected_sectors2=%d",expected2)||!$value$plusargs("expected_sectors3=%d",expected3))
    $fatal(1,"reload fixture args");
   loads=3;
  end
   $readmemh(lf,lm,0,left_len-1);
   if(MODE==0||MODE==20)$readmemh(gf,gold);
  if(right_len>0)$readmemh(rf,rm,0,right_len-1);
  if($value$plusargs("dump=%s",df))begin fd=$fopen(df,"w");if(!fd)$fatal(1,"dump open");end
  repeat(5)@(negedge clk);rst=0;wait(ready);
  for(k=0;k<loads;k=k+1)begin
   load_index=k;max_row=0;
   @(negedge clk);start=1;@(negedge clk);start=0;
   $display("LOAD_START index%0d len%0d expected_sectors%0d wide%d t%0d",k,left_len,expected,dut.wide_l,cycle);
   wait(done);
   // two negedges: the bench samples the final pixel_valid on the posedge that
   // follows the done pulse, so flags/dump must be cleared only after it
   @(negedge clk);@(negedge clk);
   if(k+1<loads)begin
    // reload fixture for the next load on the same, non-reset instance
    pixels=0;sectors=0;max_sector=0;max_row=0;last_pixel=-100000;
    write_started=0;write_released=0;ack_phase=0;ack_wait=0;active=0;cooldown=0;
    if(fd)begin $fclose(fd);fd=0;end
    if(k==0)begin $readmemh(fx2,lm,0,fx2_len-1);$readmemh(gf2,gold);
                 left_len=fx2_len;expected=expected2;dual=0;zoom=0;focus=0;page=3;end
    else begin $readmemh(fx3,lm,0,fx3_len-1);$readmemh(gf3,gold);
               left_len=fx3_len;expected=expected3;dual=0;zoom=0;focus=0;page=0;end
    repeat(4)@(negedge clk);
   end
  end
  if(fd)$fclose(fd);
  $display("TEST_PASS probe_bmp_loader mode%0d loads%0d",MODE,loads);
  $finish;
 end
 initial begin #400000000;$fatal(1,"watchdog pixels%0d state%0d",pixels,dut.state);end
endmodule
