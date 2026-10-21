#!/usr/bin/env python3
"""One-time source-faithful HTML layer export. Python stdlib + installed Chrome.
Outputs are local review artifacts; no fonts or official assets are redistributed.
"""
import argparse, base64, hashlib, html, json, re, struct, subprocess, time, zlib
from pathlib import Path

def png(path):
    d=path.read_bytes(); pos=8; data=b''
    while pos<len(d):
        n=struct.unpack_from('>I',d,pos)[0]; typ=d[pos+4:pos+8]; v=d[pos+8:pos+8+n]; pos+=n+12
        if typ==b'IHDR': w,h,depth,color,*_=struct.unpack('>IIBBBBB',v)
        if typ==b'IDAT': data+=v
    assert depth==8 and color in (2,6),(depth,color)
    bpp=4 if color==6 else 3; raw=zlib.decompress(data); stride=w*bpp; rows=[]; prev=bytes(stride); p=0
    for _ in range(h):
        f=raw[p]; p+=1; cur=bytearray(raw[p:p+stride]);p+=stride
        for i in range(stride):
            a=cur[i-bpp] if i>=bpp else 0;b=prev[i];c=prev[i-bpp] if i>=bpp else 0
            if f==1: q=a
            elif f==2:q=b
            elif f==3:q=(a+b)//2
            elif f==4:
                t=a+b-c; ds=[abs(t-a),abs(t-b),abs(t-c)];q=(a,b,c)[ds.index(min(ds))]
            else:q=0
            cur[i]=(cur[i]+q)&255
        rows.append(bytes(cur));prev=cur
    rgba=bytearray()
    for row in rows:
        for i in range(0,len(row),bpp):rgba.extend(row[i:i+3]+(row[i+3:i+4] if bpp==4 else b'\xff'))
    return w,h,rgba

