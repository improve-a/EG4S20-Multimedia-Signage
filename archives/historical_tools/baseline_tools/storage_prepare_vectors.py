"""Independent BMP golden model. Run from workspace; no device or tool launches."""
import argparse,hashlib,json,struct
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]);a=p.parse_args();root=a.root
out=root/'tb/storage_data';out.mkdir(exist_ok=True)
rows=[]
for i,src in enumerate(sorted((root/'tb/images').glob('HXTEST*.BMP')),1):
    b=src.read_bytes(); magic,size,_,_,offset=struct.unpack_from('<2sIHHI',b);dib,w,h,planes,bpp,comp=struct.unpack_from('<IiiHHI',b,14)
    assert magic==b'BM' and len(b)==size and dib>=40 and w==640 and h==480 and planes==1 and bpp==24 and comp==0
    stride=((w*bpp+31)//32)*4
    assert offset>=14+dib and offset+stride*h<=len(b)
    pixels=[]
    for y in range(h):
        for x in range(w):
            blue,green,red=b[offset+y*stride+x*3:offset+y*stride+x*3+3];pixels.append((red<<16)|(green<<8)|blue)
    padded=b+bytes((-len(b))%512)
    (out/f'bmp{i}.hex').write_text('\n'.join(f'{v:02x}' for v in padded)+'\n',encoding='ascii')
    (out/f'pixels{i}.hex').write_text('\n'.join(f'{v:06x}' for v in pixels)+'\n',encoding='ascii')
    topdown=[pixels[(h-y-1)*w+x] for y in range(h) for x in range(w)]
    (out/f'frame{i}.hex').write_text('\n'.join(f'{v:06x}' for v in topdown)+'\n',encoding='ascii')
    rows.append(dict(source=str(src.relative_to(root)),sha256=hashlib.sha256(b).hexdigest(),width=w,height=h,pixels=len(pixels),offset=offset,file_bytes=len(b),sector_bytes=len(padded)))
(out/'manifest.json').write_text(json.dumps(rows,indent=2)+'\n')
print(json.dumps({'status':'PASS','vectors':rows},indent=2))
