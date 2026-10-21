from pathlib import Path
import hashlib,json,subprocess,time,datetime,difflib,random,struct,os
r=Path(r'D:\FPGA\EG4S20-Multimedia-Signage')
o=r/'output/html_fidelity/verification/locator_compact_v1';o.mkdir(parents=True,exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
old=r/'rtl/ext/html_resource_locator.v';(o/'locator_original.v').write_text(old.read_text().replace('module html_resource_locator(','module locator_original('))
new='''// HFXL v1 locator in sequential BMP header bytes 80..111.
// The validated 640x480/offset<=1MiB contract bounds scene_offset below 2MiB.
// Aligned fields retain their useful bits; every discarded bit is checked.
module html_resource_locator(
 input clk,rst,header_start,byte_valid,input [9:0] byte_index,input [7:0] byte_data,
 input [31:0] file_len,pixel_offset,pixel_end,dib_size,width,height,
 output reg valid,output present,
 output [31:0] scene_offset,payload_bytes,word_base,output reg [31:0] set_id,
 output [15:0] page_index
);
 reg [11:0] scene_sector,payload_blocks;
 reg [12:0] base_blocks;
 reg [2:0] page;
 reg magic_ok,magic_done,constants_ok,constants_done,field_bits_ok;
 reg check_constant;reg [7:0] expected_constant;
 always @*begin
  check_constant=1;expected_constant=0;
  case(byte_index)
   84:expected_constant=1;
   86:expected_constant=32;
   102:expected_constant=6;
   85,87,103,108,109,110,111:expected_constant=0;
   default:check_constant=0;
  endcase
 end
 assign present=magic_ok&&magic_done;
 assign scene_offset={11'd0,scene_sector,9'd0};
 assign payload_bytes={10'd0,payload_blocks,10'd0};
 assign word_base={11'd0,base_blocks,8'd0};
 assign page_index={13'd0,page};
 reg [32:0] aligned_pixel_end;
 reg [21:0] scene_end,memory_end;
 reg format_ok,layout_ok,extent_ok;
 always @(posedge clk)begin
  if(rst||header_start)begin
   magic_ok<=1;magic_done<=0;constants_ok<=1;constants_done<=0;field_bits_ok<=1;
   scene_sector<=0;payload_blocks<=0;base_blocks<=0;page<=0;set_id<=0;
  end else if(byte_valid)begin
   if(check_constant && byte_data!=expected_constant)constants_ok<=0;
   if(byte_index==111)constants_done<=1;
   case(byte_index)
    80:if(byte_data!=8'h48)magic_ok<=0;
    81:if(byte_data!=8'h46)magic_ok<=0;
    82:if(byte_data!=8'h58)magic_ok<=0;
    83:begin if(byte_data!=8'h4c)magic_ok<=0;magic_done<=1;end
    88,91,92,95,96,99,101:if(byte_data!=0)field_bits_ok<=0;
    89:begin scene_sector[6:0]<=byte_data[7:1];if(byte_data[0])field_bits_ok<=0;end
    90:begin scene_sector[11:7]<=byte_data[4:0];if(byte_data[7:5]!=0)field_bits_ok<=0;end
    93:begin payload_blocks[5:0]<=byte_data[7:2];if(byte_data[1:0]!=0)field_bits_ok<=0;end
    94:begin payload_blocks[11:6]<=byte_data[5:0];if(byte_data[7:6]!=0)field_bits_ok<=0;end
    97:base_blocks[7:0]<=byte_data;
    98:begin base_blocks[12:8]<=byte_data[4:0];if(byte_data[7:5]!=0)field_bits_ok<=0;end
    100:begin page<=byte_data[2:0];if(byte_data[7:3]!=0)field_bits_ok<=0;end
    104:set_id[7:0]<=byte_data;105:set_id[15:8]<=byte_data;
    106:set_id[23:16]<=byte_data;107:set_id[31:24]<=byte_data;
   endcase
  end
 end
 // Keep the original validation pipeline latency. The caller consumes valid
 // only after the complete sequential512byte header, well after byte111.
 always @(posedge clk)begin
  if(rst||header_start)begin
   aligned_pixel_end<=0;scene_end<=0;memory_end<=0;
   format_ok<=0;layout_ok<=0;extent_ok<=0;valid<=0;
  end else begin
   aligned_pixel_end<=({1'b0,pixel_end}+33'd511)&33'h1fffffe00;
   scene_end<={1'b0,scene_sector,9'd0}+{payload_blocks,10'd0};
   memory_end<={1'b0,base_blocks,8'd0}+{2'b00,payload_blocks,8'd0};
   format_ok<=present && constants_ok && constants_done && field_bits_ok &&
    page<6 && width==640 && height==480 && dib_size==40;
   layout_ok<=pixel_offset>=512 && pixel_offset<=1048576 &&
    payload_blocks>=4 && payload_blocks<=2048;
   extent_ok<=scene_offset==aligned_pixel_end &&
    file_len=={10'd0,scene_end} && memory_end<=1843200;
   valid<=format_ok&&layout_ok&&extent_ok;
  end
 end
endmodule
'''
(o/'html_resource_locator.v').write_bytes(new.encode())
oldscene=(r/'rtl/ext/html_scene_loader.v').read_text();s=oldscene
s=s.replace('reg [31:0] file_len,pixel_offset,dib_size,width,height;','reg [31:0] file_len,pixel_offset;')
s=s.replace('   26:bmp_expected_constant=1;', '   14:bmp_expected_constant=40;\n   18:bmp_expected_constant=128;\n   19:bmp_expected_constant=2;\n   22:bmp_expected_constant=224;\n   23:bmp_expected_constant=1;\n   26:bmp_expected_constant=1;')
s=s.replace('   27,29,30,31,32,33:bmp_expected_constant=0;','   15,16,17,20,21,24,25,27,29,30,31,32,33:bmp_expected_constant=0;')
s=s.replace('.dib_size(dib_size),.width(width),.height(height)',".dib_size(32'd40),.width(32'd640),.height(32'd480)")
s=s.replace('dib_size<=0;width<=0;height<=0;','')
s='\n'.join(line for line in s.split('\n') if not any(f'{n}[' in line for n in ['dib_size','width','height']))
(o/'html_scene_loader.v').write_bytes(s.encode())
t=(r/'tests/html_scene_loader_tb.v').read_text()
t=t.replace('if(c>=28)begin','if(c>=28 && c<172)begin').replace('c<172;c=c+1','c<268;c=c+1')
needle='  if(c>=28 && c<172)begin';i=t.index(needle);j=t.index('\n  end',i)+len('\n  end')
t=t[:j]+"\n  if(c>=172)h[14+(c-172)/8]=h[14+(c-172)/8]^(1<<((c-172)%8));"+t[j:]
t=t.replace('170 malformed/transport/timeout cases (including 144 fixed-field bit flips)','266 malformed/transport/timeout cases (including 240 fixed-field bit flips)')
assert 'c<268' in t
(o/'html_scene_loader_tb.v').write_bytes(t.encode())
for name,before in [('html_resource_locator.v',old.read_text()),('html_scene_loader.v',oldscene),('html_scene_loader_tb.v',(r/'tests/html_scene_loader_tb.v').read_text())]:
 (o/(name+'.before')).write_bytes(before.encode())
 (o/(name+'.diff')).write_bytes(''.join(difflib.unified_diff(before.splitlines(True),(o/name).read_text().splitlines(True),fromfile=name+'.before',tofile=name)).encode())
headers=[]
for i in range(1,7):headers.append(bytearray((r/f'output/html_fidelity/media/UI{i:02d}.BMP').read_bytes()[:512]))
formal=list(headers)
for h in formal:
 for pos in range(80,112):
  for bit in range(8):q=bytearray(h);q[pos]^=1<<bit;headers.append(q)
# Legal caller metadata: file bounds and pixel_end are computed from the BMP.
rng=random.Random(0x4c58464c)
for i in range(512):
 h=bytearray(formal[i%6]);off=rng.randrange(512,1048577);end=off+921600;scene=(end+511)&~511
 base=rng.randrange(0,6000)*256;maxblocks=min(2048,(1843200-base)//256);blocks=rng.randrange(4,maxblocks+1)
 for pos,val in [(2,scene+blocks*1024),(10,off),(88,scene),(92,blocks*1024),(96,base),(104,rng.getrandbits(32))]:struct.pack_into('<I',h,pos,val)
 headers.append(h)
# All bits of BMP fixed fields and externally calculated extents, not just locators.
for h in formal:
 for pos in list(range(2,6))+list(range(10,26)):
  for bit in range(8):q=bytearray(h);q[pos]^=1<<bit;headers.append(q)
(o/'headers.hex').write_bytes(''.join(f'{b:02x}\n' for h in headers for b in h).encode())
tb='''`timescale 1ns/1ps
module locator_equivalence_tb;
reg clk=0;always #5 clk=~clk;
reg rst=1,header_start=0,byte_valid=0;reg[9:0]byte_index=0;reg[7:0]byte_data=0;
reg[31:0] file_len,pixel_offset,pixel_end,dib_size,width,height;
wire va,vb,pa,pb;wire[31:0]sa,sb,la,lb,ba,bb,ia,ib;wire[15:0] xa,xb;
locator_original a(.clk(clk),.rst(rst),.header_start(header_start),.byte_valid(byte_valid),.byte_index(byte_index),.byte_data(byte_data),.file_len(file_len),.pixel_offset(pixel_offset),.pixel_end(pixel_end),.dib_size(dib_size),.width(width),.height(height),.valid(va),.present(pa),.scene_offset(sa),.payload_bytes(la),.word_base(ba),.set_id(ia),.page_index(xa));
html_resource_locator b(.clk(clk),.rst(rst),.header_start(header_start),.byte_valid(byte_valid),.byte_index(byte_index),.byte_data(byte_data),.file_len(file_len),.pixel_offset(pixel_offset),.pixel_end(pixel_end),.dib_size(dib_size),.width(width),.height(height),.valid(vb),.present(pb),.scene_offset(sb),.payload_bytes(lb),.word_base(bb),.set_id(ib),.page_index(xb));
reg[7:0]h[0:TOTAL*512-1];integer k,j,accepted=0,rejected=0;
function[31:0] word;input integer n;begin word={h[n+3],h[n+2],h[n+1],h[n]};end endfunction
initial begin
 $readmemh("headers.hex",h);repeat(3)@(negedge clk);rst=0;
 for(k=0;k<TOTAL;k=k+1)begin
  @(negedge clk);header_start=1;byte_valid=0;file_len=word(k*512+2);pixel_offset=word(k*512+10);pixel_end=word(k*512+10)+32'd921600;dib_size=word(k*512+14);width=word(k*512+18);height=word(k*512+22);
  @(negedge clk);header_start=0;
  for(j=0;j<512;j=j+1)begin byte_valid=1;byte_index=j;byte_data=h[k*512+j];@(negedge clk);end
  byte_valid=0;repeat(5)@(negedge clk);
  if(va!==vb||pa!==pb)$fatal(1,"valid/present mismatch case%0d old%0d/%0d new%0d/%0d",k,va,pa,vb,pb);
  if(va)begin accepted=accepted+1;if({sa,la,ba,ia,xa}!={sb,lb,bb,ib,xb})$fatal(1,"valid payload mismatch case%0d",k);end else rejected=rejected+1;
 end
 $display("TEST_PASS header_contract_equivalence cases%0d accepted%0d rejected%0d complete512byte caller metadata",TOTAL,accepted,rejected);$finish;
end
endmodule
'''.replace('TOTAL',str(len(headers)))
(o/'locator_equivalence_tb.v').write_bytes(tb.encode())
report={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'production_untouched':True,'scope':'Complete sequential BMP headers with caller-derived pixel_end. All retained valid outputs and locator present identical; malformed output payload bits are not meaningful. Discarded fields are explicitly rejected.','bounds':{'pixel_offset_max':1048576,'pixel_bytes':921600,'aligned_scene_max':1970176,'scene_bits':21,'payload_max':2097152,'payload_bits':22,'memory_words_limit':1843200,'word_base_bits':21},'sources':{n:sha(o/n) for n in ['html_resource_locator.v','html_scene_loader.v','html_scene_loader_tb.v','locator_equivalence_tb.v','locator_original.v']},'steps':[]}
for top,names in [('locator_equivalence_tb',['locator_equivalence_tb.v','locator_original.v','html_resource_locator.v']),('html_scene_loader_tb',['html_scene_loader_tb.v','html_scene_loader.v','html_resource_locator.v'])]:
 for step,cmd in [('compile',[r'C:\iverilog\bin\iverilog.exe','-g2012','-DHTML_SIM','-s',top,'-o',top+'.vvp']+names),('simulation',[r'C:\iverilog\bin\vvp.exe',top+'.vvp'])]:
  log=o/(top+'_'+step+'.log');start=time.monotonic()
  with log.open('wb') as f:p=subprocess.Popen(cmd,cwd=o,stdout=f,stderr=subprocess.STDOUT);pid=p.pid;code=p.wait(timeout=180)
  report['steps'].append({'name':top,'step':step,'command':cmd,'pid':pid,'exit':code,'wall_seconds':time.monotonic()-start,'log_sha256':sha(log),'tail':log.read_text()[-2000:]})
  (o/'verification.json').write_bytes(json.dumps(report,indent=2).encode())
  if code:print(json.dumps(report,indent=2));raise SystemExit(0)
report['state']='UNIT_SIM_PASS';(o/'verification.json').write_bytes(json.dumps(report,indent=2).encode());print(json.dumps(report,indent=2))
