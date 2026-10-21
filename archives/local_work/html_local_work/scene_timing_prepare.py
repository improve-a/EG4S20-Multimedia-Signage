from pathlib import Path
import os,re,subprocess,hashlib,json,time,difflib,datetime
r=Path(r'D:\FPGA\EG4S20-Multimedia-Signage');os.chdir(r)
d=r/'output/html_fidelity/verification/header_timing_v1';d.mkdir(parents=True,exist_ok=True)
s=(r/'rtl/ext/html_scene_loader.v').read_text();old=s
assert hashlib.sha256((r/'rtl/ext/html_scene_loader.v').read_bytes()).hexdigest()=='fc68493af9f175664f1b08e66ae2d3c371cfa9cdc5e14b45d6bc44d876ffd290'
def rep(a,b):
 global s
 assert s.count(a)==1,(a,s.count(a))
 s=s.replace(a,b)
rep('reg [31:0] origin,payload_sector,timeout_count;','reg [31:0] origin,payload_sector,timeout_count;\n reg timeout_expired;')
rep('reg [31:0] expected_body_word;','reg [31:0] expected_body_word;\n reg body_checked_q;reg [31:0] expected_body_word_q;\n reg header_ok_q,resource_range_ok;')
start=s.index('      if(bmp_check_constant && sector_data!=bmp_expected_constant)bmp_constants_ok<=0;')
end=s.index('      endcase',start)+len('      endcase')
fields=s[start:end].replace("      if(byte_index<513)byte_index<=byte_index+1'b1;\n",'')
rep(s[start:end],"      if(byte_index<513)byte_index<=byte_index+1'b1;")
rep('   file_len<=0;pixel_offset<=0;signature<=0;bmp_constants_ok<=0;\n   body_ok<=0;','')
rep('byte_index<=0;signature<=0;file_len<=0;pixel_offset<=0;\n     bmp_constants_ok<=1;state<=HWAIT;', 'byte_index<=0;state<=HWAIT;')
rep('payload_sector<=0;timeout_count<=0;assembled<=0;', 'payload_sector<=0;timeout_count<=0;timeout_expired<=(TIMEOUT_CYCLES==0);assembled<=0;')
rep("   if(sector_valid||sector_end||write_req_ack||finish_pulse||!active)timeout_count<=0;\n   else if(timeout_count<TIMEOUT_CYCLES)timeout_count<=timeout_count+1'b1;", """   if(sector_valid||sector_end||write_req_ack||finish_pulse||!active)begin
    timeout_count<=0;timeout_expired<=(TIMEOUT_CYCLES==0);
   end else if(timeout_count<TIMEOUT_CYCLES)begin
    timeout_count<=timeout_count+1'b1;timeout_expired<=(timeout_count==TIMEOUT_CYCLES-1);
   end else timeout_expired<=1;""")
