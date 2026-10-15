#!/usr/bin/env python3
"""Independent binary validator; does not import the producer or trust its format claims."""
from __future__ import annotations
import argparse, array, hashlib, json, math, struct, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def digest(data): return hashlib.sha256(data).hexdigest()
def require(test, message):
    if not test: raise ValueError(message)

def bmp(data):
    require(len(data)>=54,'truncated BMP')
    signature,length,res1,res2,offset=struct.unpack_from('<2sIHHI',data)
    dib,width,height,planes,bits,compression,image_size=struct.unpack_from('<IiiHHII',data,14)
    require(signature==b'BM' and length==len(data),'BMP signature/declared length')
    require((res1,res2,offset,dib,planes,bits,compression)==(0,0,54,40,1,24,0),'canonical BMP contract')
    require(0<width<=640 and 0<height<=480,'BMP dimensions/bottom-up')
    stride=(width*3+3)//4*4
    require(image_size==stride*height and length==54+image_size,'BMP image payload/stride')
    rows=[]
    for y in range(height-1,-1,-1):
        row=data[offset+y*stride:offset+(y+1)*stride]
        require(not any(row[width*3:]),'BMP row padding not zero')
        rgb=bytearray(width*3)
        for x in range(width):
            b,g,r=struct.unpack_from('BBB',row,x*3)
            rgb[x*3:x*3+3]=bytes((r,g,b))
        rows.append(rgb)
    pixels=b''.join(rows)
    return dict(width=width,height=height,bits=bits,compression=compression,stride=stride,bottom_up=True,
        header_sha256=digest(data[:54]),rgb_sha256=digest(pixels),bytes=len(data)),pixels

def wav(data):
    require(len(data)>=44 and data[:4]==b'RIFF' and data[8:12]==b'WAVE','WAV RIFF/WAVE')
    require(struct.unpack_from('<I',data,4)[0]+8==len(data),'RIFF length')
    fmt=None; pcm=None; data_offset=None; pos=12
    while pos+8<=len(data):
        kind=data[pos:pos+4];size=struct.unpack_from('<I',data,pos+4)[0];start=pos+8;end=start+size
        require(end<=len(data),'truncated RIFF chunk')
        if kind==b'fmt ':
            require(fmt is None and size>=16,'WAV duplicate/short fmt')
            fmt=struct.unpack_from('<HHIIHH',data,start)
        elif kind==b'data':
            require(pcm is None,'WAV duplicate data');pcm=data[start:end];data_offset=start
        pos=end+(size&1)
    require(pos==len(data) and fmt is not None and pcm is not None,'WAV chunks complete')
    encoding,channels,rate,byte_rate,align,bits=fmt
    require(data_offset<4096,'WAV exceeds RTL 4096-byte header bound')
    require(encoding==1 and channels in (1,2) and rate==48000 and bits==16,'WAV PCM16 48k mono/stereo')
    require(align==channels*2 and byte_rate==rate*align and len(pcm)%align==0,'WAV sample bounds/alignment')
    samples=array.array('h');samples.frombytes(pcm)
    if sys.byteorder!='little': samples.byteswap()
    require(len(samples)>0,'empty WAV')
    peak=max(abs(x) for x in samples);clipped=sum(x in (-32768,32767) for x in samples)
    require(clipped==0,'WAV clipping')
    rms=math.sqrt(sum(x*x for x in samples)/len(samples))
    adjacent_step=max(abs(b-a) for a,b in zip(samples,samples[channels:]))
    tail_samples=rate*channels
    final_second_silent=all(x==0 for x in samples[-tail_samples:])
    require(final_second_silent,'WAV clean final-second silence')
    return dict(channels=channels,sample_rate=rate,bits=bits,frames=len(samples)//channels,
        seconds=len(samples)/channels/rate,data_offset=data_offset,peak_pcm=peak,peak_dbfs=round(20*math.log10(max(peak,1)/32768),3),
        rms_pcm=round(rms,3),max_per_channel_adjacent_step=adjacent_step,clipped_samples=clipped,final_second_silent=final_second_silent,pcm_sha256=digest(pcm),bytes=len(data))

