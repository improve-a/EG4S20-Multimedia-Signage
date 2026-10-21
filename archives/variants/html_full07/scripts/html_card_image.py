#!/usr/bin/env python3
"""Build an ordinary FAT32 image for offline validation; never opens a device.

The image has deterministic contiguous files and is test evidence, not a claim
about allocation or physical sector addresses on tomorrow's actual TF card.
"""
import argparse,hashlib,json,struct
from pathlib import Path
SECTOR=512
TOTAL=131072
RESERVED=32
FAT_SECTORS=1024
DATA_LBA=RESERVED+2*FAT_SECTORS
CLUSTERS=TOTAL-DATA_LBA

def u16(data,offset,value):struct.pack_into('<H',data,offset,value)
def u32(data,offset,value):struct.pack_into('<I',data,offset,value)
def sha(data):return hashlib.sha256(data).hexdigest()

def create(pack,output):
    pack=Path(pack);output=Path(output)
    if output.suffix.lower()!='.img' or str(output).startswith('\\\\.\\'):
        raise ValueError('output must be a new ordinary .img file')
    files=sorted(pack.glob('*.BMP'))+sorted(pack.glob('*.WAV'))
    if len(files)!=7 or sum(p.suffix=='.BMP' for p in files)!=6:
        raise ValueError('requires six BMPs and one WAV in a unified directory')
    records=[];next_cluster=3
    for source in files:
        name=source.name.upper();stem,suffix=name.split('.')
        if len(stem)>8 or len(suffix)>3 or not name.isascii():raise ValueError('requires simple 8.3 names')
        data=source.read_bytes();n=(len(data)+511)//512
        if not n:raise ValueError('empty media')
        records.append(dict(name=name,bytes=len(data),sha256=sha(data),cluster=next_cluster,
                            sectors=n,start_lba=DATA_LBA+next_cluster-2,source=str(source.resolve())))
        next_cluster+=n
    if next_cluster>CLUSTERS+2:raise ValueError('media exceeds image')
    boot=bytearray(512);boot[:3]=b'\xeb\x58\x90';boot[3:11]=b'ANLOGIC '
    u16(boot,11,512);boot[13]=1;u16(boot,14,RESERVED);boot[16]=2;boot[21]=0xf8
    u16(boot,24,63);u16(boot,26,255);u32(boot,32,TOTAL);u32(boot,36,FAT_SECTORS)
    u32(boot,44,2);u16(boot,48,1);u16(boot,50,6);boot[64]=0x80;boot[66]=0x29
    u32(boot,67,0x20261015);boot[71:82]=b'ANLOGIC2026';boot[82:90]=b'FAT32   ';boot[510:]=b'\x55\xaa'
    info=bytearray(512);u32(info,0,0x41615252);u32(info,484,0x61417272)
    u32(info,488,CLUSTERS-(next_cluster-2));u32(info,492,next_cluster);u32(info,508,0xaa550000)
    fat=bytearray(FAT_SECTORS*512);u32(fat,0,0x0ffffff8);u32(fat,4,0xffffffff);u32(fat,8,0x0fffffff)
    root=bytearray(512);root[:11]=b'ANLOGIC2026';root[11]=8
    for slot,rec in enumerate(records,1):
        start=rec['cluster'];n=rec['sectors']
        for cluster in range(start,start+n):u32(fat,cluster*4,cluster+1 if cluster+1<start+n else 0x0fffffff)
        entry=bytearray(32);stem,suffix=rec['name'].split('.');entry[:11]=(stem.ljust(8)+suffix.ljust(3)).encode('ascii')
        entry[11]=0x20;u16(entry,16,((2026-1980)<<9)|(10<<5)|15);u16(entry,18,((2026-1980)<<9)|(10<<5)|15)
        u16(entry,20,start>>16);u16(entry,24,((2026-1980)<<9)|(10<<5)|15);u16(entry,26,start&65535);u32(entry,28,rec['bytes'])
        root[slot*32:(slot+1)*32]=entry
    output.parent.mkdir(parents=True,exist_ok=True)
    with output.open('xb') as image:
        image.truncate(TOTAL*512)
        for sector,data in [(0,boot),(1,info),(6,boot),(7,info),(RESERVED,fat),(RESERVED+FAT_SECTORS,fat),(DATA_LBA,root)]:
            image.seek(sector*512);image.write(data)
        for rec in records:
            image.seek(rec['start_lba']*512);image.write(Path(rec['source']).read_bytes())
    report=dict(scope='offline ordinary image only; actual card LBAs remain unknown',path=str(output.resolve()),
                bytes=output.stat().st_size,sha256=sha(output.read_bytes()),filesystem='FAT32',sector_bytes=512,
                sectors_per_cluster=1,files=records,hardware='NOT_TESTED_THIS_RUN',device_access=False)
    report_path=output.with_suffix('.json');report_path.write_text(json.dumps(report,indent=2),encoding='utf-8')
    return report

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--pack',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    print(json.dumps(create(args.pack,args.output),indent=2))
if __name__=='__main__':main()