rep('if(finish_pulse&&state>=WREQ&&state<=FINISH)', 'if(finish_pulse&&(state==WREQ||state==DREQ||state==DWAIT||state==FINISH))')
rep('sector_error||timeout_count==TIMEOUT_CYCLES','sector_error||timeout_expired')
rep('if(header_ok && byte_index+sector_valid==512 && !resource_last_sector[32])','if(header_ok_q && byte_index+sector_valid==512 && resource_range_ok)')
rep('       body_ok<=1;state<=WREQ;','       state<=WREQ;')
rep('        if(sector_index==0&&body_checked&&assembled_word!=expected_body_word)body_ok<=0;','')
new_block=""" // Header fields settle long before the 512-byte decision. Keep their
 // enables local; transport abort/timeout only controls the transaction FSM.
 always @(posedge clk)begin
  if(rst)begin
   file_len<=0;pixel_offset<=0;signature<=0;bmp_constants_ok<=0;
  end else if(state==HREQ)begin
   file_len<=0;pixel_offset<=0;signature<=0;bmp_constants_ok<=1;
  end else if(state==HWAIT&&sector_valid)begin
FIELDS
  end
 end
 // Four byte clocks separate successive body words. Register the expected
 // word before its fourth byte, cutting the selector out of the comparison.
 always @(posedge clk)begin
  if(rst)begin
   header_ok_q<=0;resource_range_ok<=0;body_checked_q<=0;expected_body_word_q<=0;body_ok<=0;
  end else begin
   header_ok_q<=header_ok;resource_range_ok<=!resource_last_sector[32];
   body_checked_q<=body_checked;expected_body_word_q<=expected_body_word;
   if(state==HREQ)body_ok<=1;
   else if(state==DWAIT&&sector_valid&&byte_index[1:0]==3&&sector_index==0&&
           body_checked_q&&assembled_word!=expected_body_word_q)body_ok<=0;
  end
 end
""".replace('FIELDS',fields)
idx=s.index(' always @(posedge clk)begin\n  if(rst)begin\n   state<=IDLE;')
s=s[:idx]+new_block+s[idx:]
(d/'html_scene_loader_candidate.v').write_bytes(s.encode())
(d/'html_scene_loader_original.v').write_bytes(old.replace('module html_scene_loader #','module html_scene_loader_original #').encode())
(d/'html_scene_loader_candidate.diff').write_text(''.join(difflib.unified_diff(old.splitlines(True),s.splitlines(True),fromfile='production',tofile='candidate')))
t=(r/'tests/html_scene_loader_tb.v').read_text()
a=t.index(' html_scene_loader #');b=t.index(' task put32;',a)
instance=t[a:b]
outs=['active','ready','error','page_ready','mode_valid','layer_mode','req','address','wreq','we','wdata','base','len']
extra=' wire active_old,ready_old,error_old,req_old,wreq_old,we_old,mode_valid_old,layer_mode_old;wire [5:0] page_ready_old;\n wire [31:0] address_old,wdata_old;wire [20:0] base_old,len_old;\n'
oi=instance.replace('html_scene_loader #','html_scene_loader_original #').replace(')) dut(', ')) original(')
for x in outs:oi=re.sub(r'\('+x+r'\)', '('+x+'_old)',oi)
cmp=' always @(posedge clk)begin #1;if(!rst && {'+','.join(outs)+'} !== {'+','.join(x+'_old' for x in outs)+'})$fatal(1,"scene cycle interface mismatch c=%0d cycle=%0d",c,cycles);end\n'
t=t[:b]+extra+oi+cmp+t[b:]
(d/'scene_cycle_equivalence_tb.v').write_bytes(t.encode())
cmd=[r'C:\iverilog\bin\iverilog.exe','-g2012','-s','html_scene_loader_tb','-o',str(d/'scene_equivalence.vvp'),str(d/'scene_cycle_equivalence_tb.v'),str(d/'html_scene_loader_candidate.v'),str(d/'html_scene_loader_original.v'),str(r/'rtl/ext/html_resource_locator.v')]
t0=time.monotonic();c=subprocess.run(cmd,capture_output=True);(d/'compile.log').write_bytes(c.stdout+c.stderr)
print('compile',c.returncode,c.stderr.decode(errors='replace'));assert c.returncode==0
v=subprocess.run([r'C:\iverilog\bin\vvp.exe',str(d/'scene_equivalence.vvp')],capture_output=True,timeout=90);(d/'run.log').write_bytes(v.stdout+v.stderr)
print('run',v.returncode,v.stdout.decode(errors='replace'),v.stderr.decode(errors='replace'))
report={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'scope':'all externally visible outputs every clock, 6 pages, 266 malformed/transport/timeout cases, ordinary fallback','command':cmd,'run_exit':v.returncode,'elapsed':time.monotonic()-t0,'sha256':{str(p.relative_to(d)):hashlib.sha256(p.read_bytes()).hexdigest() for p in d.iterdir() if p.is_file()}}
(d/'scene_equivalence.json').write_text(json.dumps(report,indent=2));print(json.dumps(report));assert v.returncode==0
