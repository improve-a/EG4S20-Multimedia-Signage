from pathlib import Path
import hashlib,json,difflib,subprocess,time,datetime,sys
r=Path(r'D:\FPGA\EG4S20-Multimedia-Signage')
out=r/'output/html_fidelity/verification/locator_scene_stream_v1'
out.mkdir(parents=True,exist_ok=False)
sha=lambda b:hashlib.sha256(b).hexdigest()
changed={}
def save(rel,before,after):
    assert before!=after
    p=r/rel;(out/(p.name+'.before')).write_bytes(before.encode())
    (out/(p.name+'.diff')).write_bytes(''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile=rel+'.before',tofile=rel)).encode())
    p.write_bytes(after.encode());changed[rel]={'before_sha256':sha(before.encode()),'after_sha256':sha(p.read_bytes())}
p=r/'rtl/ext/html_resource_locator.v';old=p.read_text();s=old
s=s.replace('reg [31:0] magic,reserved;','reg [31:0] magic;\n reg constants_ok,constants_done;\n reg check_constant;reg [7:0] expected_constant;\n always @*begin\n  check_constant=1;expected_constant=0;\n  case(byte_index)\n   84:expected_constant=1;\n   86:expected_constant=32;\n   102:expected_constant=6;\n   85,87,103,108,109,110,111:expected_constant=0;\n   default:check_constant=0;\n  endcase\n end')
s=s.replace(' reg [15:0] version,locator_len,page_count;\n','')
s=s.replace('magic<=0;version<=0;locator_len<=0;scene_offset<=0;payload_bytes<=0;','magic<=0;constants_ok<=1;constants_done<=0;scene_offset<=0;payload_bytes<=0;')
s=s.replace('word_base<=0;page_index<=0;page_count<=0;set_id<=0;reserved<=0;','word_base<=0;page_index<=0;set_id<=0;')
s=s.replace('  end else if(byte_valid)begin\n   case(byte_index)','  end else if(byte_valid)begin\n   // Callers deliver one sequential 512-byte sector; constants are checked\n   // once on arrival and used only after the complete header transport.\n   if(check_constant && byte_data!=expected_constant)constants_ok<=0;\n   if(byte_index==111)constants_done<=1;\n   case(byte_index)')
for line in [
'    84:version[7:0]<=byte_data;85:version[15:8]<=byte_data;\n',
'    86:locator_len[7:0]<=byte_data;87:locator_len[15:8]<=byte_data;\n',
'    102:page_count[7:0]<=byte_data;103:page_count[15:8]<=byte_data;\n',
'    108:reserved[7:0]<=byte_data;109:reserved[15:8]<=byte_data;\n',
'    110:reserved[23:16]<=byte_data;111:reserved[31:24]<=byte_data;\n']:
    assert line in s;s=s.replace(line,'')
