#!/usr/bin/env python3
"""READ ONLY FAT32/physical-LBA audit for the unified six-page media pack; never writes card bytes.

Accepts a whole-disk image or an explicitly selected Windows PhysicalDrive path.
No disk discovery, elevation, formatting, copying, allocation repair or raw write.
"""
from __future__ import annotations
import argparse, hashlib, json, struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SECTOR=512
SCAN_SECTORS=131072
MAX_FILE=256*1024*1024

def u16(data,off): return struct.unpack_from('<H',data,off)[0]
def u32(data,off): return struct.unpack_from('<I',data,off)[0]
def sha(data): return hashlib.sha256(data).hexdigest()
def check(condition,message):
    if not condition: raise ValueError(message)

def bmp_header(header):
    if len(header)<54 or header[:2]!=b'BM': return None
    size,offset,dib,width,height=u32(header,2),u32(header,10),u32(header,14),u32(header,18),u32(header,22)
    end=offset+((width*3+3)&~3)*height
    extended=False
    if len(header)>=112 and header[80:84]==b'HFXL':
        scene,payload,base=u32(header,88),u32(header,92),u32(header,96)
        page,count=u16(header,100),u16(header,102)
        extended=(u16(header,84)==1 and u16(header,86)==32 and page<6 and count==6 and
            u32(header,108)==0 and width==640 and height==480 and dib==40 and offset>=512 and
            scene==((end+511)//512)*512 and payload>=4096 and payload<=2097152 and payload%1024==0 and
            base%256==0 and base+payload//4<=1843200 and size==scene+payload)
    if (0<width<=640 and 0<height<=480 and u16(header,26)==1 and u16(header,28)==24 and u32(header,30)==0
        and dib in (40,108,124) and dib+14<=offset<=1048576 and end<=size and (size<=end+65536 or extended)):
        return dict(bytes=size,width=width,height=height)
    return None

def inspect(source,pack):
    expected={sha(p.read_bytes()):p.name for p in pack.iterdir() if p.suffix.upper() in ('.BMP','.WAV')}
    check(len(expected)==7,'requires exactly six distinct BMP files and one WAV')
    with open(source,'rb',buffering=0) as disk:
        def read_at(offset,length):
            disk.seek(offset);data=disk.read(length)
            check(len(data)==length,f'short read at byte {offset}, requested {length}')
            return data
        scan=read_at(0,SCAN_SECTORS*SECTOR)
        check(scan[510:512]==b'\x55\xaa','missing MBR/BPB signature')
        # Only explicit MBR FAT32 or superfloppy FAT32. GPT is intentionally unsupported.
        candidates=[]
        for off in (446,462,478,494):
            if scan[off+4] in (0x0b,0x0c): candidates.append(u32(scan,off+8))
        if u16(scan,11)==512 and scan[82:90].startswith(b'FAT32'): candidates=[0]
        check(len(candidates)==1,'requires exactly one unambiguous FAT32 MBR partition (GPT unsupported)')
        partition=candidates[0];bpb=read_at(partition*512,512)
        check(bpb[510:512]==b'\x55\xaa' and u16(bpb,11)==512,'requires 512-byte FAT32 sectors')
        spc=bpb[13];reserved=u16(bpb,14);nf=bpb[16];fs=u32(bpb,36);root=u32(bpb,44)
        check(spc>0 and spc&(spc-1)==0 and nf in (1,2) and fs>0 and reserved>0,'invalid FAT geometry')
        check(u16(bpb,17)==0 and u16(bpb,22)==0,'not FAT32')
        check(fs*512<=64*1024*1024,'FAT exceeds audit memory bound')
        total=u32(bpb,32);data_lba=partition+reserved+nf*fs
        cluster_count=(total-reserved-nf*fs)//spc
        check(cluster_count>=65525,'not FAT32 cluster count')
        fats=[read_at((partition+reserved+i*fs)*512,fs*512) for i in range(nf)]
        def chain(start):
            result=[];seen=set();current=start
            while current<0x0ffffff8:
                check(2<=current<cluster_count+2 and current not in seen,'invalid/looped FAT chain')
                seen.add(current);result.append(current)
                links=[u32(f,current*4)&0x0fffffff for f in fats]
                check(all(x==links[0] for x in links),'FAT copies disagree on used chain')
                current=links[0]
            return result
        def lba(cluster): return data_lba+(cluster-2)*spc
        entries=[];visited=set()
        def directory(start,prefix='',depth=0):
            check(depth<=8 and start not in visited,'directory cycle/depth limit')
            visited.add(start);clusters=chain(start)
            check(len(clusters)*spc*512<=8*1024*1024,'directory exceeds audit bound')
            data=b''.join(read_at(lba(c)*512,spc*512) for c in clusters)
            for off in range(0,len(data),32):
                e=data[off:off+32]
                if e[0]==0: break
                if e[0]==229 or e[11]==15 or e[11]&8: continue
                name=e[:8].decode('ascii',errors='replace').rstrip();ext=e[8:11].decode('ascii',errors='replace').rstrip()
                if name in ('.','..'): continue
                name=name+('.'+ext if ext else '')
                first=u16(e,20)<<16|u16(e,26);size=u32(e,28)
                if e[11]&16: directory(first,prefix+name+'/',depth+1)
                elif ext.upper() in ('BMP','WAV'):
                    check(0<size<=MAX_FILE,'media size outside audit bound')
                    clusters_file=chain(first)
                    check(len(clusters_file)==(size+spc*512-1)//(spc*512),'FAT chain length does not match file size')
                    payload=b''.join(read_at(lba(c)*512,spc*512) for c in clusters_file)[:size]
                    contiguous=all(b==a+1 for a,b in zip(clusters_file,clusters_file[1:]))
                    entries.append(dict(directory_name=prefix+name,bytes=size,start_lba=lba(first),end_lba=lba(first)+(size+511)//512-1,
                        cluster_count=len(clusters_file),contiguous=contiguous,sha256=sha(payload),matches_pack_name=expected.get(sha(payload)),fat_copies_agree=True))
        directory(root)
        bmp_hits=[];wav_candidates=[]
        for index in range(SCAN_SECTORS):
            header=scan[index*512:(index+1)*512]
            info=bmp_header(header)
            if info:
                payload=read_at(index*512,info['bytes'])
                bmp_hits.append(dict(start_lba=index,sha256=sha(payload),matches_pack_name=expected.get(sha(payload)),**info))
            if header[:4]==b'RIFF' and header[8:12]==b'WAVE':
                size=u32(header,4)+8
                check(12<=size<=MAX_FILE,'RIFF candidate size outside audit bound')
                payload=read_at(index*512,size)
                wav_candidates.append(dict(start_lba=index,bytes=size,sha256=sha(payload),matches_pack_name=expected.get(sha(payload))))
        issues=[]
        media=[x for x in entries if x['matches_pack_name']]
        if {x['sha256'] for x in media}!=set(expected): issues.append('selected pack files not all present with exact FAT file hashes')
        if any(not x['contiguous'] for x in media): issues.append('selected media has fragmented FAT chain; FPGA cannot traverse it')
        if any(x['start_lba']>=SCAN_SECTORS for x in media): issues.append('selected media starts beyond physical header scan range')
        expected_bmp={h for h,n in expected.items() if n.endswith('.BMP')}
        expected_wav={h for h,n in expected.items() if n.endswith('.WAV')}
        if len(bmp_hits)!=6 or {x['sha256'] for x in bmp_hits}!=expected_bmp or len(bmp_hits)!=len(expected_bmp):
            issues.append('unexpected, duplicate, missing or not exactly six physical BMP headers (including deleted/free regions)')
        if len(wav_candidates)!=1 or {x['sha256'] for x in wav_candidates}!=expected_wav:
            issues.append('unexpected/missing RIFF candidates; first WAV may capture audio discovery')
        intended=[p.name for p in sorted(pack.glob('*.BMP'))]
        actual=[x['matches_pack_name'] for x in bmp_hits]
        if intended!=actual: issues.append('physical BMP order differs from advisory filename order')
        return dict(status='PASS' if not issues else 'FAIL',read_only=True,source=str(source),selected_pack=str(pack),
            physical_scan=dict(start_lba=0,last_lba=131071,bytes=len(scan),sha256=sha(scan)),
            filesystem=dict(type='FAT32',partition_lba=partition,sectors_per_cluster=spc,fat_count=nf,fat_sectors=fs,data_lba=data_lba),
            fat_media=entries,bmp_physical_scan=bmp_hits,wav_physical_candidates=wav_candidates,issues=issues,
            hardware_functional_status='NOT_VERIFIED',card_write_performed=False,
            scope='FAT allocation and physical hashes only; actual RTL WAV parser/HDMI playback still requires hardware evidence')

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source',required=True,help=r'whole-disk image or explicitly selected read-only \\.\PhysicalDriveN')
    p.add_argument('--pack',required=True,type=Path,help='directory containing the unified six BMP files and one WAV')
    p.add_argument('--report',type=Path,help='optional ordinary JSON evidence file; defaults to stdout')
    args=p.parse_args()
    try: result=inspect(args.source,args.pack)
    except Exception as e: result=dict(status='FAIL',read_only=True,card_write_performed=False,error=str(e),hardware_functional_status='NOT_VERIFIED')
    text=json.dumps(result,ensure_ascii=False,indent=2)+'\n'
    if args.report:
        check(not str(args.report).startswith(('\\\\.\\','/dev/')),'report must be ordinary evidence file')
        check(str(args.report.resolve())!=str(Path(args.source).resolve()),'report cannot overwrite source')
        check(args.report.suffix.lower()=='.json','report must have .json suffix')
        args.report.parent.mkdir(parents=True,exist_ok=True);args.report.write_text(text,encoding='utf-8')
    print(text,end='')
    if result['status']!='PASS': raise SystemExit(1)

if __name__=='__main__': main()
