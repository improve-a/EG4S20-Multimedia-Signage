// Experimental complete six-scene layer read adapter. One shared physical
// APUG011 four-word cache serves runtime plainRGB, packed compare and HFXL.
// Existing pins, SDRAM IP, frame reader and video/read clocks are unchanged.
module html_layer_memory_bridge #(parameter CACHE_SLOT_BITS=3,CONTEXT_BITS=3,BG_SLOT_BITS=4)(
 input mem_clk,rst,video_read_req,read_accept_mem,
 input[4:0]active_view,input[1:0]zoom,transition_mode,input[2:0]focus,
 input panels_ready,layer_resources_enabled,write_busy_mem,mem_ready,refresh_active,
 input raw_read_en,output read_en,output[20:0]read_addr,
 input response,input[31:0]memory_data,
 output[31:0]pixel_data,output logical_ready,logical_response,busy,output fault
);
 (* async_reg="true" *)reg[13:0]config_meta,config_sync;
 reg[13:0]frame_config;reg accept_previous,frame_active;
 wire frame_latch=read_accept_mem&&!accept_previous;
 wire page_event=frame_latch&&(!frame_active||config_sync[3:0]!=frame_config[3:0]);
 reg[18:0]issued;reg[3:0]outstanding,queued;reg[2:0]mapper_inflight;
 wire run_start;
 wire speculate=frame_active&&issued<307200&&outstanding<6&&!frame_latch;
 wire mapped_valid,mapped_packed,mapped_half,mapped_black;wire[20:0]mapped_addr;
 wire[9:0]source_x,logical_x,canvas_start_x;wire[8:0]source_y,logical_y,canvas_start_y;
 wire[2:0]source_page,current_page,previous_page;wire source_old,source_dual,previous_active;wire[1:0]source_repeat;
 html_layer_viewport #(.ENABLE_TRANSITION(1),.EXPLICIT_DIRECTION(1))mapper(
 .clk(mem_clk),.rst(rst),.frame_latch(frame_latch),.pixel_step(speculate),
 .page_index(config_sync[2:0]),.dual_enable(config_sync[3]),.zoom(config_sync[6:5]),.focus(config_sync[9:7]),
 .transition_mode(config_sync[11:10]),.panels_ready(config_sync[12]),.page_reverse(config_sync[4]),
 .mapped_addr(mapped_addr),.mapped_valid(mapped_valid),.mapped_packed(mapped_packed),.mapped_half(mapped_half),.mapped_black(mapped_black),
 .source_canvas_x(source_x),.source_canvas_y(source_y),.source_logical_x(logical_x),.source_logical_y(logical_y),
 .source_scene_page(source_page),.source_old(source_old),.source_dual(source_dual),.source_repeat(source_repeat),.run_start(run_start),
 .current_page(current_page),.previous_page(previous_page),.previous_active(previous_active),.canvas_start_x(canvas_start_x),.canvas_start_y(canvas_start_y));
 reg[59:0]entries[0:7];reg[2:0]wp,rp;
 wire[59:0]head=entries[rp];
 wire[20:0]head_addr;wire hp,hh,hb,ho,hd;wire[9:0]hx,hlx;wire[8:0]hy;wire[2:0]hpage;wire[1:0]hr;
 assign {head_addr,hp,hh,hb,hx,hy,hlx,hpage,ho,hd,hr}=head;
 wire frontend_ready,frontend_valid,engine_ready,geometry_fault;
 wire[2:0]engine_page;wire[20:0]engine_bg,engine_rgba0,engine_rgba1,engine_direct_addr;
 wire[1:0]engine_lane,engine_repeat,engine_count;wire[7:0]engine_op0,engine_op1;
 wire engine_direct,engine_packed,engine_half,engine_black;
 html_layer_span_frontend geometry(
 .clk(mem_clk),.rst(rst),.flush(frame_latch),.layer_resources_enabled(frame_config[13]),.page_event(page_event),.page_reverse(config_sync[4]),
 .current_page(current_page),.previous_page(previous_page),.previous_active(previous_active),.canvas_start_x(canvas_start_x),.canvas_start_y(canvas_start_y),
 .i_valid(queued!=0),.i_ready(frontend_ready),.i_page(hpage),.i_old(ho),.i_dual(hd),.i_x(hx),.i_logical_x(hlx),.i_y(hy),.i_repeat(hr),
 .i_mapped_addr(head_addr),.i_packed(hp),.i_half(hh),.i_black(hb),.o_valid(frontend_valid),.o_ready(engine_ready),
 .o_page(engine_page),.o_bg_addr(engine_bg),.o_bg_lane(engine_lane),.o_repeat(engine_repeat),.o_rgba_count(engine_count),
 .o_rgba0_addr(engine_rgba0),.o_rgba1_addr(engine_rgba1),.o_opacity0(engine_op0),.o_opacity1(engine_op1),
 .o_direct(engine_direct),.o_packed(engine_packed),.o_half(engine_half),.o_black(engine_black),.o_packed_addr(engine_direct_addr),.fault(geometry_fault));
 wire palette_enable;wire[11:0]palette_address;wire[23:0]palette_data;
 html_layer_palette palette(mem_clk,palette_enable,palette_address,palette_data);
 wire engine_busy,engine_fault;
 html_layer_pixel_engine #(.CACHE_SLOT_BITS(CACHE_SLOT_BITS),.CONTEXT_BITS(CONTEXT_BITS),.BG_SLOT_BITS(BG_SLOT_BITS)) engine(
 .clk(mem_clk),.rst(rst),.flush(frame_latch),.i_valid(frontend_valid),.i_ready(engine_ready),.i_page(engine_page),
 .i_bg_addr(engine_bg),.i_bg_lane(engine_lane),.i_repeat(engine_repeat),.i_rgba_count(engine_count),
 .i_rgba0_addr(engine_rgba0),.i_rgba1_addr(engine_rgba1),.i_opacity0(engine_op0),.i_opacity1(engine_op1),
 .i_direct(engine_direct),.i_packed(engine_packed),.i_half(engine_half),.i_black(engine_black),.i_packed_addr(engine_direct_addr),
 .palette_read(palette_enable),.palette_addr(palette_address),.palette_data(palette_data),
 .raw_read_en(raw_read_en),.logical_ready(logical_ready),.logical_response(logical_response),.pixel_data(pixel_data),
 .mem_ready(mem_ready),.refresh_active(refresh_active),.write_busy_mem(write_busy_mem),.read_en(read_en),.read_addr(read_addr),
 .response(response),.memory_data(memory_data),.busy(engine_busy),.fault(engine_fault));
 wire front_accept=queued!=0&&frontend_ready;
 wire map_emit=speculate&&run_start;
 assign busy=engine_busy||mapper_inflight!=0;
 reg local_fault;assign fault=local_fault|engine_fault|geometry_fault;
 always@(posedge mem_clk)begin
  if(rst)begin config_meta<=0;config_sync<=0;frame_config<=0;accept_previous<=0;frame_active<=0;issued<=0;outstanding<=0;queued<=0;mapper_inflight<=0;wp<=0;rp<=0;local_fault<=0;end
  else begin
   config_meta<={layer_resources_enabled,panels_ready,transition_mode,focus,zoom,active_view};config_sync<=config_meta;
   accept_previous<=read_accept_mem;
   if(frame_latch)begin
    if(busy||raw_read_en||response||mapped_valid)local_fault<=1;
    frame_config<=config_sync;frame_active<=1;issued<=0;outstanding<=0;queued<=0;mapper_inflight<=0;wp<=0;rp<=0;
   end else begin
    if(speculate)issued<=issued+1'b1;
    if(mapped_valid)begin entries[wp]<={mapped_addr,mapped_packed,mapped_half,mapped_black,source_x,source_y,logical_x,source_page,source_old,source_dual,source_repeat};wp<=wp+1'b1;end
    if(front_accept)rp<=rp+1'b1;
    case({map_emit,front_accept})2'b10:outstanding<=outstanding+1'b1;2'b01:outstanding<=outstanding-1'b1;endcase
    case({mapped_valid,front_accept})2'b10:queued<=queued+1'b1;2'b01:queued<=queued-1'b1;endcase
    case({map_emit,mapped_valid})2'b10:mapper_inflight<=mapper_inflight+1'b1;2'b01:mapper_inflight<=mapper_inflight-1'b1;endcase
    if((mapped_valid&&queued==8&&!front_accept)||(front_accept&&outstanding==0)||(mapped_valid&&mapper_inflight==0))local_fault<=1;
   end
  end
 end
endmodule