s=s.replace("format_ok<=magic==32'h4c584648 && version==1 && locator_len==32 &&\n    page_index<6 && page_count==6 && reserved==0 &&", "format_ok<=magic==32'h4c584648 && constants_ok && constants_done &&\n    page_index<6 &&")
save('rtl/ext/html_resource_locator.v',old,s)
p=r/'rtl/ext/html_scene_loader.v';old=p.read_text();s=old
s=s.replace('reg [31:0] file_len,pixel_offset,dib_size,width,height,compression;','reg [31:0] file_len,pixel_offset,dib_size,width,height;')
s=s.replace('reg [15:0] signature,planes,bit_count;','reg [15:0] signature;\n reg bmp_constants_ok;\n reg bmp_check_constant;reg [7:0] bmp_expected_constant;\n always @*begin\n  bmp_check_constant=1;bmp_expected_constant=0;\n  case(byte_index)\n   26:bmp_expected_constant=1;\n   28:bmp_expected_constant=24;\n   27,29,30,31,32,33:bmp_expected_constant=0;\n   default:bmp_check_constant=0;\n  endcase\n end')
s=s.replace("signature==16'h4d42 && planes==1 && bit_count==24 && compression==0 &&", "signature==16'h4d42 && bmp_constants_ok &&")
s=s.replace('signature<=0;planes<=0;bit_count<=0;compression<=0;','signature<=0;bmp_constants_ok<=0;')
s=s.replace('dib_size<=0;width<=0;height<=0;planes<=0;bit_count<=0;compression<=0;state<=HWAIT;','dib_size<=0;width<=0;height<=0;bmp_constants_ok<=1;state<=HWAIT;')
s=s.replace('     if(sector_valid)begin\n      if(byte_index<513)', '     if(sector_valid)begin\n      if(bmp_check_constant && sector_data!=bmp_expected_constant)bmp_constants_ok<=0;\n      if(byte_index<513)',1)
for line in [
'       26:planes[7:0]<=sector_data;27:planes[15:8]<=sector_data;28:bit_count[7:0]<=sector_data;29:bit_count[15:8]<=sector_data;\n',
'       30:compression[7:0]<=sector_data;31:compression[15:8]<=sector_data;32:compression[23:16]<=sector_data;33:compression[31:24]<=sector_data;\n']:
    assert line in s;s=s.replace(line,'')
assert all(x not in s for x in ['planes','bit_count','compression'])
save('rtl/ext/html_scene_loader.v',old,s)
p=r/'tests/html_scene_loader_tb.v';old=p.read_text();s=old
s=s.replace('integer k;','integer k;integer fixed_byte;')
needle='  case(c)1:h[84]=2;2:put32(104,0);3:put32(96,256);4:begin put32(92,8192);put32(2,930304);end endcase\n'
assert needle in s
s=s.replace(needle,needle+'''  // Every bit of every streamed fixed header byte must reject independently.
  if(c>=28)begin
   case((c-28)/8)
    0:fixed_byte=84;1:fixed_byte=85;2:fixed_byte=86;3:fixed_byte=87;
    4:fixed_byte=102;5:fixed_byte=103;6:fixed_byte=108;7:fixed_byte=109;
    8:fixed_byte=110;9:fixed_byte=111;
    default:fixed_byte=26+((c-28)/8)-10;
   endcase
   h[fixed_byte]=h[fixed_byte]^(1<<((c-28)%8));
  end
''')
s=s.replace('c<28','c<172').replace('26 malformed/transport/timeout cases','170 malformed/transport/timeout cases (including 144 fixed-field bit flips)')
save('tests/html_scene_loader_tb.v',old,s)
cmd=[r'C:\iverilog\bin\iverilog.exe','-g2012','-DHTML_SIM','-s','html_scene_loader_tb','-o',str(out/'scene.vvp'),'tests/html_scene_loader_tb.v','rtl/ext/html_scene_loader.v','rtl/ext/html_resource_locator.v']
t=time.monotonic()
with (out/'compile.log').open('wb') as log:
    p=subprocess.Popen(cmd,cwd=r,stdout=log,stderr=subprocess.STDOUT);cpid=p.pid;ce=p.wait(timeout=60)
record={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source':changed,'compile_command':cmd,'compile_pid':cpid,'compile_exit':ce}
if ce==0:
    with (out/'simulation.log').open('wb') as log:
        p=subprocess.Popen([r'C:\iverilog\bin\vvp.exe',str(out/'scene.vvp')],cwd=r,stdout=log,stderr=subprocess.STDOUT);record['simulation_pid']=p.pid;record['simulation_exit']=p.wait(timeout=120)
    record['log']=(out/'simulation.log').read_text();record['status']='PASS' if record['simulation_exit']==0 and 'TEST_PASS' in record['log'] else 'FAIL'
else:record['status']='COMPILE_FAIL'
record['wall_seconds']=time.monotonic()-t
(out/'verification.json').write_bytes(json.dumps(record,indent=2).encode())
print(json.dumps(record,indent=2))
