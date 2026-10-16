// Generic ordered word-task cache for the experimental lossless layer renderer.
// The production html_memory_bridge remains separate and unchanged.
module html_layer_cache #(
 parameter TAG_BITS=12, parameter CACHE_SLOT_BITS=5
)(
 input clk,rst,flush,
 input request_valid,input [20:0] request_addr,input [TAG_BITS-1:0] request_tag,
 output request_ready,
 output result_valid,input result_ready,
 output [31:0] result_data,output [TAG_BITS-1:0] result_tag,
 input mem_ready,refresh_active,write_busy_mem,
 output read_en,output [20:0] read_addr,
 input response,input [31:0] memory_data,
 output busy,output reg fault
);
 localparam SLOTS=1<<CACHE_SLOT_BITS;
 localparam WORD_BITS=CACHE_SLOT_BITS+2;
 reg [18:0] cache_tag[0:SLOTS-1];
 reg [5:0] references[0:SLOTS-1];
 reg [SLOTS-1:0] allocated,complete,filling;
 // Separate one-write/one-read synchronous memory, no reset on payload.
 // SLOTS*4 words use block RAM rather than a large pixel-data mux.
 reg [31:0] cache_data[0:SLOTS*4-1];
 reg [31:0] ram_word;
 reg read_pending;
 reg [TAG_BITS-1:0] pending_tag;
 reg [31:0] output_data[0:1];
 reg [TAG_BITS-1:0] output_tag[0:1];
 reg output_wp,output_rp;
 reg [1:0] output_count;
 reg entry_valid;
 reg [4:0] wp,rp;
 reg [5:0] queued;
 wire [TAG_BITS+WORD_BITS-1:0] head;
 wire [CACHE_SLOT_BITS-1:0] head_slot=head[WORD_BITS-1:2];
 assign result_data=output_data[output_rp];
 assign result_tag=output_tag[output_rp];
 assign result_valid=output_count!=0 && !flush;
 wire retire=result_valid&&result_ready;
 wire lookup=queued!=0 && entry_valid && complete[head_slot] && !flush &&
             ({1'b0,output_count}+read_pending < 2 || retire);
 reg hit,free_found;
 reg [CACHE_SLOT_BITS-1:0] hit_slot,free_slot;
 assign request_ready=queued<32 && !flush && (hit || free_found);
 wire accept=request_valid&&request_ready;

 integer k;
 always @*begin
  hit=0;hit_slot=0;free_found=0;free_slot=0;
  for(k=SLOTS-1;k>=0;k=k-1)begin
   if(allocated[k] && cache_tag[k]==request_addr[20:2])begin hit=1;hit_slot=k;end
   if(references[k]==0 && !filling[k])begin free_found=1;free_slot=k;end
  end
 end
 wire [CACHE_SLOT_BITS-1:0] dispatch_slot=hit?hit_slot:free_slot;
 wire allocate=accept&&!hit;
 wire [4:0] entry_read_addr=lookup?rp+1'b1:rp;
 html_layer_queue_ram #(.WIDTH(TAG_BITS+WORD_BITS)) task_queue(clk,accept,{1'b0,wp},{request_tag,dispatch_slot,request_addr[1:0]},queued!=0,{1'b0,entry_read_addr},head);

 reg [CACHE_SLOT_BITS-1:0] jobs[0:SLOTS-1];
 reg [CACHE_SLOT_BITS-1:0] jwp,jrp;
 reg [CACHE_SLOT_BITS:0] jobs_count;
 reg issue_active;
 reg [1:0] issue_phase;
 reg [CACHE_SLOT_BITS-1:0] issue_slot;
 reg [18:0] issue_base;
 assign read_en=issue_active && mem_ready && (issue_phase!=0 || !refresh_active);
 assign read_addr={issue_base,issue_phase};
 wire take_job=!flush && jobs_count!=0 && mem_ready && !refresh_active && !write_busy_mem &&
               (!issue_active || (read_en && issue_phase==3));
 // APUG011 responses preserve the order of issued four-word groups.
 // A slot cannot be reused while filling; hence at most SLOTS distinct
 // groups can be outstanding. Store the slot once, not once per word.
 reg[CACHE_SLOT_BITS-1:0]return_groups[0:SLOTS-1];
 reg[CACHE_SLOT_BITS-1:0]twp,trp;
 reg[CACHE_SLOT_BITS:0]return_groups_count;
 reg[1:0]return_phase;
 reg[6:0]return_count;
 wire group_push=read_en&&issue_phase==0;
 wire group_pop=response&&return_phase==3;
 wire[WORD_BITS-1:0]returning={return_groups[trp],return_phase};
 wire return_head_valid=return_groups_count!=0;
 always@(posedge clk)if(group_push)return_groups[twp]<=issue_slot;
 assign busy=issue_active || jobs_count!=0 || return_count!=0;
 integer i;
 // The RAM read and payload write both remain outside reset/flush logic.
 always @(posedge clk)begin
  if(lookup)ram_word<=cache_data[head[WORD_BITS-1:0]];
  if(response && return_count!=0 && return_head_valid && !flush)cache_data[returning]<=memory_data;
 end
 always @(posedge clk)begin
  if(rst)begin
   allocated<=0;complete<=0;filling<=0;wp<=0;rp<=0;queued<=0;entry_valid<=0;
   jwp<=0;jrp<=0;jobs_count<=0;issue_active<=0;issue_phase<=0;issue_slot<=0;issue_base<=0;
   twp<=0;trp<=0;return_count<=0;return_phase<=0;return_groups_count<=0;fault<=0;
   read_pending<=0;output_wp<=0;output_rp<=0;output_count<=0;pending_tag<=0;
   for(i=0;i<SLOTS;i=i+1)begin cache_tag[i]<=0;references[i]<=0;end
  end else if(flush)begin
   if(busy || response)fault<=1;
   allocated<=0;complete<=0;filling<=0;wp<=0;rp<=0;queued<=0;entry_valid<=0;
   jwp<=0;jrp<=0;jobs_count<=0;issue_active<=0;issue_phase<=0;
   twp<=0;trp<=0;return_count<=0;return_phase<=0;return_groups_count<=0;
   read_pending<=0;output_wp<=0;output_rp<=0;output_count<=0;
   for(i=0;i<SLOTS;i=i+1)references[i]<=0;
  end else begin
   if(accept)wp<=wp+1'b1;
   if(lookup)entry_valid<=queued>1;else if(queued!=0)entry_valid<=1;
   if(lookup)rp<=rp+1'b1;
   read_pending<=lookup;
   if(lookup)pending_tag<=head[TAG_BITS+WORD_BITS-1:WORD_BITS];
   if(read_pending)begin output_data[output_wp]<=ram_word;output_tag[output_wp]<=pending_tag;output_wp<=!output_wp;end
   if(retire)output_rp<=!output_rp;
   case({read_pending,retire})2'b10:output_count<=output_count+1'b1;2'b01:output_count<=output_count-1'b1;endcase
   case({accept,lookup})2'b10:queued<=queued+1'b1;2'b01:queued<=queued-1'b1;endcase
   for(i=0;i<SLOTS;i=i+1)begin
    case({accept&&dispatch_slot==i,lookup&&head_slot==i})
     2'b10:references[i]<=references[i]+1'b1;
     2'b01:references[i]<=references[i]-1'b1;
    endcase
    if(allocate&&dispatch_slot==i)begin
     allocated[i]<=1;complete[i]<=0;filling[i]<=1;cache_tag[i]<=request_addr[20:2];
    end
    if(response&&return_head_valid&&return_count!=0&&returning[WORD_BITS-1:2]==i&&returning[1:0]==3)begin complete[i]<=1;filling[i]<=0;end
   end
   if(allocate)begin jobs[jwp]<=dispatch_slot;jwp<=jwp+1'b1;end
   if(take_job)begin
    issue_active<=1;issue_phase<=0;issue_slot<=jobs[jrp];issue_base<=cache_tag[jobs[jrp]];jrp<=jrp+1'b1;
   end else if(read_en)begin
    if(issue_phase==3)begin issue_active<=0;issue_phase<=0;end
    else issue_phase<=issue_phase+1'b1;
   end
   case({allocate,take_job})2'b10:jobs_count<=jobs_count+1'b1;2'b01:jobs_count<=jobs_count-1'b1;endcase
   if(group_push)twp<=twp+1'b1;
   if(group_pop)trp<=trp+1'b1;
   if(response)return_phase<=return_phase+1'b1;
   case({group_push,group_pop})2'b10:return_groups_count<=return_groups_count+1'b1;2'b01:return_groups_count<=return_groups_count-1'b1;endcase
   case({read_en,response})2'b10:return_count<=return_count+1'b1;2'b01:return_count<=return_count-1'b1;endcase
   if((allocate&&!free_found)||(allocate&&jobs_count==SLOTS&&!take_job)||
      (response&&(return_count==0||!return_head_valid))||(read_en&&return_count==64&&!response)||
      (group_push&&return_groups_count==SLOTS&&!group_pop)||(read_en&&write_busy_mem)||(lookup&&references[head_slot]==0)||(output_count==2&&read_pending&&!retire))fault<=1;
  end
 end
endmodule

// Read-only head prefetch converts dynamic FIFO payload muxes into clocked
// block RAM. Ownership counters and valid bits remain in the caller.
module html_layer_queue_ram #(parameter WIDTH=8)(input clk,input write_en,input[5:0]write_addr,input[WIDTH-1:0]write_data,
 input read_en,input[5:0]read_addr,output[WIDTH-1:0]read_data);

 reg[WIDTH-1:0]memory[0:31];reg[WIDTH-1:0]q;
 always@(posedge clk)begin if(write_en)memory[write_addr[4:0]]<=write_data;if(read_en)q<=memory[read_addr[4:0]];end
 assign read_data=q;

endmodule
