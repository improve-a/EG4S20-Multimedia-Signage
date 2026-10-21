// Experimental double-bank row preparation for this six-scene atlas.
// At most four components intersect one scene row; eight spans safely hold
// old/new arbitrary page pairs. Geometry work overlaps the preceding row.
module html_layer_span_frontend(
 input clk,rst,flush,layer_resources_enabled,page_event,page_reverse,
 input[2:0]current_page,previous_page,input previous_active,
 input[9:0]canvas_start_x,input[8:0]canvas_start_y,
 input i_valid,output i_ready,
 input[2:0]i_page,input i_old,i_dual,input[9:0]i_x,i_logical_x,input[8:0]i_y,
 input[1:0]i_repeat,input[20:0]i_mapped_addr,input i_packed,i_half,i_black,
 output o_valid,input o_ready,
 output[2:0]o_page,output[20:0]o_bg_addr,output[1:0]o_bg_lane,o_repeat,o_rgba_count,
 output[20:0]o_rgba0_addr,o_rgba1_addr,output[7:0]o_opacity0,o_opacity1,
 output o_direct,o_packed,o_half,o_black,output[20:0]o_packed_addr,
 output reg fault
);
 function[20:0]page_base;input[2:0]p;begin case(p)
 0:page_base=0;1:page_base=275200;2:page_base=586240;3:page_base=890880;4:page_base=1202688;5:page_base=1514240;default:page_base=0;endcase end endfunction
 function[20:0]bg_base;input[2:0]p;begin case(p)
 0:bg_base=648;1:bg_base=275872;2:bg_base=586912;3:bg_base=891552;4:bg_base=1203360;5:bg_base=1514896;default:bg_base=648;endcase end endfunction
 reg[1:0]prepared,need_fill;reg[8:0]bank_y[0:1];reg[2:0]new_count[0:1],old_count[0:1];
 reg[20:0]span_base[0:15];reg signed[10:0]span_min[0:15],span_max[0:15];
 reg[1:0]span_role[0:15];reg[7:0]span_alpha[0:15];
 // Only the incoming hero scales. Old hero/giant and both text classes
 // translate, so their integer source offset replaces six wide recurrences.
 reg signed[26:0]hero_origin,hero_accum;reg[16:0]hero_step;
 reg signed[10:0]giant_offset[0:1],old_text_offset;
 reg last_y_valid;reg[8:0]last_y;
 wire match0=prepared[0]&&bank_y[0]==i_y;
 wire match1=prepared[1]&&bank_y[1]==i_y;
 wire selected_bank=!match0&&match1;
 wire metadata_ready=!layer_resources_enabled||match0||match1;
 assign o_valid=i_valid&&metadata_ready&&!flush;
 assign i_ready=o_ready&&metadata_ready&&!flush;
 wire accepted=i_valid&&i_ready;
 wire direct_path=!layer_resources_enabled||i_dual;
 assign o_page=i_page;assign o_repeat=i_repeat;
 assign o_direct=direct_path&&!i_packed;assign o_packed=i_packed;assign o_half=i_half;assign o_black=i_black;assign o_packed_addr=i_mapped_addr;
 wire[20:0]bg_row=({12'd0,i_y}<<7)+({12'd0,i_y}<<6)+({12'd0,i_y}<<4)+({12'd0,i_y}<<2)+({12'd0,i_y}<<1);
 assign o_bg_addr=bg_base(i_page)+bg_row+i_x/3;
 assign o_bg_lane=i_x%3;
 reg[1:0]hit_count;wire[20:0]addr0,addr1;reg[20:0]selected_base0,selected_base1;reg signed[10:0]selected_x0,selected_x1;reg[7:0]alpha0,alpha1;reg excess;
 // Asset guard x lies within[-128,768] including CSS70/120px offsets and
 // hero inverse<=4245/4096. Signed11 integer bits and Q16 therefore retain
 // all sampled coordinate precision while removing oversized mux/adder bits.
 reg signed[10:0]source_x;
 reg signed[10:0]class_x[0:3];
 always@*begin
  class_x[0]=$signed({1'b0,i_x});
  class_x[1]=i_old?$signed({1'b0,i_x})+giant_offset[1]:(i_logical_x==0?hero_origin[26:16]:hero_accum[26:16]);
  class_x[2]=$signed({1'b0,i_x})+giant_offset[i_old];
  class_x[3]=i_old?$signed({1'b0,i_x})+old_text_offset:$signed({1'b0,i_x});
 end
 assign addr0=selected_base0+{{10{selected_x0[10]}},selected_x0};
 assign addr1=selected_base1+{{10{selected_x1[10]}},selected_x1};
 integer k,idx;
 always@*begin
  hit_count=0;selected_base0=0;selected_base1=0;selected_x0=0;selected_x1=0;alpha0=255;alpha1=255;excess=0;source_x=0;idx=0;
  for(k=0;k<4;k=k+1)begin
   idx=(selected_bank?8:0)+(i_old?4:0)+k;
   source_x=class_x[span_role[idx]];
   if(!direct_path&&k<(i_old?old_count[selected_bank]:new_count[selected_bank])&&source_x>=span_min[idx]&&source_x<span_max[idx])begin
    if(hit_count==0)begin selected_base0=span_base[idx];selected_x0=source_x;alpha0=span_alpha[idx];hit_count=1;end
    else if(hit_count==1)begin selected_base1=span_base[idx];selected_x1=source_x;alpha1=span_alpha[idx];hit_count=2;end
    else excess=1;
   end
  end
 end
 assign o_rgba_count=direct_path?2'd0:hit_count;assign o_rgba0_addr=addr0;assign o_rgba1_addr=addr1;assign o_opacity0=alpha0;assign o_opacity1=alpha1;
 reg[2:0]prep_state;reg prep_bank,prep_old;reg[3:0]component;
 reg[2:0]words_issued,word_tag;reg rom_valid;
 wire rom_request=prep_state==1&&words_issued<5;
 wire[2:0]prep_page=prep_old?previous_page:current_page;
 wire[9:0]rom_address={prep_page,component,words_issued};wire[31:0]rom_word;
 html_layer_descriptor_rom descriptors(clk,rom_address,rom_word);
 reg[31:0]d0,d1,d2,d3,d4;
 reg motion_query;reg[1:0]motion_kind;reg[2:0]motion_data;
 wire motion_valid;wire[4:0]motion_tag;wire signed[17:0]motion_x;wire signed[12:0]motion_y;
 wire[12:0]motion_scale,motion_inv;wire[7:0]motion_alpha;wire[6:0]frame_age;wire motion_active;
 html_scene_motion motion(clk,rst,flush,page_event,page_reverse,motion_query,{prep_old,component},motion_kind,prep_old,motion_data,
 motion_valid,motion_tag,motion_x,motion_y,motion_scale,motion_inv,motion_alpha,frame_age,motion_active);
 reg signed[17:0]tx;reg signed[12:0]ty;reg[12:0]inv;reg[7:0]opacity;
 wire setup_ready,span_valid;wire[4:0]span_tag;wire[1:0]span_kind;
 wire signed[31:0]span_origin;wire[16:0]span_step;wire signed[15:0]span_crop_x;wire[9:0]span_width;
 wire[20:0]span_row;wire[7:0]span_opacity;
 wire[1:0]kind=(d0[7:0]==2||d0[7:0]==3)?2'd1:d0[7:0]==1?2'd2:d0[7:0]==4?2'd3:2'd0;
 wire[20:0]texture_address=page_base(prep_page)+d3[20:0];
 html_layer_line_setup setup(clk,rst,flush,prep_state==2,setup_ready,{prep_old,component},texture_address,
 d1[15:0],d1[31:16],d2[9:0],d2[25:16],d4[15:0],d4[31:16],kind,tx,ty,inv,opacity,bank_y[prep_bank],canvas_start_x,
 span_valid,1'b1,span_tag,span_kind,span_origin,span_step,span_crop_x,span_width,span_row,span_opacity);
 reg[1:0]startup;integer i,write_index;
 always@(posedge clk)begin
  if(rst)begin prepared<=0;need_fill<=0;prep_state<=0;startup<=0;last_y_valid<=0;fault<=0;motion_query<=0;rom_valid<=0;words_issued<=0;new_count[0]<=0;new_count[1]<=0;old_count[0]<=0;old_count[1]<=0;end
  else if(flush)begin prepared<=0;need_fill<=0;prep_state<=0;startup<=2;last_y_valid<=0;motion_query<=0;rom_valid<=0;words_issued<=0;new_count[0]<=0;new_count[1]<=0;old_count[0]<=0;old_count[1]<=0;end
  else begin
   motion_query<=0;rom_valid<=rom_request;word_tag<=words_issued;
   if(rom_request)words_issued<=words_issued+1'b1;
   if(motion_valid)begin tx<=motion_x;ty<=motion_y;inv<=motion_inv;opacity<=motion_alpha;end
   if(startup!=0)begin
    startup<=startup-1'b1;
    if(startup==1&&layer_resources_enabled)begin bank_y[0]<=canvas_start_y;bank_y[1]<=canvas_start_y+1'b1;need_fill<=canvas_start_y==479?2'b01:2'b11;end
   end else if(layer_resources_enabled)begin
    case(prep_state)
     0:if(need_fill!=0)begin
      prep_bank<=need_fill[0]?0:1;need_fill[need_fill[0]?0:1]<=0;
      new_count[need_fill[0]?0:1]<=0;old_count[need_fill[0]?0:1]<=0;prep_old<=0;component<=0;words_issued<=0;prep_state<=1;
     end
     1:if(rom_valid)begin
      case(word_tag)
       0:begin d0<=rom_word;motion_kind<=(rom_word[7:0]==2||rom_word[7:0]==3)?2'd1:rom_word[7:0]==1?2'd2:rom_word[7:0]==4?2'd3:2'd0;motion_data<=rom_word[10:8];motion_query<=1;end
       1:d1<=rom_word;2:d2<=rom_word;3:d3<=rom_word;
       4:begin d4<=rom_word;prep_state<=2;end
      endcase
     end
     2:if(setup_ready)prep_state<=3;
     3:if(setup_ready)begin
      if(component==15)begin
       if(previous_active&&!prep_old)begin prep_old<=1;component<=0;words_issued<=0;prep_state<=1;end
       else begin prepared[prep_bank]<=1;prep_state<=0;end
      end else begin component<=component+1'b1;words_issued<=0;prep_state<=1;end
     end
     default:prep_state<=0;
    endcase
   end
   if(span_valid)begin
    if((span_tag[4]?old_count[prep_bank]:new_count[prep_bank])>=4)fault<=1;
    else begin
     write_index=(prep_bank?8:0)+(span_tag[4]?4:0)+(span_tag[4]?old_count[prep_bank]:new_count[prep_bank]);
     span_base[write_index]<=span_row-{{5{span_crop_x[15]}},span_crop_x};span_min[write_index]<=span_crop_x[10:0];span_max[write_index]<=span_crop_x+$signed({6'd0,span_width});
     span_role[write_index]<=span_kind;span_alpha[write_index]<=span_opacity;
     if(span_kind==1&&!span_tag[4])begin hero_origin<=span_origin[26:0];hero_step<=span_step;end
     if(span_kind==2||(span_kind==1&&span_tag[4]))giant_offset[span_tag[4]]<=($signed(span_origin)>>>16)-$signed({1'b0,canvas_start_x});
     if(span_kind==3&&span_tag[4])old_text_offset<=($signed(span_origin)>>>16)-$signed({1'b0,canvas_start_x});
     if(span_tag[4])old_count[prep_bank]<=old_count[prep_bank]+1'b1;else new_count[prep_bank]<=new_count[prep_bank]+1'b1;
    end
   end
   if(accepted&&layer_resources_enabled)begin
    hero_accum<=(i_logical_x==0?hero_origin:hero_accum)+$signed({10'd0,hero_step});
    if(!last_y_valid)begin last_y_valid<=1;last_y<=i_y;end
    else if(last_y!=i_y)begin
     last_y<=i_y;prepared[!selected_bank]<=0;
     if(i_y<479)begin bank_y[!selected_bank]<=i_y+1'b1;need_fill[!selected_bank]<=1;end
    end
    if(excess)fault<=1;
   end
  end
 end
endmodule
