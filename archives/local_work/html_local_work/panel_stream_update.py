import pathlib,hashlib,json,difflib,subprocess,base64,datetime
r=pathlib.Path(r'D:\FPGA\EG4S20-Multimedia-Signage');out=r/'output/html_fidelity/verification/panel_stream_v1';out.mkdir(parents=True,exist_ok=False)
f=r/'rtl/ext/html_panel_loader.v';before=f.read_bytes();s=before.decode();(out/'before.v').write_bytes(before)
s=s.replace(' reg [31:0] magic,resource_bytes,resource_offset;\n reg [15:0] signature,version,texture_width,texture_height,low_width,low_height;',' reg header_ok;\n reg checked_header_byte;reg [7:0] expected_header_byte;\n localparam [31:0] RESOURCE_BYTES=PANEL_SECTORS*512;')
start=s.index(' wire header_ok=');end=s.index(' always @(posedge clk)',start)
expected={0:"8'h42",1:"8'h4d",54:"8'h48",55:"8'h46",56:"8'h58",57:"8'h43",58:"8'h01",59:"8'h00",60:"8'h40",61:"8'h01",62:"8'h80",63:"8'h01",64:"8'h50",65:"8'h00",66:"8'h18",67:"8'h00",68:'RESOURCE_BYTES[7:0]',69:'RESOURCE_BYTES[15:8]',70:'RESOURCE_BYTES[23:16]',71:'RESOURCE_BYTES[31:24]',72:"8'h00",73:"8'h02",74:"8'h00",75:"8'h00"}
block=''' // All accepted header fields are fixed constants. Compare each arriving
 // byte once; the sticky result replaces 192 stored field bits. Last checked
 // byte75 precedes the complete 512-byte sector decision by436 clocks.
 always @*begin
  checked_header_byte=1;expected_header_byte=0;
  case(byte_index)
'''
block+=''.join(f'   10\'d{k}:expected_header_byte={v};\n' for k,v in expected.items())
block+='   default:checked_header_byte=0;\n  endcase\n end\n';s=s[:start]+block+s[end:]
s=s.replace('   magic<=0;resource_bytes<=0;resource_offset<=0;signature<=0;version<=0;\n   texture_width<=0;texture_height<=0;low_width<=0;low_height<=0;','   header_ok<=0;')
s=s.replace('byte_index<=0;signature<=0;magic<=0;state<=HWAIT;','byte_index<=0;header_ok<=1;state<=HWAIT;')
start=s.index('      case(byte_index)');end=s.index('      endcase',start)+len('      endcase')
s=s[:start]+'      if(checked_header_byte&&sector_data!=expected_header_byte)header_ok<=0;'+s[end:]
assert 'signature' not in s and 'magic' not in s and 'resource_offset' not in s
f.write_bytes(s.encode());(out/'change.diff').write_text(''.join(difflib.unified_diff(before.decode().splitlines(True),s.splitlines(True),fromfile='before',tofile='current')))
t=r/'tests/html_panel_loader_tb.v';tb=t.read_bytes();u=tb.decode();(out/'before_tb.v').write_bytes(tb)
needle="if(bad&&b==54)sd_data=8'h00;";assert u.count(needle)==1
u=u.replace(needle,"if(bad==1&&b==54)sd_data=8'h00;else if(bad>=2&&b==bad-2)sd_data=media[idx]^8'h01;")
needle=' mode=2;reset_dut;';assert u.count(needle)==1
addition=''' // Flip every byte of each required header field independently. No write
 // handshake is allowed after any mismatch, including zero-valued bytes.
 for(j=0;j<24;j=j+1)begin
  mode=9+j;reset_dut;wait(sd_req);
  send_sector(0,0,512,(j<2?j:54+j-2)+2,j%2);wait_failure;
  if(acks||words)$fatal(1,"mutated header wrote memory byte%0d",j<2?j:54+j-2);
 end
 $display("HEADER_BYTES_REJECT_PASS checked24");
'''
u=u.replace(needle,addition+needle);t.write_bytes(u.encode())
(out/'test_change.diff').write_text(''.join(difflib.unified_diff(tb.decode().splitlines(True),u.splitlines(True),fromfile='before',tofile='current')))
(out/'audit.json').write_text(json.dumps({'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'before':hashlib.sha256(before).hexdigest(),'after':hashlib.sha256(f.read_bytes()).hexdigest(),'test_after':hashlib.sha256(t.read_bytes()).hexdigest(),'reason':'full03 real packing failure; stream exact fixed header bytes with unchanged payload, transport, timeout and handshake behavior'},indent=2))
cmd=subprocess.list2cmdline([r'D:\python3.12.3\python.exe',str(r/'scripts/html_fidelity_verify_io.py')])
ps="$r=Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine='"+cmd.replace("'","''")+"';CurrentDirectory='"+str(r)+"'}; $r | Select-Object ReturnValue,ProcessId | ConvertTo-Json"
p=subprocess.run(['powershell','-NoProfile','-NonInteractive','-EncodedCommand',base64.b64encode(ps.encode('utf-16le')).decode()],capture_output=True,text=True);print('IO_LAUNCH',p.returncode,p.stdout,p.stderr)