def bmp(path,w,h,rgba):
    stride=(w*3+3)&~3;pix=bytearray()
    for y in range(h-1,-1,-1):
        for x in range(w):
            i=(y*w+x)*4;r,g,b=rgba[i:i+3];pix.extend((b,g,r))
        pix.extend(bytes(stride-w*3))
    path.write_bytes(struct.pack('<2sIHHI',b'BM',54+len(pix),0,0,54)+struct.pack('<IiiHHIIiiII',40,w,h,1,24,0,len(pix),2835,2835,0,0)+pix)

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--prototype',type=Path,required=True);ap.add_argument('--out',type=Path,required=True);ap.add_argument('--chrome',default='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome');a=ap.parse_args()
    out=a.out;out.mkdir(parents=True,exist_ok=True);tmp=out/'local_temp';tmp.mkdir(exist_ok=True)
    source=(a.prototype/'anlogic-exhibit.html').read_text(encoding='utf-8');seed='<script>let seed=20261015;Math.random=()=>((seed=(1664525*seed+1013904223)>>>0)/4294967296);window.requestAnimationFrame=()=>0;</script>'
    source=source.replace('<script>',seed+'<script>',1)
    css='''<style>html,body{width:640px;height:480px;display:block!important;overflow:hidden!important;background:transparent!important}.viewport{position:absolute!important;left:0;top:0;width:640px;height:480px;padding:0!important;display:block!important;min-height:0!important}.frame{position:absolute!important;left:0;top:0;width:640px!important;height:480px!important;box-shadow:none!important}#stage{transform:none!important}.panel,.viewport-meta{display:none!important}*,*::before,*::after{animation:none!important;transition:none!important}</style>'''
    base="S.playing=false;S.acc=0;clock.t=0;bot.t=0;bot.queue=[];bot.blinkAt=99999;bot.nextLook=99999;bot.nextCurious=99999;bot.render(0);scenes.forEach(s=>s.className='scene '+PAGES[scenes.indexOf(s)].cls);"
    records=[]
    def render(name,js='',kind='reference',size=(640,480),extra=''):
        f=tmp/(name+'.html'); target=out/(name+'.png')
        f.write_text(source.replace('</head>',css+extra+'</head>').replace('</body>',f'<script>{base}{js}</script></body>'))
        cmd=[a.chrome,'--headless','--disable-gpu','--no-first-run','--no-default-browser-check','--hide-scrollbars','--force-device-scale-factor=1','--default-background-color=00000000',f'--user-data-dir={tmp/"chrome_profile"}',f'--window-size={size[0]},{size[1]}','--virtual-time-budget=300',f'--screenshot={target}',f.as_uri()]
        t=time.monotonic();p=subprocess.run(cmd,capture_output=True);(tmp/(name+'.log')).write_bytes(p.stderr);assert p.returncode==0,(name,p.stderr)
        w,h,rgba=png(target);assert(w,h)==size,(name,w,h)
        if kind in ('scene','panel'):bmp(out/(name+'.bmp'),w,h,rgba)
        records.append(dict(name=name,kind=kind,width=w,height=h,sha256=hashlib.sha256(target.read_bytes()).hexdigest(),seconds=round(time.monotonic()-t,3)))
        return rgba
    for i,n in enumerate(['home','eagle','phoenix','elf','dragon','eco']):
        state=f'S.page={i};scenes[{i}].classList.add("on");updateOSD(false);sayEl.textContent=PAGES[{i}].say;bot.render(0);vizStep(.1);'
        render('A_'+str(i+1).zfill(2)+'_'+n,state+'$("#osd").style.display="none";$("#bot").style.display="none";','scene')
        render('reference_'+n,state)
    for i,n in enumerate(['eagle','phoenix','elf','dragon'],1):
        render('panel_'+n,f'S.page={i};setCompare(true);$("#osd").style.display="none";$("#bot").style.display="none";$(".half.r").remove();$(".seam").remove();$(".cmp-title").remove();','panel',(320,480))
    render('reference_dual','S.page=1;setCompare(true);sayEl.textContent=cmpLine();bot.render(0);vizStep(.1);')
    render('reference_zoom','S.page=1;scenes[1].classList.add("on");updateOSD(false);sayEl.textContent=PAGES[1].say;setZoom(true);bot.render(0);vizStep(.1);')
    for seconds in [0,.09,.42,1.1,1.55]:
        render('timed_bot_'+str(round(seconds*1000)).zfill(4)+'ms','scenes[0].classList.add("on");go(1,"next");last=0;'+f'for(let n=1;n<={round(seconds*60)};n++)frame(n*1000/60);')
    rgba=render('bot_body_nominal','$("#bmp").remove();$("#osd").remove();$("#stage").style.background="transparent";$("#frame").style.background="transparent";$("#bot").style.left="0";$("#bot").style.top="0";bot.$l.remove();bot.$r.remove();bot.render=()=>{};','body',(104,100))
    levels=[0,2,4,7,11,16,22,29,37,46,58,74,96,128,176,255]
    q=lambda v:min(range(16),key=lambda i:abs(levels[i]-v))
    words=[]
    for i in range(0,len(rgba),4):
        r,g,b,alpha=rgba[i:i+4];words.append(f'{((alpha+8)//17<<12)|(q(r)<<8)|(q(g)<<4)|q(b):04x}')
    (out/'bot_body_argb4444.hex').write_text('\n'.join(words)+'\n')
    manifest=dict(source_root=str(a.prototype),source_files={str(p.relative_to(a.prototype)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(a.prototype.rglob('*')) if p.is_file()},renderer=subprocess.check_output([a.chrome,'--version'],text=True).strip(),stage=[640,480],seed=20261015,body_format='10400 row-major16bit ARGB4444;alpha linear,RGB nibble palette[0,2,4,7,11,16,22,29,37,46,58,74,96,128,176,255]; no eyes; shadow y>=90 fixed ground',records=records,scope='Native static layers; dynamic OSD/body separate. Reference composites are visual evidence, never runtime movies.',font_policy='Original CSS font stack; local installed fonts only, no font files copied.')
    (out/'asset_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'outputs':len(records),'out':str(out)},ensure_ascii=False))
if __name__=='__main__':main()
