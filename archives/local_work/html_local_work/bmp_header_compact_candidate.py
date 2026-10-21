from pathlib import Path
import hashlib,json,subprocess,time,datetime,difflib,random,struct,os
r=Path(r'D:\FPGA\EG4S20-Multimedia-Signage');o=r/'output/html_fidelity/verification/bmp_header_compact_v1';o.mkdir(parents=True,exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
p=r/'rtl/ext/bmp_scale.v';old=p.read_text();s=old
s=s.replace('reg [31:0] start_sector, file_len,pixel_offset,dib_size,width,height,compression;\n reg [15:0] planes,bit_count;', '''reg [31:0] start_sector,file_len;
 reg [20:0] pixel_offset;
 reg [6:0] dib_size;
 reg [9:0] width;
 reg [8:0] height;
 // Legal BMP bounds fit these fields. Every discarded header bit and fixed
 // format byte is checked on arrival, before the full512byte header decision.
 reg header_fields_ok;''')
s=s.replace('.pixel_offset(pixel_offset)',".pixel_offset({11'd0,pixel_offset})").replace('.dib_size(dib_size),.width(width),.height(height)',".dib_size({25'd0,dib_size}),.width({22'd0,width}),.height({23'd0,height})")
s=s.replace('reg signature_ok,width_ok,height_ok,planes_ok,bits_ok,compression_ok,dib_ok;', 'reg signature_ok,width_ok,height_ok,dib_ok;')
s=s.replace('height_ok<=0;planes_ok<=0;\n   bits_ok<=0;compression_ok<=0;dib_ok<=0;', 'height_ok<=0;dib_ok<=0;')
s=s.replace('   planes_ok<=planes==16\'d1;bits_ok<=bit_count==16\'d24;\n   compression_ok<=compression==0;\n','')
s=s.replace('format_ok<=planes_ok&&bits_ok&&compression_ok&&dib_ok;', 'format_ok<=header_fields_ok&&dib_ok;')
s=s.replace('.source_height(height[9:0])',".source_height({1'b0,height})")
s=s.replace('height<=0;compression<=0;\n   planes<=0;bit_count<=0;', 'height<=0;header_fields_ok<=0;\n   ')
s=s.replace('width<=0;height<=0;planes<=0;bit_count<=0;compression<=0;', 'width<=0;height<=0;header_fields_ok<=1;')
a=s.index('       12:pixel_offset[23:16]');b=s.index('\n      endcase',a)
s=s[:a]+'''       12:begin pixel_offset[20:16]<=sd_sec_read_data[4:0];if(sd_sec_read_data[7:5]!=0)header_fields_ok<=0;end
       14:begin dib_size<=sd_sec_read_data[6:0];if(sd_sec_read_data[7])header_fields_ok<=0;end
       18:width[7:0]<=sd_sec_read_data;
       19:begin width[9:8]<=sd_sec_read_data[1:0];if(sd_sec_read_data[7:2]!=0)header_fields_ok<=0;end
       22:height[7:0]<=sd_sec_read_data;
       23:begin height[8]<=sd_sec_read_data[0];if(sd_sec_read_data[7:1]!=0)header_fields_ok<=0;end
       26:if(sd_sec_read_data!=1)header_fields_ok<=0;
       28:if(sd_sec_read_data!=24)header_fields_ok<=0;
       13,15,16,17,20,21,24,25,27,29,30,31,32,33:if(sd_sec_read_data!=0)header_fields_ok<=0;'''+s[b:]
assert all(x not in s for x in ['planes_ok','bits_ok','compression_ok','planes<=','compression<=','height[9:0]'])
(o/'bmp_scale.v').write_bytes(s.encode());(o/'bmp_scale.v.before').write_bytes(p.read_bytes());(o/'bmp_scale.v.diff').write_bytes(''.join(difflib.unified_diff(old.splitlines(True),s.splitlines(True),fromfile='bmp_scale.v.before',tofile='bmp_scale.v')).encode())
ref=old.replace('bmp_scale_read','bmp_scale_read_original').replace('bmp_sector_buffer','bmp_sector_buffer_original').replace('module bmp_scale #(', 'module bmp_scale_original #(').replace(' bmp_scale scaler(', ' bmp_scale_original scaler(')
assert 'module bmp_scale_original #(' in ref
(o/'bmp_original.v').write_bytes(ref.encode());(o/'html_resource_locator.v').write_bytes((r/'rtl/ext/html_resource_locator.v').read_bytes())
headers=[]
for i in range(1,7):headers.append(bytearray((r/f'output/html_fidelity/media/UI{i:02d}.BMP').read_bytes()[:512]))
formal=list(headers)
for h in formal:
 for pos in list(range(0,6))+list(range(10,34))+list(range(80,112)):
  for bit in range(8):q=bytearray(h);q[pos]^=1<<bit;headers.append(q)
rng=random.Random(0x424d)
for i in range(512):
 h=bytearray(512);h[:2]=b'BM';w=rng.randrange(1,641);ht=rng.randrange(1,481);dib=[40,108,124][i%3];off=rng.randrange(dib+14,1048577);end=off+((w*3+3)&~3)*ht
 for pos,val in [(2,end+rng.randrange(0,65537)),(10,off),(14,dib),(18,w),(22,ht)]:struct.pack_into('<I',h,pos,val)
 struct.pack_into('<HH',h,26,1,24);headers.append(h)
# Explicit admissible boundaries plus sign/highbit and extent rejection boundaries.
for w in [0,1,640,641,1023,1024,0xffffffff]:
 for ht in [0,1,480,481,511,512,0xffffffff]:
  h=bytearray(headers[-1]);struct.pack_into('<I',h,18,w);struct.pack_into('<I',h,22,ht);headers.append(h)
(o/'headers.hex').write_bytes(''.join(f'{b:02x}\n' for h in headers for b in h).encode())
tb='''`timescale 1ns/1ps
module bmp_header_equivalence_tb;
reg clk=0;always #5 clk=~clk;
reg rst=1,start=0,dv=0,done=0;reg[7:0]data=0;
wire ra,rb,sda,sdb,fva,fvb,sra,srb;wire[3:0]ta,tb,ea,eb;wire[31:0]fa,fb,aa,ab;
bmp_scale_read_original #(.ENABLE_HFXL(1)) a(.clk(clk),.rst(rst),.ready(ra),.scan_start(start),.scan_start_sector(32'd0),.scan_max_sector(32'd0),.scan_target_count(4'd1),.scan_done(sda),.scan_found_valid(fva),.scan_found_sector(fa),.scan_found_total(ta),.load_start(1'b0),.load_abort(1'b0),.load_sector(32'd0),.scale_mode(2'd0),.sd_init_done(1'b1),.write_req_ack(1'b0),.sd_sec_read(sra),.sd_sec_read_addr(aa),.sd_sec_read_data(data),.sd_sec_read_data_valid(dv),.sd_sec_read_end(done),.sd_sec_read_error(1'b0),.error_code(ea));
bmp_scale_read #(.ENABLE_HFXL(1)) b(.clk(clk),.rst(rst),.ready(rb),.scan_start(start),.scan_start_sector(32'd0),.scan_max_sector(32'd0),.scan_target_count(4'd1),.scan_done(sdb),.scan_found_valid(fvb),.scan_found_sector(fb),.scan_found_total(tb),.load_start(1'b0),.load_abort(1'b0),.load_sector(32'd0),.scale_mode(2'd0),.sd_init_done(1'b1),.write_req_ack(1'b0),.sd_sec_read(srb),.sd_sec_read_addr(ab),.sd_sec_read_data(data),.sd_sec_read_data_valid(dv),.sd_sec_read_end(done),.sd_sec_read_error(1'b0),.error_code(eb));
reg[7:0]h[0:TOTAL*512-1];integer k,j,accepts=0,rejects=0;
always@(negedge clk)if(!rst && {ra,sda,fva,fa,ta,sra,aa,ea}!={rb,sdb,fvb,fb,tb,srb,ab,eb})$fatal(1,"BMP header interface mismatch case%0d idx%0d state%0d/%0d found%0d/%0d",k,j,a.state,b.state,fva,fvb);
initial begin
 $readmemh("headers.hex",h);repeat(3)@(negedge clk);rst=0;
 for(k=0;k<TOTAL;k=k+1)begin
  @(negedge clk);start=1;@(negedge clk);start=0;wait(sra);@(negedge clk);
  for(j=0;j<512;j=j+1)begin dv=1;data=h[k*512+j];@(negedge clk);end
  dv=0;done=1;@(negedge clk);done=0;wait(sda);@(negedge clk);
  if(ta==1)accepts=accepts+1;else rejects=rejects+1;
 end
 $display("TEST_PASS BMP header sequential interface equivalence cases%0d accepted%0d rejected%0d scan only; pixel parser/scaler unchanged",TOTAL,accepts,rejects);$finish;
end
endmodule
'''.replace('TOTAL',str(len(headers)))
(o/'bmp_header_equivalence_tb.v').write_bytes(tb.encode())
report={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'state':'RUNNING','scope':'All cycle-visible scan header interfaces old/new; fixed positive dimensions and BI_RGB contract preserved. Actual unchanged scaler instantiated, payload parsing never entered in this header test.','old_sha256':sha(p),'new_sha256':sha(o/'bmp_scale.v'),'locator_sha256':sha(o/'html_resource_locator.v'),'headers':len(headers),'steps':[]}
for step,cmd in [('compile',[r'C:\iverilog\bin\iverilog.exe','-g2012','-DHTML_SIM','-s','bmp_header_equivalence_tb','-o','test.vvp','bmp_header_equivalence_tb.v','bmp_original.v','bmp_scale.v','html_resource_locator.v']),('simulation',[r'C:\iverilog\bin\vvp.exe','test.vvp'])]:
 log=o/(step+'.log');t=time.monotonic()
 with log.open('wb') as f:p2=subprocess.Popen(cmd,cwd=o,stdout=f,stderr=subprocess.STDOUT);pid=p2.pid;code=p2.wait(timeout=300)
 report['steps'].append({'step':step,'command':cmd,'pid':pid,'exit':code,'wall_seconds':time.monotonic()-t,'log_sha256':sha(log),'tail':log.read_text()[-2500:]});(o/'verification.json').write_bytes(json.dumps(report,indent=2).encode())
 if code:report['state']='FAIL';break
else:report['state']='UNIT_SIM_PASS'
(o/'verification.json').write_bytes(json.dumps(report,indent=2).encode());print(json.dumps(report,indent=2))
