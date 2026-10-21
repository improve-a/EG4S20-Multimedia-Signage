import sys
sys.path.insert(0,'harness')
from windows_runner import remote_python
print(remote_python(r"""
from pathlib import Path
import json,zipfile,hashlib
r=Path(r'D:\FPGA\EG4S20-Multimedia-Signage')
p=r/'rtl/SD/bmp_read.v';original=p.read_bytes()
zp=r/'output/html_fidelity/integration_baseline.zip'
with zipfile.ZipFile(zp,'a',zipfile.ZIP_DEFLATED) as z:
 if 'rtl/SD/bmp_read.v' not in z.namelist():z.writestr('rtl/SD/bmp_read.v',original)
s=original.decode('utf-8').replace('\r\n','\n')
a='parameter ENABLE_SCALE=0)';b='parameter ENABLE_SCALE=0, parameter ENABLE_HFXL=0)'
assert s.count(a)==1;s=s.replace(a,b)
a='bmp_scale_read #(.TIMEOUT_CYCLES(TIMEOUT_CYCLES))';b='bmp_scale_read #(.TIMEOUT_CYCLES(TIMEOUT_CYCLES),.ENABLE_HFXL(ENABLE_HFXL))'
assert s.count(a)==1;s=s.replace(a,b);p.write_text(s,encoding='utf-8')
p=r/'rtl/ext/bmp_scale.v';s=p.read_text(encoding='utf-8')
a='module bmp_scale_read #(parameter TIMEOUT_CYCLES=200_000_000)';b='module bmp_scale_read #(parameter TIMEOUT_CYCLES=200_000_000, parameter ENABLE_HFXL=0)'
assert s.count(a)==1;s=s.replace(a,b)
a=' wire [31:0] pixel_end=pixel_end_wide[31:0];'
b=a+'''
 wire hfxl_extent_ok;
 generate if(ENABLE_HFXL)begin: layer_locator
  html_resource_locator locator(.clk(clk),.rst(rst),.header_start(state==HREQ),
   .byte_valid(state==HRECV && sd_sec_read_data_valid),.byte_index(receive_count),
   .byte_data(sd_sec_read_data),.file_len(file_len),.pixel_offset(pixel_offset),
   .pixel_end(pixel_end),.dib_size(dib_size),.width(width),.height(height),
   .valid(hfxl_extent_ok),.scene_offset(),.payload_bytes(),.word_base(),.set_id(),.page_index());
 end else begin: ordinary_bmp
  assign hfxl_extent_ok=1'b0;
 end endgenerate'''
assert s.count(a)==1;s=s.replace(a,b)
a='extent_upper_ok<=file_len<=max_file_len;';b='extent_upper_ok<=(file_len<=max_file_len)||hfxl_extent_ok;'
assert s.count(a)==1;s=s.replace(a,b);p.write_text(s,encoding='utf-8')
print('HFXL opt-in parser installed; default ordinary BMP bounds unchanged')
""",timeout=60))
