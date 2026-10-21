// APUG011 hardware adapter: the SDRAM IP samples a new aligned address only
// every four physical beats. Logical viewport pixels therefore reference a
// four-word cache; physical responses refill it before a logical pixel retires.
module html_memory_bridge(
 input mem_clk,rst,video_read_req,read_accept_mem,
 input [4:0] active_view,input [1:0] zoom,transition_mode,input [2:0] focus,
 input panels_ready,write_busy_mem,mem_ready,refresh_active,
 input raw_read_en,output read_en,output [20:0] read_addr,
 input response,input [31:0] memory_data,
 output [31:0] pixel_data,output logical_ready,logical_response,busy,
 output reg fault
);
 localparam WINDOW=16,SLOTS=16;
 (* async_reg="true" *) reg [12:0] config_meta,config_sync;
 reg accept_previous,frame_active;
 wire frame_latch=read_accept_mem&&!accept_previous;
 reg [18:0] issued;
 reg [4:0] outstanding,queued;
 reg [2:0] mapper_inflight;
 wire speculate=frame_active && issued<19'd307200 && outstanding<WINDOW && !frame_latch;
 wire [20:0] mapped_addr;
 wire mapped_valid,mapped_packed,mapped_half,mapped_black;
 reg [18:0] cache_tag[0:15];
 reg [4:0] references[0:15];
 reg [15:0] allocated,complete,filling;
 reg [31:0] cache_data[0:63];
 // Each entry holds format and the protected cache slot/word, not a pixel copy.
 reg [8:0] logical_entries[0:15];
 reg [3:0] lwp,lrp;
 wire [8:0] head=logical_entries[lrp];
 wire [3:0] head_slot=head[5:2];
 wire [31:0] head_data=cache_data[head[5:0]];
 assign logical_ready=frame_active && queued!=0 && complete[head_slot] && !frame_latch;
 assign logical_response=raw_read_en&&logical_ready;
 wire [15:0] packed_value=head[7]?head_data[31:16]:head_data[15:0];
 wire [23:0] rgb={{packed_value[15:11],packed_value[15:13]},
                 {packed_value[10:5],packed_value[10:9]},
                 {packed_value[4:0],packed_value[4:2]}};
 assign pixel_data=head[8]?32'd0:(head[6]?{rgb,8'd0}:head_data);
 reg hit,free_found;
 reg [3:0] hit_slot,free_slot;
 integer k;
 always @*begin
  hit=0;hit_slot=0;free_found=0;free_slot=0;
  for(k=15;k>=0;k=k-1)begin
   if(allocated[k] && cache_tag[k]==mapped_addr[20:2])begin hit=1;hit_slot=k;end
   if(references[k]==0 && !filling[k])begin free_found=1;free_slot=k;end
  end
 end
 wire [3:0] dispatch_slot=hit?hit_slot:free_slot;
 wire allocate=mapped_valid&&!hit;
 // Miss jobs retain their slot until every physical response has arrived.
 reg [3:0] jobs[0:15];
 reg [3:0] jwp,jrp;
 reg [4:0] jobs_count;
 reg issue_active;
 reg [1:0] issue_phase;
 reg [3:0] issue_slot;
 reg [18:0] issue_base;
 assign read_en=issue_active && mem_ready && (issue_phase!=0 || !refresh_active);
 assign read_addr={issue_base,issue_phase};
 wire take_job=!frame_latch && jobs_count!=0 && mem_ready && !refresh_active && !write_busy_mem &&
               (!issue_active || (read_en && issue_phase==3));
 // Ordered response tags identify the cache word for each physical IP beat.
 reg [5:0] return_tags[0:63];
 reg [5:0] twp,trp;
 reg [6:0] return_count;
 wire [5:0] returning=return_tags[trp];
 assign busy=issue_active || jobs_count!=0 || return_count!=0 || mapper_inflight!=0;
 integer i;
 always @(posedge mem_clk)begin
  if(rst)begin
   config_meta<=0;config_sync<=0;accept_previous<=0;frame_active<=0;
   issued<=0;outstanding<=0;queued<=0;mapper_inflight<=0;lwp<=0;lrp<=0;
   allocated<=0;complete<=0;filling<=0;jwp<=0;jrp<=0;jobs_count<=0;
   issue_active<=0;issue_phase<=0;issue_slot<=0;issue_base<=0;
   twp<=0;trp<=0;return_count<=0;fault<=0;
   for(i=0;i<16;i=i+1)begin cache_tag[i]<=0;references[i]<=0;end
  end else begin
   accept_previous<=read_accept_mem;
   config_meta<={panels_ready,transition_mode,focus,zoom,active_view};config_sync<=config_meta;
   if(frame_latch)begin
    // The reader may acknowledge only after all physical work has drained.
    if(busy || raw_read_en || response || mapped_valid)fault<=1;
    frame_active<=1;issued<=0;outstanding<=0;queued<=0;mapper_inflight<=0;
    lwp<=0;lrp<=0;allocated<=0;complete<=0;filling<=0;
    jwp<=0;jrp<=0;jobs_count<=0;issue_active<=0;issue_phase<=0;
    twp<=0;trp<=0;return_count<=0;
    for(i=0;i<16;i=i+1)references[i]<=0;
   end else begin
    if(speculate)issued<=issued+1'b1;
    case({speculate,logical_response})
     2'b10:outstanding<=outstanding+1'b1;
     2'b01:outstanding<=outstanding-1'b1;
    endcase
    case({speculate,mapped_valid})
     2'b10:mapper_inflight<=mapper_inflight+1'b1;
     2'b01:mapper_inflight<=mapper_inflight-1'b1;
    endcase
    if(mapped_valid)begin
     logical_entries[lwp]<={mapped_black,mapped_half,mapped_packed,dispatch_slot,mapped_addr[1:0]};
     lwp<=lwp+1'b1;
    end
    if(logical_response)lrp<=lrp+1'b1;
    case({mapped_valid,logical_response})
     2'b10:queued<=queued+1'b1;
     2'b01:queued<=queued-1'b1;
    endcase
    for(i=0;i<16;i=i+1)begin
     case({mapped_valid && dispatch_slot==i,logical_response && head_slot==i})
      2'b10:references[i]<=references[i]+1'b1;
      2'b01:references[i]<=references[i]-1'b1;
     endcase
     if(allocate && dispatch_slot==i)begin
      allocated[i]<=1;complete[i]<=0;filling[i]<=1;cache_tag[i]<=mapped_addr[20:2];
     end
     if(response && returning[5:2]==i && returning[1:0]==3)begin complete[i]<=1;filling[i]<=0;end
    end
    if(allocate)begin jobs[jwp]<=dispatch_slot;jwp<=jwp+1'b1;end
    if(take_job)begin
     issue_active<=1;issue_phase<=0;issue_slot<=jobs[jrp];issue_base<=cache_tag[jobs[jrp]];
     jrp<=jrp+1'b1;
    end else if(read_en)begin
     if(issue_phase==3)begin issue_active<=0;issue_phase<=0;end
     else issue_phase<=issue_phase+1'b1;
    end
    case({allocate,take_job})
     2'b10:jobs_count<=jobs_count+1'b1;
     2'b01:jobs_count<=jobs_count-1'b1;
    endcase
    if(read_en)begin return_tags[twp]<={issue_slot,issue_phase};twp<=twp+1'b1;end
    if(response)begin cache_data[returning]<=memory_data;trp<=trp+1'b1;end
    case({read_en,response})
     2'b10:return_count<=return_count+1'b1;
     2'b01:return_count<=return_count-1'b1;
    endcase
    if((raw_read_en&&!logical_ready) || (mapped_valid&&queued==16&&!logical_response) ||
       (allocate&&!free_found) || (allocate&&jobs_count==16&&!take_job) ||
       (response&&return_count==0) || (read_en&&return_count==64&&!response) ||
       (read_en&&write_busy_mem) || (logical_response&&references[head_slot]==0))fault<=1;
   end
  end
 end
 exhibit_viewport #(.ENABLE_TRANSITION(1),.EXPLICIT_DIRECTION(1)) mapper(
  .clk(mem_clk),.rst(rst),.frame_latch(frame_latch),.pixel_step(speculate),
  .page_index(config_sync[2:0]),.dual_enable(config_sync[3]),.page_reverse(config_sync[4]),
  .zoom(config_sync[6:5]),.focus(config_sync[9:7]),.transition_mode(config_sync[11:10]),
  .panels_ready(config_sync[12]),.mapped_addr(mapped_addr),.mapped_valid(mapped_valid),
  .mapped_packed(mapped_packed),.mapped_half(mapped_half),.mapped_black(mapped_black));
endmodule
