// Exact source CSS curves sampled at16.8ms, and source JS cleanup at1.55s.
// Query latency is two registered stages, with one query accepted each clock.
// Frame age advances only on actual read-commit ACK; page_event may precede it.
// x/y offsets areQ8 pixels, scale/inverse areQ12, alpha is straight0..255.
module html_scene_motion #(
 parameter OFFSET_FILE="D:/FPGA/EG4S20-NoBot-RCA-20261020/builds/rca_locked_only_001/work/design/user_source/hdl_source/ext/html_assets/html_motion_offset.hex",
 parameter ALPHA_SCALE_FILE="D:/FPGA/EG4S20-NoBot-RCA-20261020/builds/rca_locked_only_001/work/design/user_source/hdl_source/ext/html_assets/html_motion_alpha_scale.hex"
)(
 input wire clk,rst,frame_start,page_event,page_reverse,
 input wire i_valid,
 input wire [4:0] query_tag,
 input wire [1:0] layer_kind,
 input wire old_layer,
 input wire [2:0] data_index,
 output reg o_valid,
 output reg [4:0] query_tag_out,
 output reg signed [17:0] x_offset_q8,
 output reg signed [12:0] y_offset_q8,
 output reg [12:0] scale_q12,inv_scale_q12,
 output reg [7:0] alpha,
 output reg [6:0] frame_age,
 output wire active
);
 reg event_pending,reverse_l;
 assign active=frame_age<7'd93;
 always @(posedge clk)begin
  if(rst)begin frame_age<=127;event_pending<=0;reverse_l<=0;end
  else begin
   if(page_event)event_pending<=1;
   if(frame_start)begin
    if(page_event||event_pending)begin frame_age<=0;event_pending<=0;reverse_l<=page_reverse;end
    else if(frame_age<127)frame_age<=frame_age+1'b1;
   end
  end
 end
 reg [3:0] bank;
 always @*begin
  if(old_layer)bank=layer_kind==3 ? 4'd3 : 4'd2;
  else case(layer_kind)
   1:bank=0;2:bank=1;3:bank=4'd4+data_index;default:bank=0;
  endcase
 end
 wire [10:0] address={bank,frame_age};
 wire [15:0] offset_word,alpha_scale_word;
 html_rom16 #(.WORDS(1536),.ADDR_BITS(11),.INIT_FILE(OFFSET_FILE)) offset_rom(
  .clk(clk),.address(address),.data(offset_word));
 html_rom16 #(.WORDS(1536),.ADDR_BITS(11),.INIT_FILE(ALPHA_SCALE_FILE)) alpha_rom(
  .clk(clk),.address(address),.data(alpha_scale_word));
 reg valid0,old0,reverse0;
 reg [1:0] kind0;
 reg [4:0] tag0;
 reg [6:0] age0;
 // BEGIN GENERATED INVERSE
 function [12:0] inverse_scale;input[7:0] deficit;begin case(deficit)
   8'd0:inverse_scale=13'd4096;
   8'd1:inverse_scale=13'd4097;
   8'd2:inverse_scale=13'd4098;
   8'd3:inverse_scale=13'd4099;
   8'd4:inverse_scale=13'd4100;
   8'd5:inverse_scale=13'd4101;
   8'd6:inverse_scale=13'd4102;
   8'd7:inverse_scale=13'd4103;
   8'd8:inverse_scale=13'd4104;
   8'd9:inverse_scale=13'd4105;
   8'd10:inverse_scale=13'd4106;
   8'd11:inverse_scale=13'd4107;
   8'd12:inverse_scale=13'd4108;
   8'd13:inverse_scale=13'd4109;
   8'd14:inverse_scale=13'd4110;
   8'd15:inverse_scale=13'd4111;
   8'd16:inverse_scale=13'd4112;
   8'd17:inverse_scale=13'd4113;
   8'd18:inverse_scale=13'd4114;
   8'd19:inverse_scale=13'd4115;
   8'd20:inverse_scale=13'd4116;
   8'd21:inverse_scale=13'd4117;
   8'd22:inverse_scale=13'd4118;
   8'd23:inverse_scale=13'd4119;
   8'd24:inverse_scale=13'd4120;
   8'd25:inverse_scale=13'd4121;
   8'd26:inverse_scale=13'd4122;
   8'd27:inverse_scale=13'd4123;
   8'd28:inverse_scale=13'd4124;
   8'd29:inverse_scale=13'd4125;
   8'd30:inverse_scale=13'd4126;
   8'd31:inverse_scale=13'd4127;
   8'd32:inverse_scale=13'd4128;
   8'd33:inverse_scale=13'd4129;
   8'd34:inverse_scale=13'd4130;
   8'd35:inverse_scale=13'd4131;
   8'd36:inverse_scale=13'd4132;
   8'd37:inverse_scale=13'd4133;
   8'd38:inverse_scale=13'd4134;
   8'd39:inverse_scale=13'd4135;
   8'd40:inverse_scale=13'd4136;
   8'd41:inverse_scale=13'd4137;
   8'd42:inverse_scale=13'd4138;
   8'd43:inverse_scale=13'd4139;
   8'd44:inverse_scale=13'd4140;
   8'd45:inverse_scale=13'd4141;
   8'd46:inverse_scale=13'd4143;
   8'd47:inverse_scale=13'd4144;
   8'd48:inverse_scale=13'd4145;
   8'd49:inverse_scale=13'd4146;
   8'd50:inverse_scale=13'd4147;
   8'd51:inverse_scale=13'd4148;
   8'd52:inverse_scale=13'd4149;
   8'd53:inverse_scale=13'd4150;
   8'd54:inverse_scale=13'd4151;
   8'd55:inverse_scale=13'd4152;
   8'd56:inverse_scale=13'd4153;
   8'd57:inverse_scale=13'd4154;
   8'd58:inverse_scale=13'd4155;
   8'd59:inverse_scale=13'd4156;
   8'd60:inverse_scale=13'd4157;
   8'd61:inverse_scale=13'd4158;
   8'd62:inverse_scale=13'd4159;
   8'd63:inverse_scale=13'd4160;
   8'd64:inverse_scale=13'd4161;
   8'd65:inverse_scale=13'd4162;
   8'd66:inverse_scale=13'd4163;
   8'd67:inverse_scale=13'd4164;
   8'd68:inverse_scale=13'd4165;
   8'd69:inverse_scale=13'd4166;
   8'd70:inverse_scale=13'd4167;
   8'd71:inverse_scale=13'd4168;
   8'd72:inverse_scale=13'd4169;
   8'd73:inverse_scale=13'd4170;
   8'd74:inverse_scale=13'd4171;
   8'd75:inverse_scale=13'd4172;
   8'd76:inverse_scale=13'd4173;
   8'd77:inverse_scale=13'd4174;
   8'd78:inverse_scale=13'd4176;
   8'd79:inverse_scale=13'd4177;
   8'd80:inverse_scale=13'd4178;
   8'd81:inverse_scale=13'd4179;
   8'd82:inverse_scale=13'd4180;
   8'd83:inverse_scale=13'd4181;
   8'd84:inverse_scale=13'd4182;
   8'd85:inverse_scale=13'd4183;
   8'd86:inverse_scale=13'd4184;
   8'd87:inverse_scale=13'd4185;
   8'd88:inverse_scale=13'd4186;
   8'd89:inverse_scale=13'd4187;
   8'd90:inverse_scale=13'd4188;
   8'd91:inverse_scale=13'd4189;
   8'd92:inverse_scale=13'd4190;
   8'd93:inverse_scale=13'd4191;
   8'd94:inverse_scale=13'd4192;
   8'd95:inverse_scale=13'd4193;
   8'd96:inverse_scale=13'd4194;
   8'd97:inverse_scale=13'd4195;
   8'd98:inverse_scale=13'd4196;
   8'd99:inverse_scale=13'd4197;
   8'd100:inverse_scale=13'd4199;
   8'd101:inverse_scale=13'd4200;
   8'd102:inverse_scale=13'd4201;
   8'd103:inverse_scale=13'd4202;
   8'd104:inverse_scale=13'd4203;
   8'd105:inverse_scale=13'd4204;
   8'd106:inverse_scale=13'd4205;
   8'd107:inverse_scale=13'd4206;
   8'd108:inverse_scale=13'd4207;
   8'd109:inverse_scale=13'd4208;
   8'd110:inverse_scale=13'd4209;
   8'd111:inverse_scale=13'd4210;
   8'd112:inverse_scale=13'd4211;
   8'd113:inverse_scale=13'd4212;
   8'd114:inverse_scale=13'd4213;
   8'd115:inverse_scale=13'd4214;
   8'd116:inverse_scale=13'd4215;
   8'd117:inverse_scale=13'd4216;
   8'd118:inverse_scale=13'd4218;
   8'd119:inverse_scale=13'd4219;
   8'd120:inverse_scale=13'd4220;
   8'd121:inverse_scale=13'd4221;
   8'd122:inverse_scale=13'd4222;
   8'd123:inverse_scale=13'd4223;
   8'd124:inverse_scale=13'd4224;
   8'd125:inverse_scale=13'd4225;
   8'd126:inverse_scale=13'd4226;
   8'd127:inverse_scale=13'd4227;
   8'd128:inverse_scale=13'd4228;
   8'd129:inverse_scale=13'd4229;
   8'd130:inverse_scale=13'd4230;
   8'd131:inverse_scale=13'd4231;
   8'd132:inverse_scale=13'd4232;
   8'd133:inverse_scale=13'd4233;
   8'd134:inverse_scale=13'd4235;
   8'd135:inverse_scale=13'd4236;
   8'd136:inverse_scale=13'd4237;
   8'd137:inverse_scale=13'd4238;
   8'd138:inverse_scale=13'd4239;
   8'd139:inverse_scale=13'd4240;
   8'd140:inverse_scale=13'd4241;
   8'd141:inverse_scale=13'd4242;
   8'd142:inverse_scale=13'd4243;
   8'd143:inverse_scale=13'd4244;
   default:inverse_scale=13'd4096;
  endcase end endfunction
 // END GENERATED INVERSE
 wire signed [17:0] offset_value={{2{offset_word[15]}},offset_word};
 always @(posedge clk)begin
  if(rst)begin
   valid0<=0;old0<=0;reverse0<=0;kind0<=0;tag0<=0;age0<=127;
   o_valid<=0;query_tag_out<=0;x_offset_q8<=0;y_offset_q8<=0;
   scale_q12<=4096;inv_scale_q12<=4096;alpha<=255;
  end else begin
   valid0<=i_valid&&!frame_start;old0<=old_layer;reverse0<=reverse_l;
   kind0<=layer_kind;tag0<=query_tag;age0<=frame_age;
   o_valid<=valid0;query_tag_out<=tag0;
   x_offset_q8<=0;y_offset_q8<=0;scale_q12<=4096;inv_scale_q12<=4096;alpha<=255;
   if(age0>=93)begin
    if(old0)alpha<=0;
   end else if(kind0!=0)begin
    alpha<=alpha_scale_word[15:8];
    if(kind0==3&&!old0)y_offset_q8<=offset_word[12:0];
    else x_offset_q8<=(!old0&&kind0==1&&reverse0) ? -offset_value : offset_value;
    if(kind0==1&&!old0)begin
     scale_q12<=13'd4096-{5'd0,alpha_scale_word[7:0]};
     inv_scale_q12<=inverse_scale(alpha_scale_word[7:0]);
    end
   end
  end
 end
endmodule
