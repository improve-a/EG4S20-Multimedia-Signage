// Runtime SDRAM address mapping. Three registered stages, no image store and
// no combinational division. pixel_step may contain arbitrary bubbles. The
// accepted request is presented after the third register stage (edge N+2).
// frame_latch must precede the first pixel_step and atomically captures config.
module exhibit_viewport #(
 parameter ENABLE_TRANSITION=0,EXPLICIT_DIRECTION=0,
 parameter COMPARE_HEIGHT=384,COMPARE_WORDS=62464
)(
 input clk,rst,frame_latch,pixel_step,
 input [2:0] page_index,input dual_enable,input [1:0] zoom,input [2:0] focus,
 input [1:0] transition_mode,input panels_ready,input page_reverse,
 output reg [20:0] mapped_addr,output reg mapped_valid,
 output reg mapped_packed,mapped_half,mapped_black
);
 reg [2:0] page_l;
 reg dual_l,panels_l,old_dual,have_frame,aperture_active,reverse_l;
 reg [2:0] old_page;
 reg [6:0] aperture_age;
 reg [9:0] aperture_width;
 // The preserved25MHz/800x525 video frame is16.8ms. This table samples
 // CSS cubic-bezier(.76,0,.24,1) at the actual frame times through1050ms.
 function [9:0] aperture;
 input [6:0] age;
 begin case(age)
 7'd0:aperture=10'd0;
 7'd1:aperture=10'd0;
 7'd2:aperture=10'd0;
 7'd3:aperture=10'd1;
 7'd4:aperture=10'd2;
 7'd5:aperture=10'd3;
 7'd6:aperture=10'd4;
 7'd7:aperture=10'd5;
 7'd8:aperture=10'd7;
 7'd9:aperture=10'd9;
 7'd10:aperture=10'd12;
 7'd11:aperture=10'd15;
 7'd12:aperture=10'd18;
 7'd13:aperture=10'd22;
 7'd14:aperture=10'd26;
 7'd15:aperture=10'd31;
 7'd16:aperture=10'd36;
 7'd17:aperture=10'd42;
 7'd18:aperture=10'd49;
 7'd19:aperture=10'd56;
 7'd20:aperture=10'd65;
 7'd21:aperture=10'd75;
 7'd22:aperture=10'd86;
 7'd23:aperture=10'd98;
 7'd24:aperture=10'd113;
 7'd25:aperture=10'd129;
 7'd26:aperture=10'd149;
 7'd27:aperture=10'd172;
 7'd28:aperture=10'd199;
 7'd29:aperture=10'd231;
 7'd30:aperture=10'd268;
 7'd31:aperture=10'd309;
 7'd32:aperture=10'd352;
 7'd33:aperture=10'd391;
 7'd34:aperture=10'd426;
 7'd35:aperture=10'd455;
 7'd36:aperture=10'd480;
 7'd37:aperture=10'd501;
 7'd38:aperture=10'd519;
 7'd39:aperture=10'd535;
 7'd40:aperture=10'd548;
 7'd41:aperture=10'd560;
 7'd42:aperture=10'd570;
 7'd43:aperture=10'd580;
 7'd44:aperture=10'd588;
 7'd45:aperture=10'd595;
 7'd46:aperture=10'd601;
 7'd47:aperture=10'd607;
 7'd48:aperture=10'd612;
 7'd49:aperture=10'd616;
 7'd50:aperture=10'd620;
 7'd51:aperture=10'd624;
 7'd52:aperture=10'd627;
 7'd53:aperture=10'd630;
 7'd54:aperture=10'd632;
 7'd55:aperture=10'd634;
 7'd56:aperture=10'd635;
 7'd57:aperture=10'd637;
 7'd58:aperture=10'd638;
 7'd59:aperture=10'd639;
 7'd60:aperture=10'd639;
 7'd61:aperture=10'd640;
 7'd62:aperture=10'd640;
 7'd63:aperture=10'd640;
 default:aperture=640;
 endcase end endfunction
 reg [1:0] divisor;
 reg [9:0] x,canvas_x,origin_x;
 reg [8:0] y,canvas_y,origin_y;
 reg [1:0] remainder_x,remainder_y,origin_remainder_x,origin_remainder_y;
 wire select_old=aperture_active && (reverse_l ? canvas_x>=aperture_width : canvas_x<640-aperture_width);
 wire [2:0] selected_page=select_old?old_page:page_l;
 wire selected_dual=select_old?old_dual:dual_l;
 function [23:0] origin;
 input home;input[2:0] f;input[1:0] z;
 begin case({home,(f>5?3'd0:f),(z>2?2'd2:z)})
  6'd0:origin=24'h000000;
  6'd1:origin=24'h480350;
  6'd2:origin=24'h5545d4;
  6'd4:origin=24'h000000;
  6'd5:origin=24'h280780;
  6'd6:origin=24'h354a04;
  6'd8:origin=24'h000000;
  6'd9:origin=24'h000780;
  6'd10:origin=24'h0d4a04;
  6'd12:origin=24'h000000;
  6'd13:origin=24'h500780;
  6'd14:origin=24'h5d4a04;
  6'd16:origin=24'h000000;
  6'd17:origin=24'h280000;
  6'd18:origin=24'h354284;
  6'd20:origin=24'h000000;
  6'd21:origin=24'h280f00;
  6'd22:origin=24'h355184;
  6'd32:origin=24'h000000;
  6'd33:origin=24'h44c480;
  6'd34:origin=24'h520704;
  6'd36:origin=24'h000000;
  6'd37:origin=24'h280780;
  6'd38:origin=24'h354a04;
  6'd40:origin=24'h000000;
  6'd41:origin=24'h000780;
  6'd42:origin=24'h0d4a04;
  6'd44:origin=24'h000000;
  6'd45:origin=24'h500780;
  6'd46:origin=24'h5d4a04;
  6'd48:origin=24'h000000;
  6'd49:origin=24'h280000;
  6'd50:origin=24'h354284;
  6'd52:origin=24'h000000;
  6'd53:origin=24'h280f00;
  6'd54:origin=24'h355184;
 default:origin=0;
 endcase end endfunction
 wire [23:0] new_origin=origin(page_index==0,focus,zoom);
 function [20:0] page_base;
 input [2:0] p;
 begin case(p)
  0:page_base=21'd0;1:page_base=21'd307200;2:page_base=21'd614400;
  3:page_base=21'd921600;4:page_base=21'd1228800;5:page_base=21'd1536000;
  default:page_base=0;
 endcase end endfunction
 function [2:0] dual_page;
 input [2:0] p;input right;
 begin case(p)
  1:dual_page=right?3'd2:3'd1;
  2:dual_page=right?3'd1:3'd2;
  3:dual_page=right?3'd4:3'd3;
  4:dual_page=right?3'd3:3'd4;
  default:dual_page=right?3'd2:3'd1;
 endcase end endfunction
 function [20:0] panel_base;
 input [2:0] p;
 begin case(p)
  2:panel_base=1843200+COMPARE_WORDS;
  3:panel_base=1843200+2*COMPARE_WORDS;
  4:panel_base=1843200+3*COMPARE_WORDS;
  default:panel_base=1843200;
 endcase end endfunction
 reg v1,v2,packed1,packed2,half1,half2,black1,black2;
 reg [9:0] sx1,sx2;
 reg [8:0] sy1;
 reg [2:0] page1;
 reg [20:0] row2,base2;
 always @(posedge clk)begin
  if(rst)begin
   page_l<=0;dual_l<=0;panels_l<=0;old_dual<=0;old_page<=0;have_frame<=0;
   aperture_active<=0;reverse_l<=0;aperture_age<=0;aperture_width<=640;
   packed1<=0;packed2<=0;half1<=0;half2<=0;black1<=0;black2<=0;
   mapped_packed<=0;mapped_half<=0;mapped_black<=0;divisor<=1;x<=0;y<=0;canvas_x<=0;canvas_y<=0;
   origin_x<=0;origin_y<=0;remainder_x<=0;remainder_y<=0;
   origin_remainder_x<=0;origin_remainder_y<=0;
   v1<=0;v2<=0;mapped_valid<=0;mapped_addr<=0;
   sx1<=0;sx2<=0;sy1<=0;page1<=0;row2<=0;base2<=0;
  end else begin
   v1<=pixel_step&&!frame_latch;v2<=v1;mapped_valid<=v2;
   if(frame_latch)begin
    page_l<=page_index<6?page_index:3'd0;dual_l<=dual_enable;panels_l<=panels_ready;
    have_frame<=1;
    if(ENABLE_TRANSITION && have_frame && page_index!=page_l && transition_mode!=0)begin
     old_page<=page_l;old_dual<=dual_l;aperture_active<=1;aperture_age<=0;aperture_width<=0;
     reverse_l<=EXPLICIT_DIRECTION ? page_reverse : page_index==(page_l==0?3'd5:page_l-1'b1);
    end else if(aperture_active)begin
     if(transition_mode==0 || aperture_age>=62)begin aperture_active<=0;aperture_width<=640;end
     else begin aperture_age<=aperture_age+1'b1;aperture_width<=aperture(aperture_age+1'b1);end
    end
    divisor<=zoom==0?2'd1:zoom==1?2'd2:2'd3;
    x<=0;y<=0;canvas_x<=new_origin[23:14];canvas_y<=new_origin[12:4];
    origin_x<=new_origin[23:14];origin_y<=new_origin[12:4];
    remainder_x<=new_origin[3:2];remainder_y<=new_origin[1:0];
    origin_remainder_x<=new_origin[3:2];origin_remainder_y<=new_origin[1:0];
   end else if(pixel_step)begin
    page1<=selected_dual?dual_page(selected_page,canvas_x>=320):selected_page;
    packed1<=selected_dual&&panels_l;
    half1<=selected_dual&&panels_l&&canvas_y>=COMPARE_HEIGHT?canvas_x[2]:canvas_x[0];black1<=0;
    sx1<=selected_dual ? (panels_l ? (canvas_x>=320?canvas_x-10'd320:canvas_x) :
                         ((canvas_x>=320?canvas_x-10'd320:canvas_x)<<1)) : canvas_x;
    sy1<=canvas_y;
    if(x==639)begin
     x<=0;canvas_x<=origin_x;remainder_x<=origin_remainder_x;
     if(y==479)begin y<=0;canvas_y<=origin_y;remainder_y<=origin_remainder_y;end
     else begin
      y<=y+1'b1;
      if(remainder_y+3'd1>=divisor)begin canvas_y<=canvas_y+1'b1;remainder_y<=0;end
      else remainder_y<=remainder_y+1'b1;
     end
    end else begin
     x<=x+1'b1;
     if(remainder_x+3'd1>=divisor)begin canvas_x<=canvas_x+1'b1;remainder_x<=0;end
     else remainder_x<=remainder_x+1'b1;
    end
   end
   if(v1)begin
    row2<=packed1 ? (sy1>=COMPARE_HEIGHT ? 21'd61440 + ((({12'd0,sy1}-COMPARE_HEIGHT)>>2)<<5)+((({12'd0,sy1}-COMPARE_HEIGHT)>>2)<<3) : (({12'd0,sy1}<<7)+({12'd0,sy1}<<5))) : (({12'd0,sy1}<<9)+({12'd0,sy1}<<7));
    base2<=packed1?panel_base(page1):page_base(page1);sx2<=packed1 ? (sy1>=COMPARE_HEIGHT ? {3'd0,sx1[9:3]} : {1'b0,sx1[9:1]}) : sx1;
    packed2<=packed1;half2<=half1;black2<=black1;
   end
   if(v2)begin mapped_addr<=base2+row2+sx2;mapped_packed<=packed2;mapped_half<=half2;mapped_black<=black2;end
  end
 end
endmodule