def ppm_pixels(path):
    # Independent source reader, with a byte-token scanner rather than producer code.
    data=path.read_bytes();pos=0;parts=[]
    while len(parts)<4:
        while data[pos] in b' \r\n\t': pos+=1
        if data[pos]==35:
            while data[pos]!=10: pos+=1
            continue
        token=bytearray()
        while data[pos] not in b' \r\n\t': token.append(data[pos]);pos+=1
        parts.append(bytes(token))
    require(parts[0]==b'P6' and parts[3]==b'255','source PPM')
    pos+=2 if data[pos:pos+2]==b'\r\n' else 1
    width,height=int(parts[1]),int(parts[2]);pixels=data[pos:]
    require(len(pixels)==width*height*3,'source PPM length')
    return width,height,pixels

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--report',type=Path,default=ROOT/'evidence/media/validation.json');args=p.parse_args()
    manifest=json.loads((ROOT/'tf_card_package/manifest.json').read_text())
    results=[];errors=[]
    canonical=manifest['canonical']
    ids={f'UI-{i:02}' for i in range(1,7)}
    paths={f'tf_card_package/master_media/UI{i:02}.BMP' for i in range(1,7)}
    if len(canonical)!=6 or {r['page'] for r in canonical}!=ids or {r['path'] for r in canonical}!=paths:
        errors.append('canonical collection must contain exactly six unique UI-01..UI-06 IDs and matching master file paths')
    actual_master={str(p.relative_to(ROOT)) for p in (ROOT/'tf_card_package/master_media').glob('*.BMP')}
    if actual_master!=paths: errors.append('master directory must contain exactly UI01.BMP..UI06.BMP')
    for record in manifest['canonical']:
        try:
            path=ROOT/record['path'];data=path.read_bytes();info,pixels=bmp(data)
            sw,sh,source=ppm_pixels(ROOT/record['source'])
            require(digest((ROOT/record['source']).read_bytes())==record['source_sha256'],'source PPM changed after packaging')
            require((sw,sh)==(640,480)==(info['width'],info['height']),'canonical size')
            require(pixels==source,'BMP source pixels/orientation/channel order differ')
            require(digest(data)==record['sha256'] and digest(source)==record['rgb_sha256'],'canonical digest')
            results.append(dict(path=record['path'],status='PASS',sha256=digest(data),source_pixels_equal=True,**info))
        except Exception as e: errors.append(f"{record['path']}: {e}")
    counts={}
    require(set(manifest['sets'])=={'A_daily','B_emergency','C_features'},'expected independent sets')
    for name, pack in manifest['sets'].items():
        folder=ROOT/'tf_card_package'/name
        actual={x.name for x in folder.iterdir() if x.suffix.lower() in ('.bmp','.wav')}
        expected={x['name'] for x in pack['files']}
        if actual!=expected: errors.append(f'{name}: directory file set differs from manifest')
        count=sum(x.upper().endswith('.BMP') for x in actual);wcount=sum(x.upper().endswith('.WAV') for x in actual)
        counts[name]=dict(bmp=count,wav=wcount)
        if count!={'A_daily':2,'B_emergency':4,'C_features':4}[name] or wcount!=1:
            errors.append(f'{name}: exact selected pack BMP count and one WAV required')
        for record in pack['files']:
            try:
                path=folder/record['name'];data=path.read_bytes()
                require(len(data)==record['bytes'] and digest(data)==record['sha256'],'file manifest integrity')
                if path.suffix=='.BMP':
                    info,_=bmp(data)
                    if name!='C_features':
                        require((info['width'],info['height'])==(640,480),'product page must be native 640x480')
                        page_index=int(path.name[:2]) if name=='A_daily' else int(path.name[:2])+2
                        require(data==(ROOT/f'tf_card_package/master_media/UI{page_index:02}.BMP').read_bytes(),'boot-set page differs from canonical master')
                    else:
                        expected_size=((320,240),(320,180),(640,360),(640,480))[int(path.name[:2])-1]
                        require((info['width'],info['height'])==expected_size,'technical fixture size')
                else:
                    info=wav(data)
                    require(info['seconds']==(30 if name=='C_features' else 80),'soundtrack duration')
                    if name!='C_features': require(info['peak_pcm']<12000,'ambient/cue amplitude bound')
                results.append(dict(path=str(path.relative_to(ROOT)),status='PASS',sha256=digest(data),**info))
            except Exception as e: errors.append(f'{name}/{record["name"]}: {e}')
    report=dict(status='PASS' if not errors else 'FAIL',validator_sha256=digest(Path(__file__).read_bytes()),
        verified='Offline canonical binary structure, decoded pixel equality, per-boot media counts, PCM bounds and hashes',
        package_counts=counts,files=results,errors=errors,physical_allocation='NOT_VERIFIED',hardware='NOT_VERIFIED',
        filenames='advisory only; order requires physical LBA audit',audio_page_sync='NOT_SUPPORTED')
    args.report.parent.mkdir(parents=True,exist_ok=True);args.report.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(dict(status=report['status'],files=len(results),counts=counts,errors=errors),indent=2))
    if errors: raise SystemExit(1)

if __name__=='__main__': main()
