from pathlib import Path
import json,hashlib,difflib,datetime,subprocess,base64,sys
r=Path(r'D:\FPGA\EG4S20-Multimedia-Signage');out=r/'output/html_fidelity/verification/bmp_counter_width_v1';out.mkdir(parents=True,exist_ok=False)
p=r/'rtl/ext/bmp_scale.v';before=p.read_bytes();s=before.decode();(out/'before.v').write_bytes(before)
assert s.count('reg [31:0] file_position,row_position;')==1
s=s.replace('reg [31:0] file_position,row_position;','''// Accepted BMPs have width<=640, height<=480 and pixel_offset<=1048576.
 // Thus stride<=1920 and pixel_end<=1970176; these counters cannot wrap
 // before DRAIN. Keep header extent arithmetic wide for malformed inputs.
 reg [20:0] file_position;
 reg [10:0] row_position;''')
assert s.count('if(row_position==row_stride-1)')==1
s=s.replace('if(row_position==row_stride-1)','if(row_position==row_stride_narrow[10:0]-11\'d1)')
assert s.count('wire [31:0] row_stride={20\'d0,row_stride_narrow};')==1
s=s.replace(" wire [31:0] row_stride={20'd0,row_stride_narrow};\n",'')
p.write_bytes(s.encode());(out/'change.diff').write_bytes(''.join(difflib.unified_diff(before.decode().splitlines(True),s.splitlines(True),fromfile='before',tofile='current')).encode())
count=0
for width in range(1,641):
    stride=(width*3+3)&~3
    assert stride<=1920
    for rowpos in range(stride):
        wide_next=0 if rowpos==stride-1 else rowpos+1
        narrow_next=0 if rowpos==((stride-1)&2047) else (rowpos+1)&2047
        assert wide_next==narrow_next;count+=1
    assert 1048576+stride*480<=1970176<2**21
record={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'before_sha256':hashlib.sha256(before).hexdigest(),'after_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bound_proof':{'accepted_width_range':[1,640],'accepted_height_range':[1,480],'pixel_offset_upper':1048576,'max_stride':1920,'max_pixel_end':1970176,'exhaustive_row_counter_transitions':count,'status':'PASS'},'scope':'Header validation and extent arithmetic remain wide. Data counters only. Full03 packing excess and full02 row-stride setup path are real motivations.'}
(out/'audit.json').write_bytes(json.dumps(record,indent=2).encode())
cmd=subprocess.list2cmdline([sys.executable,str(r/'scripts/html_fidelity_regression.py'),'--only','scale_tb_case3','--only','scale_case4','--only','scale_case5','--only','real_hfxl_hfxc_native_bmp','--only','real_hfxl_rejected_without_optin'])
ps="$r=Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine='"+cmd.replace("'","''")+"';CurrentDirectory='"+str(r)+"'}; $r | Select-Object ReturnValue,ProcessId | ConvertTo-Json"
q=subprocess.run(['powershell','-NoProfile','-NonInteractive','-EncodedCommand',base64.b64encode(ps.encode('utf-16le')).decode()],capture_output=True,text=True)
(out/'regression_dispatch.json').write_bytes(json.dumps({'command':cmd,'exit':q.returncode,'stdout':q.stdout},indent=2).encode())
print(json.dumps(record,indent=2));print(q.stdout,q.stderr)
