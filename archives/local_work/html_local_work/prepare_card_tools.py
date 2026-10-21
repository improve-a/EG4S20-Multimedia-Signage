import sys
sys.path.insert(0,'harness')
from windows_runner import remote_python
print(remote_python(r"""
from pathlib import Path
r=Path(r'D:\FPGA\EG4S20-Multimedia-Signage')
p=r/'output/venue_emergency_ui/scripts/inspect_card.py';s=p.read_text(encoding='utf-8')
s=s.replace('for a selected media pack','for the unified six-page media pack')
a="    if (0<width<=640 and 0<height<=480 and u16(header,26)==1 and u16(header,28)==24 and u32(header,30)==0"
b='''    extended=False
    if len(header)>=112 and header[80:84]==b'HFXL':
        scene,payload,base=u32(header,88),u32(header,92),u32(header,96)
        page,count=u16(header,100),u16(header,102)
        extended=(u16(header,84)==1 and u16(header,86)==32 and page<6 and count==6 and
            u32(header,108)==0 and width==640 and height==480 and dib==40 and offset>=512 and
            scene==((end+511)//512)*512 and payload>=4096 and payload<=2097152 and payload%1024==0 and
            base%256==0 and base+payload//4<=1843200 and size==scene+payload)
    if (0<width<=640 and 0<height<=480 and u16(header,26)==1 and u16(header,28)==24 and u32(header,30)==0'''
assert s.count(a)==1;s=s.replace(a,b).replace('end<=size<=end+65536):','end<=size and (size<=end+65536 or extended)):')
s=s.replace('if not 1<=len(bmp_hits)<=4 or','if len(bmp_hits)!=6 or').replace('more than four physical BMP headers','not exactly six physical BMP headers')
s=s.replace("p.add_argument('--pack',required=True,choices=('A_daily','B_emergency','C_features'))","p.add_argument('--pack',required=True,type=Path,help='directory containing the unified six BMP files and one WAV')")
s=s.replace("inspect(args.source,ROOT/'tf_card_package'/args.pack)","inspect(args.source,args.pack)")
s=s.replace('selected pack contains no media','selected pack contains no media')
s=s.replace("    check(expected,'selected pack contains no media')","    check(len(expected)==7,'requires exactly six distinct BMP files and one WAV')")
(r/'scripts/html_inspect_card.py').write_bytes(s.encode('utf-8'));print('read-only inspector adapted from existing tool; no device opened')
""",timeout=60))
