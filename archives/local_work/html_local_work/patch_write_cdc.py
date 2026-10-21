import sys
sys.path.insert(0,'harness')
from windows_runner import remote_python
print(remote_python(r"""
from pathlib import Path
r=Path(r'D:\FPGA\EG4S20-Multimedia-Signage');p=r/'rtl/SD/frame_fifo_write.v';s=p.read_text(encoding='utf-8')
a='reg [1:0] linear_sync;'
b='''// Bundled write metadata stays stable until completion in the source domain.
// Two capture stages precede the existing three-stage request/ACK handshake;
// perform vertical-flip arithmetic only on the captured memory-domain base.
(* async_reg="true" *) reg [ADDR_BITS-1:0] base_sync0,base_sync1;
wire [ADDR_BITS-1:0] selected_base = write_addr_index==0 ? write_addr_0 :
 write_addr_index==1 ? write_addr_1 : write_addr_index==2 ? write_addr_2 : write_addr_3;
always @(posedge mem_clk or posedge rst)
 if(rst)begin base_sync0<=0;base_sync1<=0;end
 else begin base_sync0<=selected_base;base_sync1<=base_sync0;end
(* async_reg="true" *) reg [1:0] linear_sync;'''
assert s.count(a)==1;s=s.replace(a,b)
a=s.index("\t\t\t\tif(write_addr_index_d1 == 2'd0)")
b=s.index('\n\t\t\tend',a)
s=s[:a]+'''                App_wr_addr_r <= (WRITE_V_FLIP && !linear_sync[1]) ?
                    (base_sync1 + VFLIP_FIRST_ADDR_OFFSET) : base_sync1;'''+s[b:]
p.write_text(s,encoding='utf-8');print('writer metadata captured before address arithmetic')
""",timeout=60))
