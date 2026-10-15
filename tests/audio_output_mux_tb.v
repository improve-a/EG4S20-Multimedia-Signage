`timescale 1ns/1ps
// Quantify production tone/WAV valid mux and candidate unified cadence.
// Real sector WAV/media + baseline tone generator + baseline ACR calculators.
module audio_output_mux_tb #(parameter READY_DELAY=50000);
reg vc=0,sc=0;always #20 vc=~vc;always #5 sc=~sc;
reg vr=1,sr=1,sdready=0;reg grant=0,sdv=0,sde=0;reg[7:0]sddata=0;
wire req,urgent;wire[31:0]addr;wire wvalid;wire[23:0]wl,wr;wire[3:0]status;
wire[15:0]peak;wire uf,of,eof,error;wire[11:0]level;
wire tvalid;wire[23:0]tl,tr;
reg selected=0;
wire current_valid=selected?wvalid:tvalid;
wire unified_valid,fixed_selected;wire[23:0]fixed_left,fixed_right;
wire[23:0]pcm_left=selected?wl:tl,pcm_right=selected?wr:tr;
wire cv,uv;wire[19:0]ccts,ucts,cn,un;
reg[7:0]card[0:3071];integer sb=0,offset=0,base=0,delay_count=0;
integer cycles=0,last_current=-1,last_unified=-1,min_current=100000,max_current=0;
integer min_unified=100000,max_unified=0,current_bad_gaps=0,unified_bad_gaps=0;
integer current_frames=0,unified_frames=0,ctses=0,utses=0,current_bad_cts=0,unified_bad_cts=0;
integer gap,selection_cycle=-1;
audio_media media(sc,sr,vc,vr,1'b1,1'b0,1'b0,1'b0,4'd8,sdready,
 grant,sddata,sdv,sde,1'b0,req,addr,urgent,wvalid,wl,wr,status,peak,uf,of,eof,error,level);
hdmi_audio_tone_pcm_scale tone(vc,vr,1'b0,tvalid,tl,tr);
audio_arc_calculate current_acr(vc,vr,current_valid,cv,ccts,cn);
audio_output_mux fixed_mux(vc,vr,tvalid,tl,tr,wl,wr,status,4'd8,unified_valid,fixed_left,fixed_right,fixed_selected);
audio_arc_calculate unified_acr(vc,vr,unified_valid,uv,ucts,un);
// Exact current production latch/mux expressions; no top source is changed.
always @(posedge vc)begin
 if(vr)selected<=0;
 else if(status==2||status==3||status==4||status==5)selected<=1;
end
always @(negedge sc)begin
 grant=0;sdv=0;sde=0;
 if(!sr)begin
  if(sb==0&&req)begin
   if(addr>5)$fatal(1,"card address %0d",addr);
   base=addr*512;offset=0;sb=1;delay_count=10;grant=1;
  end else if(sb==1)begin
   if(delay_count>0)delay_count=delay_count-1;
   else if(offset<512)begin sdv=1;sddata=card[base+offset];offset=offset+1;delay_count=3;end
   else begin sde=1;sb=2;delay_count=4;end
  end else if(sb==2)begin if(delay_count>0)delay_count=delay_count-1;else sb=0;end
 end
end
always @(posedge vc)if(!vr)begin
 cycles=cycles+1;
 if(selected&&selection_cycle<0)begin selection_cycle=cycles;$display("SELECT_WAV cycle=%0d wvalid=%0d tvalid=%0d status=%0d",cycles,wvalid,tvalid,status);end
 if(current_valid)begin
  if(last_current>=0)begin
   gap=cycles-last_current;
   if(gap<min_current)min_current=gap;if(gap>max_current)max_current=gap;
   if(gap!=520&&gap!=521)begin current_bad_gaps=current_bad_gaps+1;$display("CURRENT_MUX_ANOMALOUS_GAP cycle=%0d clocks=%0d",cycles,gap);end
  end
  last_current=cycles;
  if(selected&&(pcm_left!=0||pcm_right!=0))begin
   if($signed(pcm_left)!=(-30000+current_frames*97)*256||$signed(pcm_right)!=(25000-current_frames*83)*256)$fatal(1,"current mux frame order %0d",current_frames);
   current_frames=current_frames+1;
  end
 end
 if(unified_valid)begin
  if(last_unified>=0)begin
   gap=cycles-last_unified;if(gap<min_unified)min_unified=gap;if(gap>max_unified)max_unified=gap;
   if(gap!=520&&gap!=521)unified_bad_gaps=unified_bad_gaps+1;
  end
  last_unified=cycles;
  if(fixed_selected&&(fixed_left!=0||fixed_right!=0))begin
   if($signed(fixed_left)!=(-30000+unified_frames*97)*256||$signed(fixed_right)!=(25000-unified_frames*83)*256)$fatal(1,"unified cadence frame order %0d got %0d %0d",unified_frames,$signed(fixed_left),$signed(fixed_right));
   unified_frames=unified_frames+1;
  end
 end
 if(cv)begin
  ctses=ctses+1;
  if(ctses>1&&ccts!=25000)begin current_bad_cts=current_bad_cts+1;$display("CURRENT_MUX_ANOMALOUS_CTS cycle=%0d CTS=%0d N=%0d",cycles,ccts,cn);end
 end
 if(uv)begin utses=utses+1;if(utses>1&&ucts!=25000)unified_bad_cts=unified_bad_cts+1;end
end
initial begin
 $readmemh("tests/audio_card.hex",card);
 repeat(10)@(negedge vc);vr=0;sr=0;
 repeat(READY_DELAY)@(negedge vc);sdready=1;
 wait(eof);repeat(50000)@(negedge vc);
 if(current_frames!=300||unified_frames!=300||uf||of||error)$fatal(1,"PCM output counts %0d/%0d flags%0d%0d%0d",current_frames,unified_frames,uf,of,error);
 if(current_bad_gaps!=1||current_bad_cts!=1)$fatal(1,"current mux expected one quantified transition anomaly gaps=%0d CTS=%0d",current_bad_gaps,current_bad_cts);
 if(unified_bad_gaps!=0||unified_bad_cts!=0||min_unified!=520||max_unified!=521)$fatal(1,"unified cadence anomaly");
 $display("TEST_PASS output mux diagnosis: current gap range=%0d..%0d anomalous_gaps=%0d anomalous_CTS=%0d; unified gap=%0d..%0d anomalous_gaps=%0d anomalous_CTS=%0d; exact WAV frame order current/unified=%0d/%0d; ready delay clocks=%0d",min_current,max_current,current_bad_gaps,current_bad_cts,min_unified,max_unified,unified_bad_gaps,unified_bad_cts,current_frames,unified_frames,READY_DELAY);$finish;
end
initial begin #15000000;$fatal(1,"mux test timeout");end
endmodule
