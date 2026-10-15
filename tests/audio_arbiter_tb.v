`timescale 1ns/1ps
module audio_arbiter_tb;
reg sc=0,ac=0;always #5 sc=~sc;always #20 ac=~ac;
reg rst=1,ar=1,enable=0;wire areq,urgent;wire[31:0]aaddr;wire agrant;
wire[7:0]adata,bdata;wire av,ae,ax,bv,be,bx;
wire[23:0]left,right;wire valid;wire[15:0]peak;wire[3:0]status;wire uf,of,eof,err;wire[11:0]level;
reg breq=0;reg[31:0]baddr=4096;
wire sdreq;wire[31:0]sdaddr;reg[7:0]sddata=0;reg sdvalid=0,sdend=0,sderr=0;
reg[7:0]card[0:11263];integer busy=0,delay_count=0,offset=0,sector_base=0;
integer cycles=0,last_a_req=-1,max_a_wait=0,wait_now,a_requests=0,b_sectors=0,a_sectors=0,frames=0;
integer last_phy_end=0,max_sector_cycles=0,phy_start=0,sd_sectors=0,bbytes=0,bgap=0;
reg [31:0]held_lba;reg served_audio;
audio_media media(sc,rst,ac,ar,enable,1'b0,1'b0,1'b0,4'd8,1'b1,agrant,adata,av,ae,ax,
 areq,aaddr,urgent,valid,left,right,status,peak,uf,of,eof,err,level);
media_sector_arbiter arb(sc,rst,1'b1,breq,baddr,bdata,bv,be,bx,
 areq,aaddr,urgent,agrant,adata,av,ae,ax,sdreq,sdaddr,sddata,sdvalid,sdend,sderr);
always @(negedge sc)begin
 cycles=cycles+1;sdvalid=0;sdend=0;
 if(!rst)begin
  if(areq&&last_a_req<0)last_a_req=cycles;
  if(agrant)begin
   if(last_a_req<0)$fatal(1,"unsolicited audio grant");
   wait_now=cycles-last_a_req;if(wait_now>max_a_wait)max_a_wait=wait_now;
   last_a_req=-1;a_requests=a_requests+1;
  end
  if(busy==0&&sdreq)begin
   held_lba=sdaddr;sector_base=sdaddr*512;offset=0;busy=1;delay_count=2048;phy_start=cycles;
   served_audio=arb.owner_audio;
   if(served_audio&&sdaddr>21)$fatal(1,"duplicate/out-of-range WAV LBA %0d",sdaddr);
   sd_sectors=sd_sectors+1;
  end else if(busy==1)begin
   if(!sdreq||sdaddr!=held_lba)$fatal(1,"physical request changed mid-sector");
   if(delay_count>0)delay_count=delay_count-1;
   else if(offset<512)begin
    sdvalid=1;sddata=served_audio?card[sector_base+offset]:8'ha5;offset=offset+1;delay_count=offset==512?127:63;
   end else begin
    sdend=1;busy=2;delay_count=128;
    if(cycles-phy_start>max_sector_cycles)max_sector_cycles=cycles-phy_start;
    last_phy_end=cycles;
   end
  end else if(busy==2)begin
   if(!sdreq)busy=0;
  end
 end
end
// Clients sample the routed completion pulse on the same rising clock edge.
always @(posedge sc)if(!rst)begin
 if(be)begin
  if(bbytes!=512)$fatal(1,"BMP routed byte count %0d",bbytes);
  bbytes=0;breq<=0;bgap=1;baddr<=baddr+1;b_sectors=b_sectors+1;
 end else if(bgap!=0)bgap=bgap-1;else breq<=1;
 if(bv)bbytes=bbytes+1;
 if(ae)a_sectors=a_sectors+1;
end
always @(negedge ac)if(valid&&(left!=0||right!=0))begin
 if($signed(left)!=(-30000+(frames%600)*97)*256)$fatal(1,"lost/duplicate L frame %0d got %0d",frames,$signed(left));
 if($signed(right)!=(25000-(frames%500)*83)*256)$fatal(1,"lost/duplicate R frame %0d got %0d",frames,$signed(right));
 frames=frames+1;
end
initial begin
 $readmemh("tests/audio_arbiter_card.hex",card);
 repeat(10)@(negedge sc);rst=0;ar=0;enable=1;
 wait(eof);repeat(10)@(negedge ac);
 if(frames!=2304||uf||of||err)$fatal(1,"shared reader frames=%0d UF=%0d OF=%0d err=%0d",frames,uf,of,err);
 if(a_requests!=24||a_sectors!=24)$fatal(1,"scan/replay LBA count req=%0d end=%0d",a_requests,a_sectors);
 if(b_sectors<70)$fatal(1,"BMP starvation sectors=%0d",b_sectors);
 if(max_a_wait>75000)$fatal(1,"grant delay exceeds two sector bound %0d",max_a_wait);
 $display("TEST_PASS shared physical reader: 2304 PCM frames exact order; continuous BMP load; 64 sys clocks/SD byte; no UF/OF; audio_sectors=%0d bmp_sectors=%0d longest_audio_grant_delay_sys_clocks=%0d max_sector_sys_clocks=%0d",a_sectors,b_sectors,max_a_wait,max_sector_cycles);
 $finish;
end
initial begin #60000000;$fatal(1,"timeout frames=%0d reqs=%0d bmp=%0d state=%0d",frames,a_requests,b_sectors,media.state);end
endmodule
