#!/usr/bin/env python3
"""Create/independently inspect an ordinary FAT32 image, never a card/device.
Geometry/encoding follows existing scripts/html_card_image.py, generalized to the
explicit sixUI/fourPN/WAV order. All readers/writers accept ordinary .img only.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import struct
import sys
import time
from html_card_image import SECTOR, TOTAL, RESERVED, FAT_SECTORS, DATA_LBA, CLUSTERS, u16, u32

ROOT = Path(__file__).resolve().parents[1]
ORDER = [f'UI{i:02d}.BMP' for i in range(1,7)] + [f'PN{i:02d}.BMP' for i in range(1,5)] + ['07_MUSIC.WAV']
LABEL = b'NOBOT2026  '

def sha(data):
    return hashlib.sha256(data).hexdigest()

def ordinary_image(path):
    text = str(path)
    if path.suffix.lower() != '.img' or text.startswith(('\\\\.\\','\\\\?\\','/dev/')):
        raise ValueError('only ordinary .img files are accepted; device paths forbidden')

def create(pack, output):
    ordinary_image(output)
    manifest = json.loads((pack/'manifest.json').read_text(encoding='utf-8'))
    if manifest['loading_order'] != ORDER or [a['name'] for a in manifest['assets']] != ORDER:
        raise ValueError('source manifest does not declare exact10BMP+WAV catalog')
    records=[]
    next_cluster=3
    for index, name in enumerate(ORDER):
        path=pack/name
        data=path.read_bytes()
        expected=manifest['assets'][index]
        if sha(data)!=expected['sha256'] or len(data)!=expected['bytes']:
            raise ValueError('source media hash/size mismatch '+name)
        sectors=(len(data)+511)//512
        records.append(dict(name=name,index=index,bytes=len(data),sha256=sha(data),cluster=next_cluster,
                            cluster_count=sectors,sectors=sectors,start_lba=DATA_LBA+next_cluster-2,
                            end_lba=DATA_LBA+next_cluster-2+sectors-1))
        next_cluster+=sectors
    if next_cluster>CLUSTERS+2:
        raise ValueError('source media exceeds64MiB image')
    boot=bytearray(512)
    boot[:3]=b'\xeb\x58\x90';boot[3:11]=b'NOBOT   '
    u16(boot,11,512);boot[13]=1;u16(boot,14,RESERVED);boot[16]=2;boot[21]=0xf8
    u16(boot,24,63);u16(boot,26,255);u32(boot,32,TOTAL);u32(boot,36,FAT_SECTORS)
    u32(boot,44,2);u16(boot,48,1);u16(boot,50,6);boot[64]=0x80;boot[66]=0x29
    u32(boot,67,0x20261018);boot[71:82]=LABEL;boot[82:90]=b'FAT32   ';boot[510:]=b'\x55\xaa'
    info=bytearray(512);u32(info,0,0x41615252);u32(info,484,0x61417272)
    u32(info,488,CLUSTERS-(next_cluster-2));u32(info,492,next_cluster);u32(info,508,0xaa550000)
    fat=bytearray(FAT_SECTORS*512);u32(fat,0,0x0ffffff8);u32(fat,4,0xffffffff);u32(fat,8,0x0fffffff)
    root=bytearray(512);root[:11]=LABEL;root[11]=8
    date=((2026-1980)<<9)|(10<<5)|18
    for slot, record in enumerate(records,1):
        start=record['cluster'];count=record['cluster_count']
        for cluster in range(start,start+count):
            u32(fat,cluster*4,cluster+1 if cluster+1<start+count else 0x0fffffff)
        entry=bytearray(32);stem,extension=record['name'].split('.')
        entry[:11]=(stem.ljust(8)+extension.ljust(3)).encode('ascii');entry[11]=0x20
        u16(entry,16,date);u16(entry,18,date);u16(entry,20,start>>16);u16(entry,24,date)
        u16(entry,26,start&65535);u32(entry,28,record['bytes']);root[slot*32:(slot+1)*32]=entry
    output.parent.mkdir(parents=True,exist_ok=True)
    with output.open('xb') as stream:
        stream.truncate(TOTAL*512)
        for sector,data in [(0,boot),(1,info),(6,boot),(7,info),(RESERVED,fat),(RESERVED+FAT_SECTORS,fat),(DATA_LBA,root)]:
            stream.seek(sector*512);stream.write(data)
        for record in records:
            stream.seek(record['start_lba']*512);stream.write((pack/record['name']).read_bytes())
    return records

def inspect(image, pack):
    """Parse persisted BPB/FAT/directories and emulate scanner independently of builder records."""
    ordinary_image(image)
    expected=json.loads((pack/'manifest.json').read_text(encoding='utf-8'))
    expected_by_name={entry['name']:entry for entry in expected['assets']}
    data=image.read_bytes()
    def r16(buf,offset):return struct.unpack_from('<H',buf,offset)[0]
    def r32(buf,offset):return struct.unpack_from('<I',buf,offset)[0]
    def check(test,message):
        if not test:raise ValueError(message)
    check(data[510:512]==b'\x55\xaa' and r16(data,11)==512 and data[82:90]==b'FAT32   ','FAT32 boot identity')
    spc=data[13];reserved=r16(data,14);nf=data[16];fat_sectors=r32(data,36);root_cluster=r32(data,44)
    total=r32(data,32);data_lba=reserved+nf*fat_sectors;clusters=(total-data_lba)//spc
    check(spc==1 and nf==2 and clusters>=65525,'valid FAT32 geometry')
    check(len(data)==total*512 and r16(data,17)==0 and r16(data,22)==0,'FAT32 extent')
    check(data[:512]==data[6*512:7*512] and data[512:1024]==data[7*512:8*512],'boot/FSInfo backups')
    fats=[data[(reserved+i*fat_sectors)*512:(reserved+(i+1)*fat_sectors)*512] for i in range(nf)]
    check(fats[0]==fats[1],'FAT copies identical')
    def chain(start):
        result=[];seen=set();current=start
        while current<0x0ffffff8:
            check(2<=current<clusters+2 and current not in seen,'invalid/looped FAT chain')
            seen.add(current);result.append(current);current=r32(fats[0],current*4)&0x0fffffff
        return result
    def lba(cluster):return data_lba+(cluster-2)*spc
    root=b''.join(data[lba(c)*512:(lba(c)+spc)*512] for c in chain(root_cluster))
    records=[]
    used_clusters=set(chain(root_cluster))
    for offset in range(0,len(root),32):
        entry=root[offset:offset+32]
        if entry[0]==0:break
        if entry[0]==229 or entry[11]==15 or entry[11]&8:continue
        check(not entry[11]&16,'no unexpected subdirectory')
        name=entry[:8].decode('ascii').rstrip()+'.'+entry[8:11].decode('ascii').rstrip()
        start=(r16(entry,20)<<16)|r16(entry,26);size=r32(entry,28);links=chain(start)
        check(name in expected_by_name,'unexpected file '+name)
        check(len(links)==(size+spc*512-1)//(spc*512),'FAT chain vs filesize')
        check(all(b==a+1 for a,b in zip(links,links[1:])),'file is fragmented '+name)
        check(not used_clusters.intersection(links),'crosslinked file '+name);used_clusters.update(links)
        payload=b''.join(data[lba(c)*512:(lba(c)+spc)*512] for c in links)[:size]
        check(sha(payload)==expected_by_name[name]['sha256'] and size==expected_by_name[name]['bytes'],'file hash/size '+name)
        records.append(dict(index=len(records),name=name,bytes=size,sha256=sha(payload),first_cluster=start,
                            last_cluster=links[-1],cluster_count=len(links),start_lba=lba(start),
                            end_lba=lba(start)+(size+511)//512-1,contiguous=True,fat_copies_agree=True))
    check([record['name'] for record in records]==ORDER,'directory loading order')
    check([record['name'] for record in sorted(records,key=lambda r:r['start_lba'])]==ORDER,'physical loading order')
    check(all(b['start_lba']==a['end_lba']+1 for a,b in zip(records,records[1:])),'files physically adjacent')
    info=data[512:1024]
    check((r32(info,0),r32(info,484),r32(info,508))==(0x41615252,0x61417272,0xaa550000),'FSInfo signatures')
    check(r32(info,488)==clusters-len(used_clusters),'FSInfo free cluster count')
    check(r32(info,492)==max(used_clusters)+1,'FSInfo next free cluster')
    # Software equivalent of bmp_scale_read: on accepted header skip ceil(bfSize/512), otherwise advance one sector.
    def bmp_header(header):
        if header[:2]!=b'BM':return None
        size,off,dib,w,h=r32(header,2),r32(header,10),r32(header,14),r32(header,18),r32(header,22)
        stride=(w*3+3)&~3;pixel_end=off+stride*h
        ok=(0<w<=640 and 0<h<=480 and r16(header,26)==1 and r16(header,28)==24 and r32(header,30)==0
            and dib in (40,108,124) and dib+14<=off<=1048576 and pixel_end<=size<=pixel_end+65536)
        return dict(bytes=size,width=w,height=h,pixel_offset=off,sectors=(size+511)//512) if ok else None
    by_lba={record['start_lba']:record for record in records};hits=[];sector=0;headers_examined=0
    while sector<=131071 and len(hits)<10:
        header=data[sector*512:(sector+1)*512];info=bmp_header(header);headers_examined+=1
        if info:
            record=by_lba.get(sector)
            check(record is not None,'scanner hit an unexpected header')
            check(info['bytes']==record['bytes'] and info['pixel_offset']==512,'scanner header identity')
            hits.append(dict(index=len(hits),name=record['name'],start_lba=sector,next_lba=sector+info['sectors'],**info))
            sector+=info['sectors']
        else:sector+=1
    check([hit['name'] for hit in hits]==ORDER[:10],'scanner did not discover all10BMPs in order')
    check(sector==records[10]['start_lba'],'scanner next LBA must equal WAV start')
    # Exhaustive sector-boundary audit catches stale/free-space headers outside skipped BMP payload extents.
    physical_bmp=[];riff=[]
    for index in range(total):
        header=data[index*512:(index+1)*512]
        if bmp_header(header):physical_bmp.append(index)
        if header[:4]==b'RIFF' and header[8:12]==b'WAVE':riff.append(index)
    check(physical_bmp==[record['start_lba'] for record in records[:10]],'unexpected sector-aligned BMP signature')
    check(riff==[records[10]['start_lba']],'unexpected/missing physicalWAV header')
    return dict(state='FAT32_IMAGE_AND_PHYSICAL_ORDER_PASS',path=str(image.resolve()),bytes=len(data),sha256=sha(data),
                filesystem=dict(type='FAT32 superfloppy',partition_lba=0,sector_bytes=512,sectors_per_cluster=spc,
                                total_sectors=total,data_lba=data_lba,root_cluster=root_cluster,fat_count=nf,fat_sectors=fat_sectors,
                                cluster_count=clusters,fsinfo_free_clusters=r32(data[512:1024],488)),
                loading_order=ORDER,files=records,scanner=dict(state='PASS',scan_start_lba=0,scan_max_lba=131071,
                    scan_target_count=10,headers_examined=headers_examined,bmp_hits=hits,next_lba_after10BMPs=sector,
                    all_sector_boundary_bmp_hits=physical_bmp,wav_header_lbas=riff,
                    model='bmp_scale_read accepts width<=640,height<=480,BMP24 BI_RGB; accepted files advance ceil(bfSize/512), misses advance1sector. Software model, not RTL simulation.'),
                hardware='HARDWARE_NOT_TESTED',device_access=False,
                scope='Persisted-image FAT/directory/cluster continuity, source-byte hashes,physical order and software scanner contract. Actual card allocation/RTL/hardware remain separate.')

def documentation(report, output):
    lines=['# 无 Bot 普通媒体与离线 FAT32 镜像','',
           '本目录提供六页 UI、四份独立产品面板、原 WAV，以及可复现的 64 MiB FAT32 超软盘镜像。今夜没有操作实体卡。',
           '', '文件镜像：`'+output.name+'`；完整镜像与文件 SHA256、cluster/LBA 索引见 `'+output.with_suffix('.json').name+'`。',
           '', '```powershell', r'D:\python3.12.3\python.exe -X utf8 scripts\no_bot_package_media.py',
           r'D:\python3.12.3\python.exe -X utf8 scripts\no_bot_media_image.py',
           r'D:\python3.12.3\python.exe -X utf8 scripts\no_bot_media_image.py --validate-only', '```','',
           '镜像已存在时生成入口仅独立验证，避免覆盖交付；源素材改变时请指定新的普通 `.img` 输出路径。',
           '', '## 镜像内部已验证的布局','',
           '| 索引 | 文件 | 首 cluster | clusters | 首 LBA | 末 LBA | bytes |',
           '|---:|---|---:|---:|---:|---:|---:|']
    for record in report['files']:
        lines.append(f"|{record['index']}|{record['name']}|{record['first_cluster']}|{record['cluster_count']}|{record['start_lba']}|{record['end_lba']}|{record['bytes']}|")
    lines += ['', '512B/cluster，文件各自连续且按 UI01..06 → PN01..04 → WAV 紧邻排列。根目录顺序与物理顺序相同。',
              'BMP 都是 offset512、DIB40、24bit BI_RGB、正高度480；UI宽640、PN宽320。静态素材不含动态字幕卡。',
              'PN01/02/03/04 分别为猎鹰/凤凰/精灵/飞龙，运行时组成左右画面；未交付预拼双图。',
              '', '## 明日部署与验证','',
              'FPGA 按物理扇区查找 BMP/RIFF，不遍历 FAT 文件链。文件名和普通复制顺序不能保证实体卡上的连续性或发现顺序。',
              '若在单独授权的上板环节将整个镜像逐扇区写入合适实体卡，并在不移动/重写媒体文件的前提下读回校验，镜像索引才对应该卡：首 UI LBA2081、WAV LBA16491。整体镜像部署会覆盖卡上布局，今夜未执行。',
              '若采用普通文件复制，请在新准备的 FAT32 卡上按 UI01..06、PN01..04、WAV 顺序复制这11个媒体文件，不复制日志/JSON/镜像。该操作只是安排顺序；仍须独立检查 FAT 链连续、所有文件首 LBA 在0..131071、物理BMP顺序为10项且没有旧/已删除媒体残留头。',
              '实际卡任一文件碎片化、物理顺序不符或旧媒体头干扰时，应在单独授权的卡准备流程中重新建立连续顺序布局并重新读回核对；不能靠重命名或反复覆盖保证。不要沿用旧卡扇区索引。',
              '本离线镜像中的cluster/LBA不能用于任意普通复制后的卡。当前硬件状态为 HARDWARE_NOT_TESTED。',
              '', '## 独立核验范围','',
              '读回解析BPB、备份、两份FAT、目录和每条文件链；逐文件验证原始字节SHA256；检查无交叉链接/碎片并核对FSInfo。',
              '从LBA0按旧scanner规则遇有效BMP跳过ceil(bfSize/512)扇区，遇非BMP前进一扇区，发现顺序和数量10均通过。另逐一审查131072个扇区边界，确认只有10个有效BMP头和一个目标WAV头。',
              '这项检查是软件对持久化镜像的验证；RTL加载、双图/缩放及HDMI音频验收分别提供证据。','']
    (output.parent/'DEPLOYMENT.md').write_text('\n'.join(lines),encoding='utf-8')
    (output.parent/'SHA256SUMS').write_text(''.join(f"{r['sha256']}  {r['name']}\n" for r in report['files'])+f"{report['sha256']}  {output.name}\n",encoding='ascii')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pack',type=Path,default=ROOT/'output/html_fidelity/no_bot/media')
    parser.add_argument('--output',type=Path)
    parser.add_argument('--validate-only',action='store_true')
    args=parser.parse_args();output=args.output or args.pack/'no_bot_fat32.img'
    started=time.monotonic();created=False
    if not args.validate_only and not output.exists():create(args.pack,output);created=True
    result=inspect(output,args.pack)
    result['generator']=dict(path=str(Path(__file__).resolve()),sha256=sha(Path(__file__).read_bytes()),
                             reused_geometry_source='scripts/html_card_image.py',python=sys.version,pid=os.getpid(),
                             created_this_invocation=created,exit_code=0,wall_seconds=round(time.monotonic()-started,3),
                             completed_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
    output.with_suffix('.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    documentation(result,output)
    print(json.dumps(dict(state=result['state'],path=result['path'],sha256=result['sha256'],files=len(result['files']),
                          scan_target_count=10,created=created,wall_seconds=result['generator']['wall_seconds']),ensure_ascii=False))

if __name__=='__main__':main()
