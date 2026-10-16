// Finite two-source renderer:32 lightweight ordered fetch records are kept
// separate from8 ready-data compute records. Physical groups and outstanding
// texture ownership never depend on compositor feedback latency.
module html_layer_pixel_engine #(parameter CONTEXT_BITS=3,CACHE_SLOT_BITS=4,BG_SLOT_BITS=4,ENABLE_PHYSICAL_FAIRNESS=0)(
 input clk,rst,flush,
 input i_valid,output i_ready,
 input[2:0]i_page,input[20:0]i_bg_addr,input[1:0]i_bg_lane,i_repeat,i_rgba_count,
 input[20:0]i_rgba0_addr,i_rgba1_addr,input[7:0]i_opacity0,i_opacity1,
 input i_direct,i_packed,i_half,i_black,input[20:0]i_packed_addr,
 output palette_read,output[11:0]palette_addr,input[23:0]palette_data,
 input raw_read_en,output logical_ready,logical_response,output[31:0]pixel_data,
 input mem_ready,refresh_active,write_busy_mem,
 output read_en,output[20:0]read_addr,input response,input[31:0]memory_data,
 output busy,output fault,input pause_new_groups,output physical_busy
);
 localparam CONTEXTS=1<<CONTEXT_BITS,BG_SLOTS=1<<BG_SLOT_BITS;
 localparam LOADING=0,FIRST_READY=1,FIRST_FLIGHT=2,SECOND_READY=3,SECOND_FLIGHT=4,DONE=5;
 reg[31:0]allocated,rgba0_ready,rgba1_ready;
 reg[4:0]wp,rp;reg[5:0]fetch_count;
 reg[BG_SLOT_BITS-1:0]bg_slot[0:31];
 reg[BG_SLOTS-1:0]bg_valid;
 reg[1:0]bg_refs[0:BG_SLOTS-1];reg bg_previous_valid;reg[20:0]bg_previous_addr;reg[BG_SLOT_BITS-1:0]bg_previous_slot;
 reg free_bg;reg[BG_SLOT_BITS-1:0]free_bg_slot;integer k;
 always@*begin free_bg=0;free_bg_slot=0;for(k=BG_SLOTS-1;k>=0;k=k-1)if(bg_refs[k]==0)begin free_bg=1;free_bg_slot=k;end end
 wire bg_hit=bg_previous_valid&&i_bg_addr==bg_previous_addr;
 wire[BG_SLOT_BITS-1:0]new_bg_slot=bg_hit?bg_previous_slot:free_bg_slot;
 reg dispatch_active;reg[3:0]dispatch_mask;
 reg[4:0]dispatch_context;reg[BG_SLOT_BITS-1:0]dispatch_bg_slot;
 reg[20:0]dispatch_bg,dispatch_rgba0,dispatch_rgba1,dispatch_packed;
 assign i_ready=!flush&&fetch_count<32&&!dispatch_active&&(i_direct||i_packed||bg_hit||free_bg);
 wire begin_pixel=i_valid&&i_ready;
 wire[3:0]initial_mask=(i_direct||i_packed)?4'b1000:{1'b0,i_rgba_count==2,i_rgba_count!=0,!bg_hit};
 wire[3:0]mask=dispatch_active?dispatch_mask:initial_mask;
 reg[1:0]task_kind;
 always@*begin if(mask[0])task_kind=0;else if(mask[1])task_kind=1;else if(mask[2])task_kind=2;else task_kind=3;end
 wire[4:0]task_context=dispatch_active?dispatch_context:wp;
 wire[BG_SLOT_BITS-1:0]task_bg_slot=dispatch_active?dispatch_bg_slot:new_bg_slot;
 wire[20:0]bg_address=dispatch_active?dispatch_bg:i_bg_addr;
 wire[20:0]rgba0_address=dispatch_active?dispatch_rgba0:i_rgba0_addr;
 wire[20:0]rgba1_address=dispatch_active?dispatch_rgba1:i_rgba1_addr;
 wire[20:0]packed_address=dispatch_active?dispatch_packed:i_packed_addr;
 wire[20:0]task_address=task_kind==0?bg_address:task_kind==1?rgba0_address:task_kind==2?rgba1_address:packed_address;
 wire[7:0]task_tag={task_kind,1'b0,(task_kind==0?{{(5-BG_SLOT_BITS){1'b0}},task_bg_slot}:task_context)};
 wire task_valid=!flush&&(dispatch_active||begin_pixel)&&mask!=0;
 wire task_ready,task_result;wire[31:0]task_data;wire[7:0]returned_tag;wire cache_fault;
 wire task_accept=task_valid&&task_ready;
 wire[3:0]remaining_mask=mask&~(4'b0001<<task_kind);
 html_layer_cache #(.ENABLE_PHYSICAL_FAIRNESS(ENABLE_PHYSICAL_FAIRNESS),.TAG_BITS(8),.CACHE_SLOT_BITS(CACHE_SLOT_BITS))cache(
 .clk(clk),.rst(rst),.flush(flush),.request_valid(task_valid),.request_addr(task_address),.request_tag(task_tag),.request_ready(task_ready),
 .result_valid(task_result),.result_ready(1'b1),.result_data(task_data),.result_tag(returned_tag),
 .mem_ready(mem_ready),.refresh_active(refresh_active),.write_busy_mem(write_busy_mem),.read_en(read_en),.read_addr(read_addr),
 .response(response),.memory_data(memory_data),.busy(busy),.fault(cache_fault),.pause_new_groups(pause_new_groups),.physical_busy(physical_busy));
 wire[1:0]return_kind=returned_tag[7:6];wire[4:0]return_context=returned_tag[4:0];
 wire join_write=task_result&&return_kind!=0;
 wire[5:0]join_write_addr={return_kind==2,return_context};
 // Immutable metadata has one write and one prefetched head read. No reset
 // touches RAM payload; allocation/valid bits exclude stale records.
 wire[31:0]meta_input={3'd0,i_black,i_half,i_packed,(i_direct||i_packed),i_rgba_count,i_bg_lane,i_page,i_opacity1,i_opacity0,i_repeat};
 wire[31:0]meta_head;reg meta_valid;
 wire launch;
 wire[4:0]meta_read_addr=launch?rp+1'b1:rp;
 html_layer_join_ram metadata(clk,begin_pixel,{1'b0,wp},meta_input,fetch_count!=0,{1'b0,meta_read_addr},meta_head);
 reg[CONTEXTS-1:0]compute_allocated;reg[CONTEXT_BITS-1:0]cwp,crp;reg[CONTEXT_BITS:0]compute_count;
 reg[2:0]state[0:CONTEXTS-1];reg[23:0]base_rgb[0:CONTEXTS-1],blended_rgb[0:CONTEXTS-1];reg[CONTEXTS-1:0]use_blended;
 reg[31:0]rgba1[0:CONTEXTS-1];
 reg[7:0]op1[0:CONTEXTS-1];
 reg[1:0]repeats[0:CONTEXTS-1],rgba_count[0:CONTEXTS-1];reg[CONTEXTS-1:0]black_flags;
 reg load_pending,second_pending;reg[CONTEXT_BITS-1:0]load_slot,second_slot;
 reg[31:0]load_meta;reg[4:0]load_fetch_slot;
 wire head_ready=meta_head[25]?rgba0_ready[rp]:(bg_valid[bg_slot[rp]]&&(meta_head[24:23]==0||rgba0_ready[rp])&&(meta_head[24:23]!=2||rgba1_ready[rp]));
 // Two RGBA fetches consume two consecutive join-read cycles. Background
 // and one-source pixels may launch every cycle, independent of blending.
 wire read_second=load_pending&&load_meta[24:23]==2&&!load_meta[25];
 wire retire;
 assign launch=fetch_count!=0&&allocated[rp]&&meta_valid&&head_ready&&!read_second&&(compute_count<CONTEXTS||retire)&&!flush;
 wire join_read=read_second||(launch&&(meta_head[25]||meta_head[24:23]!=0));
 wire[5:0]join_read_addr=read_second?{1'b1,load_fetch_slot}:{1'b0,rp};wire[31:0]join_data;
 html_layer_join_ram joins(clk,join_write,join_write_addr,task_data,join_read,join_read_addr,join_data);
 wire[31:0]palette_word;
 wire bg_write=task_result&&return_kind==0;
 wire[BG_SLOT_BITS-1:0]bg_read_slot=bg_slot[launch?rp+1'b1:rp];
 wire[3:0]bg_read_addr={{(4-BG_SLOT_BITS){1'b0}},bg_read_slot};
 html_layer_bg_ram background_words(clk,bg_write,returned_tag[3:0],task_data,fetch_count!=0,bg_read_addr,palette_word);
 wire[9:0]palette_index=meta_head[22:21]==0?palette_word[9:0]:meta_head[22:21]==1?palette_word[19:10]:palette_word[29:20];
 assign palette_read=launch&&!meta_head[25];
 assign palette_addr={meta_head[20:18],palette_index[8:0]};
 wire[15:0]packed_value=load_meta[27]?join_data[31:16]:join_data[15:0];
 wire[23:0]expanded_rgb={{packed_value[15:11],packed_value[15:13]},{packed_value[10:5],packed_value[10:9]},{packed_value[4:0],packed_value[4:2]}};
 reg blend_found,blend_second;reg[CONTEXT_BITS-1:0]blend_slot;integer j;
 always@*begin blend_found=0;blend_second=0;blend_slot=0;
  for(j=CONTEXTS-1;j>=0;j=j-1)if(compute_allocated[j]&&state[j]==SECOND_READY)begin
   blend_found=1;blend_second=state[j]==SECOND_READY;blend_slot=j;
  end
 end
 wire blend_result;wire[CONTEXT_BITS:0]blend_result_tag;wire[23:0]blend_rgb;
 // First source blends directly from the ready-data load pipeline. Only
 // second-source feedback needs a saved texture word and scheduler entry.
 wire first_blend=load_pending&&!load_meta[25]&&load_meta[24:23]!=0;
 html_layer_blend #(.TAG_BITS(CONTEXT_BITS+1))compositor(clk,rst||flush,(first_blend||blend_found)&&!flush,
 first_blend?{1'b0,load_slot}:{1'b1,blend_slot},first_blend?palette_data:blended_rgb[blend_slot],
 first_blend?join_data:rgba1[blend_slot],first_blend?load_meta[9:2]:op1[blend_slot],blend_result,blend_result_tag,blend_rgb);
 reg[9:0]result_low[0:15];reg result_head_valid;reg[3:0]result_wp,result_rp;reg[4:0]result_count;
 reg repeat_active;reg[1:0]repeat_left;
 wire result_pop;
 wire[15:0]result_rg;
 wire[3:0]result_read_addr=result_pop?result_rp+1'b1:result_rp;
 wire[23:0]retired_rgb=black_flags[crp]?24'd0:(use_blended[crp]?blended_rgb[crp]:base_rgb[crp]);
 html_layer_result_rg_ram result_rg_words(clk,retire,result_wp,retired_rgb[23:8],result_count!=0,result_read_addr,result_rg);
 wire[25:0]result_head={result_low[result_rp][9:8],result_rg,result_low[result_rp][7:0]};
 wire[1:0]remaining_repeat=repeat_active?repeat_left:result_head[25:24];
 assign logical_ready=result_count!=0&&result_head_valid&&!flush;
 assign logical_response=raw_read_en&&logical_ready;
 assign pixel_data={result_head[23:0],8'd0};
 assign result_pop=logical_response&&remaining_repeat==1;
 assign retire=compute_count!=0&&compute_allocated[crp]&&state[crp]==DONE&&(result_count<16||result_pop)&&!flush;
 reg local_fault;assign fault=local_fault|cache_fault;
 always@(posedge clk)begin
  if(load_pending)base_rgb[load_slot]<=load_meta[25]?(load_meta[26]?expanded_rgb:join_data[31:8]):palette_data;
  if(blend_result)blended_rgb[blend_result_tag[CONTEXT_BITS-1:0]]<=blend_rgb;
 end
 integer i;
 always@(posedge clk)begin
  if(rst||flush)begin
   allocated<=0;wp<=0;rp<=0;fetch_count<=0;rgba0_ready<=0;rgba1_ready<=0;
   bg_valid<=0;bg_previous_valid<=0;bg_previous_addr<=0;bg_previous_slot<=0;dispatch_active<=0;dispatch_mask<=0;meta_valid<=0;
   compute_allocated<=0;cwp<=0;crp<=0;compute_count<=0;load_pending<=0;second_pending<=0;
   result_wp<=0;result_rp<=0;result_count<=0;result_head_valid<=0;repeat_active<=0;repeat_left<=0;
   if(rst)local_fault<=0;
   for(i=0;i<BG_SLOTS;i=i+1)bg_refs[i]<=0;
  end else begin
   if(launch)meta_valid<=fetch_count>1;else if(fetch_count!=0)meta_valid<=1;
   if(begin_pixel&&!i_direct&&!i_packed&&bg_refs[new_bg_slot]==3&&!(launch&&!meta_head[25]&&bg_slot[rp]==new_bg_slot))local_fault<=1;
   if(begin_pixel)begin
    allocated[wp]<=1;bg_slot[wp]<=new_bg_slot;
    rgba0_ready[wp]<=0;rgba1_ready[wp]<=0;wp<=wp+1'b1;
    if(!i_direct&&!i_packed&&!bg_hit)begin bg_valid[new_bg_slot]<=0;bg_previous_valid<=1;bg_previous_addr<=i_bg_addr;bg_previous_slot<=new_bg_slot;end
    dispatch_context<=wp;dispatch_bg_slot<=new_bg_slot;dispatch_bg<=i_bg_addr;dispatch_rgba0<=i_rgba0_addr;dispatch_rgba1<=i_rgba1_addr;dispatch_packed<=i_packed_addr;
    dispatch_mask<=task_accept?remaining_mask:initial_mask;dispatch_active<=(task_accept?remaining_mask:initial_mask)!=0;
    if(i_repeat==0||i_rgba_count>2||i_bg_lane>2||i_page>5)local_fault<=1;
   end else if(dispatch_active&&task_accept)begin dispatch_mask<=remaining_mask;if(remaining_mask==0)dispatch_active<=0;end
   if(launch)begin
    allocated[rp]<=0;rp<=rp+1'b1;load_slot<=cwp;load_meta<=meta_head;load_fetch_slot<=rp;
    compute_allocated[cwp]<=1;state[cwp]<=LOADING;cwp<=cwp+1'b1;
    if(!meta_head[25]&&bg_refs[bg_slot[rp]]==0)local_fault<=1;
    if(palette_read&&palette_index[9])local_fault<=1;
   end
   load_pending<=launch;second_pending<=read_second;if(read_second)second_slot<=load_slot;
   if(load_pending)begin
    repeats[load_slot]<=load_meta[1:0];op1[load_slot]<=load_meta[17:10];
    rgba_count[load_slot]<=load_meta[24:23];black_flags[load_slot]<=load_meta[28];
    use_blended[load_slot]<=!load_meta[25]&&load_meta[24:23]!=0;
    state[load_slot]<=load_meta[25]||load_meta[24:23]==0?DONE:FIRST_FLIGHT;
   end
   if(second_pending)rgba1[second_slot]<=join_data;
   case({begin_pixel,launch})2'b10:fetch_count<=fetch_count+1'b1;2'b01:fetch_count<=fetch_count-1'b1;endcase
   for(i=0;i<BG_SLOTS;i=i+1)begin
    case({begin_pixel&&!i_direct&&!i_packed&&new_bg_slot==i,launch&&!meta_head[25]&&bg_slot[rp]==i})
     2'b10:bg_refs[i]<=bg_refs[i]+1'b1;2'b01:bg_refs[i]<=bg_refs[i]-1'b1;
    endcase
   end
   if(task_result)begin
    if(return_kind==0)begin bg_valid[returned_tag[3:0]]<=1;end
    else begin
     if(return_kind==2)rgba1_ready[return_context]<=1;else rgba0_ready[return_context]<=1;
     if(!allocated[return_context])local_fault<=1;
    end
   end
   if(blend_found&&!first_blend)state[blend_slot]<=SECOND_FLIGHT;
   if(blend_result)begin
    state[blend_result_tag[CONTEXT_BITS-1:0]]<=!blend_result_tag[CONTEXT_BITS]&&rgba_count[blend_result_tag[CONTEXT_BITS-1:0]]==2?SECOND_READY:DONE;
    if(!compute_allocated[blend_result_tag[CONTEXT_BITS-1:0]])local_fault<=1;
   end
   if(result_pop)result_head_valid<=result_count>1;else if(result_count!=0)result_head_valid<=1;
   if(logical_response)begin
    if(remaining_repeat>1)begin repeat_left<=remaining_repeat-1'b1;repeat_active<=1;end
    else begin repeat_active<=0;result_rp<=result_rp+1'b1;end
   end
   if(retire)begin
    result_low[result_wp]<={repeats[crp],retired_rgb[7:0]};result_wp<=result_wp+1'b1;
    // A full compute ring may retire and reuse the same entry together.
    if(!(launch&&cwp==crp))compute_allocated[crp]<=0;crp<=crp+1'b1;
   end
   case({launch,retire})2'b10:compute_count<=compute_count+1'b1;2'b01:compute_count<=compute_count-1'b1;endcase
   case({retire,result_pop})2'b10:result_count<=result_count+1'b1;2'b01:result_count<=result_count-1'b1;endcase
   if(join_write&&join_read&&join_write_addr==join_read_addr)local_fault<=1;
  end
 end
endmodule

// Independent background word store: it never competes with metadata writes.
// Explicit synchronous read bypass makes same-address return/lookup defined.
module html_layer_bg_ram(input clk,input we,input[3:0]wa,input[31:0]wd,input re,input[3:0]ra,output[31:0]rd);
 reg[31:0]memory[0:15];reg[31:0]q,bypass_data;reg bypass_valid;
 always@(posedge clk)begin
  if(we)memory[wa]<=wd;
  if(re)begin q<=memory[ra];bypass_valid<=we&&wa==ra;bypass_data<=wd;end
 end
 assign rd=bypass_valid?bypass_data:q;
endmodule

// Two colour channels use one proven16bit true-dual-port32K block. Blue and
// repetition remain in small FFs. Head validity explicitly excludes stale
// RAM data at empty insertion or simultaneous pop-last/push boundaries.
module html_layer_result_rg_ram(input clk,input we,input[3:0]wa,input[15:0]wd,input re,input[3:0]ra,output[15:0]rd);
`ifdef HTML_SIM
 reg[15:0]memory[0:63];reg[15:0]q;
 always@(posedge clk)begin if(we)memory[{2'b0,wa}]<=wd;if(re)q<=memory[{2'b0,ra}];end
 assign rd=q;
`else
 EG_LOGIC_BRAM #(.DATA_WIDTH_A(16),.ADDR_WIDTH_A(6),.DATA_DEPTH_A(64),.DATA_WIDTH_B(16),.ADDR_WIDTH_B(6),.DATA_DEPTH_B(64),
 .MODE("DP"),.REGMODE_A("NOREG"),.REGMODE_B("NOREG"),.WRITEMODE_A("NORMAL"),.WRITEMODE_B("NORMAL"),
 .RESETMODE("SYNC"),.BYTE_ENABLE(0),.IMPLEMENT("32K"),.INIT_FILE("NONE"))storage(
 .clka(clk),.addra({2'b0,wa}),.dia(wd),.cea(1'b1),.ocea(1'b1),.wea(we),.rsta(1'b0),.bea(1'b1),.doa(),
 .clkb(clk),.addrb({2'b0,ra}),.dib(16'b0),.ceb(re),.oceb(1'b1),.web(1'b0),.rstb(1'b0),.beb(1'b1),.dob(rd));
`endif
endmodule
