#!/usr/bin/env python3
"""No-Bot HTML reference + append-only caption assets; stdlib/installed Chrome only."""
import argparse, copy, datetime, hashlib, html, json, os, re, struct, subprocess, sys, time, traceback
from pathlib import Path
from html_fidelity_assets import png
ROOT=Path(__file__).resolve().parents[1]
SOURCE_SHA='d1171344c3cc83f371fc6875d718ea978a56746945375b3afa2224810e46ea43'
ATLAS_SHA='e66dab4f24e304e3ab46d8ad4095d3f9bdbadabc85d899d64f1c569bca20a533'
NAMES=['home','eagle','phoenix','elf','dragon','eco']
CSS='''<style>html,body{margin:0!important;width:640px!important;height:480px!important;display:block!important;overflow:hidden!important;background:transparent!important}.viewport{position:absolute!important;left:0;top:0;width:640px;height:480px;padding:0!important;display:block!important;min-height:0!important}.frame{position:absolute!important;left:0;top:0;width:640px!important;height:480px!important;box-shadow:none!important}#stage{transform:none!important}.panel,.viewport-meta{display:none!important}*,*::before,*::after{animation:none!important;transition:none!important}</style>'''
PRE='''<script>window.__errors=[];addEventListener('error',e=>__errors.push(e.message));addEventListener('unhandledrejection',e=>__errors.push(String(e.reason)));let seed=20261018;Math.random=()=>((seed=(1664525*seed+1013904223)>>>0)/4294967296);window.requestAnimationFrame=()=>0;</script>'''
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,s):p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(s.encode('utf-8'))
def once(s,a,b):
 if s.count(a)!=1:raise ValueError('anchor mismatch '+a[:80])
 return s.replace(a,b,1)
def derive(s):
 s=re.sub(r'/\* ---------- C · bot sprite layer ---------- \*/.*?(?=/\* ---------- controls)','',s,flags=re.S)
 s=re.sub(r'/\* =====================================================================\n   C · BOT SPRITE LAYER.*?(?=/\* A · static layer markup)','',s,flags=re.S)
 s=re.sub(r'      <!-- C · sprite layer[^\n]*\n      <div id="bot"[^\n]*\n','',s)
 s=re.sub(r'^.*#bot.*\n','',s,flags=re.M)
 s=re.sub(r'^.*\.card \.tail\{.*\n','',s,flags=re.M).replace('          <i class="tail"></i>\n','')
 s=once(s,'<b>小安</b>','<b>产品导览</b>')
 s=once(s,'你好，我是这里的导览员。接下来带你看看安路的四个 FPGA 系列。','欢迎了解安路科技及其四个 FPGA 产品系列。')
 s=once(s,'静态功耗低至 5 mA','静态电流低至 5 mA')
 s=s.replace('<br><i style="background:#E0603F"></i>C Sprite 层：小安身体与眼睛','')
 for pattern in [r'^const bot = new Bot.*\n',r'^  bot\.pageChange.*\n',r'^    if \(typing.i === 0\) bot\.speak\(true\);\n',r'^    else if \(Math.random\(\) < .3\) bot\.syllable\(\);\n',r'^  bot\.look.*\n',r'^  bot\.pointer.*\n',r'^  bot\.update.*\n',r'^bot\.at.*\n']:s=re.sub(pattern,'',s,flags=re.M)
 s=once(s,'if (want === typing.text.length) { bot.speak(false); typing = null; }','if (want === typing.text.length) typing = null;')
 s=once(s,' S.zx = h[0]; S.zy = h[1]; bot.wide.t = 1.15; bot.look(-.9, -.5, false); bot.at(.8, () => bot.wide.t = 1);',' S.zx = h[0]; S.zy = h[1];')
 s=once(s,'sp = bot.speaking ? 1.25 : .55','sp = typing ? 1.25 : .55')
 s=once(s,'if (analyser) { analyser.getByteFrequencyData(fft); bot.level = bars[1]; }','if (analyser) analyser.getByteFrequencyData(fft);')
 s=s.replace('S, bot, go','S, go').replace('captions and the bot','captions').replace('`say` = bot caption','`say` = OSD caption').replace("/* drag to pan while zoomed; pointer also feeds the bot's gaze */","/* drag to pan while zoomed */").replace('A static / B OSD / C sprite','A static / B OSD')
 if re.search(r'\bbot\b|\bBot\b|小安|class="tail"',s):raise ValueError('Bot dependency remains')
 assert s.count('data:image/')==10
 return s
class Browser:
 def __init__(self,chrome,out):self.chrome=chrome;self.out=out;self.records=[]
 def run(self,name,source,js='',screenshot=False):
  work=self.out/'assets/browser';work.mkdir(parents=True,exist_ok=True);p=work/(name+'.html');write(p,source.replace('<script>',PRE+'<script>',1).replace('</head>',CSS+'</head>').replace('</body>','<script>'+js+'</script></body>'))
  target=self.out/'reference'/(name+'.png');target.parent.mkdir(parents=True,exist_ok=True)
  cmd=[str(self.chrome),'--headless','--disable-gpu','--no-first-run','--no-default-browser-check','--hide-scrollbars','--force-device-scale-factor=1','--default-background-color=00000000','--user-data-dir='+str(work/'chrome_profile'),'--window-size=640,480','--virtual-time-budget=300']+(['--screenshot='+str(target)] if screenshot else ['--dump-dom'])+[p.as_uri()]
  start=time.monotonic();pr=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.PIPE);stdout,stderr=pr.communicate(timeout=75);(work/(name+'.stderr.log')).write_bytes(stderr);rec=dict(name=name,pid=pr.pid,exit_code=pr.returncode,wall_seconds=round(time.monotonic()-start,3),command=cmd,html_sha256=sha(p));self.records.append(rec)
  if pr.returncode:raise RuntimeError(rec)
  if screenshot:
   w,h,_=png(target);assert (w,h)==(640,480);rec.update(path=str(target),sha256=sha(target),width=w,height=h);return rec
  m=re.findall(r'<pre id="export">(.*?)</pre>',stdout.decode('utf-8'),re.S)
  if not m:raise ValueError('browser export absent '+name)
  result=json.loads(html.unescape(m[-1]));write(work/(name+'.json'),json.dumps(result,ensure_ascii=False,indent=2));return result
def atlas(glyphs):return ''.join(f'{sum(v<<(14-2*j) for j,v in enumerate(g["alpha"][i:i+8])):04x}\n' for g in glyphs for i in range(0,320,8)).encode('ascii')
def caption(browser,source,accepted,out):
 data=json.loads(accepted.read_text(encoding='utf-8'));oldatlas=atlas(data['glyphs']);assert hashlib.sha256(oldatlas).hexdigest()==ATLAS_SHA;baseline=copy.deepcopy(data)
 js=r'''const existing=EXISTING,glyphs=[],ids=new Map(existing.map((g,i)=>[g.font+'|'+g.ch,i]));
function gid(ch,font){let k=font+'|'+ch;if(!ids.has(k)){ids.set(k,existing.length+glyphs.length);glyphs.push({ch,font});}return ids.get(k);}
function run(selector,caption){const el=$(selector),text=el.textContent,cs=getComputedStyle(el),font=cs.fontWeight+' '+cs.fontSize+' '+cs.fontFamily,n=el.firstChild,out=[];for(let i=0;i<text.length;i++){let r=document.createRange();r.setStart(n,i);r.setEnd(n,i+1);let q=r.getBoundingClientRect();out.push({id:gid(text[i],font),x:Math.round(q.x),y:Math.round(q.y),w:Math.max(1,Math.round(q.width)),i,caption});}return out;}
let all=[];for(let dual=0;dual<2;dual++)for(let page=0;page<6;page++){S.page=page;S.cmp=!!dual;updateOSD(false);sayEl.textContent=dual?cmpLine():PAGES[page].say;all.push({page,dual,text:sayEl.textContent,home:(!dual&&page===0)?run('#say',true):[],header:run('.who b',false).concat(run('#cardWho',false))});}
const colors=Array.from({length:4},(_,code)=>[26,25,22].map((fg,c)=>Math.floor((fg*code+[237,233,226][c]*(3-code)+1)/3)));let cvs=document.createElement('canvas');cvs.width=16;cvs.height=20;let ctx=cvs.getContext('2d');for(let g of glyphs){ctx.clearRect(0,0,16,20);ctx.font=g.font;ctx.textBaseline='alphabetic';let dark=g.font.startsWith('400 12.5px ');if(dark){ctx.fillStyle='#ede9e2';ctx.fillRect(0,0,16,20);}ctx.fillStyle=dark?'#1a1916':'#fff';ctx.fillText(g.ch,0,13);let d=ctx.getImageData(0,0,16,20).data;g.alpha=Array.from({length:320},(_,i)=>{if(!dark)return Math.round(d[i*4+3]*3/255);let errors=colors.map(rgb=>rgb.reduce((s,v,c)=>s+Math.abs(v-d[i*4+c]),0));return errors.indexOf(Math.min(...errors));});}
document.body.innerHTML='<pre id="export">'+JSON.stringify({all,glyphs,errors:__errors})+'</pre>';'''.replace('EXISTING',json.dumps(data['glyphs'],ensure_ascii=True))
 exp=browser.run('caption_export',source,js);assert not exp['errors']
 # Production caption bands remain416/435; current installedChrome154 reports home415, a documented1px baseline difference.
 for layout in exp['all']:
  for run in layout['home']:run['y']=416 if run['y']<430 else 435
 data['glyphs']+=exp['glyphs'];assert len(data['glyphs'])<255
 for old,new in zip(data['all'],exp['all']):old['runs']=[r for r in old['runs'] if r['y']!=397 and not(old['page']==0 and not old['dual'] and r['caption'])]+new['header']+new['home'];old['text']=new['text']
 assert atlas(data['glyphs'])[:len(oldatlas)]==oldatlas
 for item in data['all']:
  if not(item['page']==0 and not item['dual']):assert [r for r in item['runs'] if r['caption']]==[r for r in baseline['all'][item['dual']*6+item['page']]['runs'] if r['caption']]
 asset=ROOT/'rtl/ext/html_assets';write(out/'assets/caption_layout_no_bot.json',json.dumps(data,ensure_ascii=False,indent=2));(asset/'html_glyph_coverage.hex').write_bytes(atlas(data['glyphs']))
 lines=['// Generated by scripts/no_bot_assets.py; accepted glyph IDs/coverage retained, new glyphs appended.','module html_caption_map(input [2:0] page_index,input dual_enable,input [9:0] x,y,input [6:0] typing_index,output reg [7:0] glyph_id,output reg [3:0] glyph_x,output reg [4:0] glyph_y,output reg [6:0] char_index,output reg is_caption,is_text,output reg [6:0] total_chars,output reg punctuation_pause);','always @* begin','glyph_id=0;glyph_x=0;glyph_y=0;char_index=0;is_caption=0;is_text=0;total_chars=0;punctuation_pause=0;','case ({dual_enable,page_index})'];words=[];blank=255<<10
 def band(runs,y,x0,width):
  vals=[blank]*width
  for r in runs:
   if r['y']!=y:continue
   lo=r['x'];hi=lo+min(16,r['w'])
   if not(x0<=lo<hi<=x0+width):raise ValueError(('run outside descriptor band',r,x0,width))
   for x in range(lo,hi):vals[x-x0]=(r['id']<<10)|((lo&15)<<6)|r['i']
  return vals
 for item in data['all']:
  key=item['dual']*8+item['page'];lines.append(f"4'd{key}: begin total_chars=7'd{len(item['text'])};");pauses=[i for i,c in enumerate(item['text']) if c in '，。；、']
  if pauses:lines.append('case(typing_index) '+','.join(f"7'd{i}" for i in pauses)+': punctuation_pause=1; default:punctuation_pause=0; endcase')
  for r in item['runs']:
   x,y,w,gid=r['x'],r['y'],min(16,r['w']),r['id'];lines.append(f"if(x>=10'd{x} && x<10'd{x+w} && y>=10'd{y} && y<10'd{y+20}) begin is_text=1;is_caption=1'b{int(r['caption'])};glyph_id=8'd{gid};glyph_x=x-10'd{x};glyph_y=y-10'd{y};char_index=7'd{r['i']};end")
  lines.append('end');words+=band(item['runs'],416,42,392)+band(item['runs'],435,42,168)
 lines+=['default:begin end','endcase','end','endmodule'];write(asset/'html_caption_map.v','\n'.join(lines)+'\n')
 for item in data['all'][:6]:words+=band(item['runs'],397,42,160)
 header=band(data['all'][6]['runs'],397,42,160);assert all(band(i['runs'],397,42,160)==header for i in data['all'][6:]);words+=header
 for item in data['all'][:6]:words += [b if b!=blank else a for a,b in zip(band(item['runs'],22,528,80),band(item['runs'],23,528,80))]
 words+=band(data['all'][0]['runs'],433,468,18);assert len(words)==8338
 proof=verify_columns(data,words);write(out/'assets/caption_columns_verification.json',json.dumps(proof,indent=2));write(asset/'html_caption_columns.hex',''.join(f'{v:05x}\n' for v in words))
 for name,width in [('html_glyph_coverage.hex',16),('html_caption_columns.hex',18)]:
  vals=[int(v,16) for v in (asset/name).read_text().split()];write(asset/(name+'.bin'),''.join(f'{v:0{width}b}\n' for v in vals));assert [int(v,2) for v in (asset/(name+'.bin')).read_text().split()]==vals
 return dict(glyphs=len(data['glyphs']),glyph_words=len(data['glyphs'])*40,column_words=len(words),existing_glyph_words_retained=len(oldatlas.splitlines()),appended_glyph_ids=list(range(229,len(data['glyphs']))),header_band=[42,397,160,20],header_max_x=max(r['x']+r['w'] for i in data['all'] for r in i['runs'] if r['y']==397),descriptor_bases=dict(body=0,dual_body=3360,header=6720,dual_header=7680,index=7840,audio=8320),paths={n:sha(asset/n) for n in ['html_caption_map.v','html_glyph_coverage.hex','html_glyph_coverage.hex.bin','html_caption_columns.hex','html_caption_columns.hex.bin']})
def verify_columns(data,words):
 atlas_words=[int(v,16) for v in atlas(data['glyphs']).split()]
 def ink(g,x,y):
  if g==255 or not(0<=x<16 and 0<=y<20):return 0
  return (atlas_words[g*40+y*2+x//8]>>(14-2*(x%8)))&3
 checks=0
 for idx,item in enumerate(data['all']):
  page=item['page'];dual=item['dual'];runs=item['runs']
  for y in list(range(22,43))+list(range(397,455)):
   for x in range(42,608):
    expected=None
    for r in runs:
     if r['x']<=x<r['x']+min(16,r['w']) and r['y']<=y<r['y']+20:expected=(r['id'],x-r['x'],y-r['y'],r['i'],int(r['caption']))
    addr=None;row=0;cap=0
    if 42<=x<202 and 397<=y<417:addr=6720+(6 if dual else page)*160+x-42;row=y-397
    elif 42<=x<434 and 416<=y<435:addr=idx*560+x-42;row=y-416;cap=1
    elif 42<=x<210 and 435<=y<455:addr=idx*560+392+x-42;row=y-435;cap=1
    elif 528<=x<608 and 22<=y<43:addr=7840+page*80+x-528;row=y-(23 if x>=584 else 22)
    elif 468<=x<486 and 433<=y<453:addr=8320+x-468;row=y-433
    got=None
    if addr is not None:
     v=words[addr];got=(v>>10,(x-((v>>6)&15))&15,row,v&63,cap)
    a=0 if expected is None else ink(*expected[:3]);b=0 if got is None else ink(*got[:3])
    if a!=b:raise ValueError(('column/map ink mismatch',idx,x,y,expected,got))
    if a and expected[4] and expected[3:]!=got[3:]:raise ValueError('typing ordinal mismatch')
    checks+=1
 return dict(state='PASS',coverage_pixels_checked=checks,scope='All12layouts expanded column ROM vs generated combinational map; exact2bit ink/reveal equivalence, including band overlaps.')
def font_version(path):
 d=path.read_bytes();base=struct.unpack_from('>I',d,12)[0] if d[:4]==b'ttcf' else 0
 for i in range(struct.unpack_from('>H',d,base+4)[0]):
  tag,_,off,size=struct.unpack_from('>4sIII',d,base+12+i*16)
  if tag==b'name':
   _,count,strings=struct.unpack_from('>HHH',d,off)
   for j in range(count):
    platform,encoding,language,name,length,pos=struct.unpack_from('>HHHHHH',d,off+6+j*12)
    if name==5 and platform==3:return d[off+strings+pos:off+strings+pos+length].decode('utf-16-be')
 return 'nameID5 unavailable'
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--out',type=Path,default=ROOT/'output/html_fidelity/no_bot');ap.add_argument('--chrome',type=Path,default=Path(r'C:\Program Files\Google\Chrome\Application\chrome.exe'));ap.add_argument('--accepted-layout',type=Path,default=Path(r'D:\FPGA\EG4S20-Multimedia-Signage\output\html_fidelity\bot_osd\caption_current_candidate\caption_layout_darkpaper.json'));a=ap.parse_args();out=a.out;out.mkdir(parents=True,exist_ok=True)
 original=ROOT/'output/html_fidelity/prototype/anlogic-exhibit.html';assert sha(original)==SOURCE_SHA;original_text=original.read_text(encoding='utf-8');source=derive(original_text);derived=out/'reference/anlogic-exhibit-no-bot.html';write(derived,source);browser=Browser(a.chrome,out)
 version=subprocess.run(['powershell','-NoProfile','-Command',f'(Get-Item -LiteralPath "{a.chrome}").VersionInfo.ProductVersion'],capture_output=True,text=True,check=True).stdout.strip();fontnames=['NotoSansSC-VF.ttf','NotoSerifSC-VF.ttf','segoeui.ttf','segoeuil.ttf','segoeuisl.ttf','segoeuib.ttf','arial.ttf','simsun.ttc'];fonts=[dict(path=str(Path(r'C:\Windows\Fonts')/n),sha256=sha(Path(r'C:\Windows\Fonts')/n),version=font_version(Path(r'C:\Windows\Fonts')/n)) for n in fontnames if (Path(r'C:\Windows\Fonts')/n).exists()]
 base="S.playing=false;S.acc=0;clock.t=0;scenes.forEach((s,i)=>s.className='scene '+PAGES[i].cls);"
 for page,name in enumerate(NAMES):browser.run('reference_'+name,source,base+f'S.page={page};scenes[{page}].classList.add("on");updateOSD(false);sayEl.textContent=PAGES[{page}].say;typing=null;vizStep(.1);',True)
 for name,js in [('dual','S.page=1;setCompare(true);sayEl.textContent=cmpLine();'),('zoom','S.page=1;scenes[1].classList.add("on");updateOSD(false);sayEl.textContent=PAGES[1].say;setZoom(true);')]:browser.run('reference_'+name,source,base+js+'typing=null;vizStep(.1);',True)
 runtime=r'''const tests=[];function check(name,ok){if(!ok)throw Error(name);tests.push(name);}setPlay(false);let now=last;function advance(seconds){for(let i=0;i<Math.ceil(seconds*60);i++){now+=1000/60;frame(now);}}check('no sprite DOM',!document.querySelector('#bot,.tail'));go(1,'next');advance(4.2);check('next and typing',S.page===1&&!S.busy&&sayEl.textContent===PAGES[1].say);go(0,'prev');advance(2);check('reverse',S.page===0&&!S.busy);go(5,'prev');advance(2);go(0,'next');advance(2);check('wrap',S.page===0);setCompare(true);check('paired panels',document.querySelectorAll('#compare .half').length===2);setZoom(true);S.z=3;applyZoom(false);check('zoom3',document.querySelector('#bmp').style.transform.includes('scale(3)'));S.z=1;applyZoom(false);check('zoom1',document.querySelector('#bmp').style.transform==='');setZoom(false);setCompare(false);setOSD(false);check('osd toggle',document.querySelector('#osd').classList.contains('off'));setOSD(true);S.interval=5.4;setPlay(true);advance(5.5);check('autoplay',S.page===1);setPlay(false);let paused=S.page;advance(7);check('pause',S.page===paused);go(2,'next');advance(.2);go(3,'next');advance(4);check('input during transition',S.page===3&&!S.busy&&sayEl.textContent===PAGES[3].say);vizStep(.1);check('viz independent finite bars',Array.from(bars).every(Number.isFinite)&&bars.some(v=>v>0));check('no JS errors',__errors.length===0);document.body.innerHTML='<pre id="export">'+JSON.stringify({state:'PASS',tests,errors:__errors,clock:clock.t})+'</pre>';'''
 runtime_result=browser.run('runtime_verify',source,runtime);cap=caption(browser,source,a.accepted_layout,out)
 static_paths=[ROOT/'output/html_fidelity/assets'/f'A_{i+1:02d}_{n}.bmp' for i,n in enumerate(NAMES)]+list((ROOT/'output/html_fidelity/assets').glob('panel_*.png'))+list((ROOT/'output/html_fidelity/layers').glob('scene_*.hfxl.bin'));removed=[]
 for name in ['bot_body_argb4444.hex','bot_body_argb4444.hex.bin','html_eye_radius.hex','html_eye_radius.hex.bin']:
  p=ROOT/'rtl/ext/html_assets'/name
  if p.exists():removed.append(dict(path=str(p.relative_to(ROOT)),sha256=sha(p),bytes=p.stat().st_size));p.unlink()
 previous=out/'assets/manifest.json'
 if not removed and previous.exists():removed=json.loads(previous.read_text(encoding='utf-8')).get('removed_bot_roms',[])
 photos=lambda text:json.loads(re.search(r'const ASSETS=(.*?);\n',text).group(1))
 original_photos=photos(original_text);derived_photos=photos(source);assert original_photos==derived_photos and len(original_photos)==9
 static_function=lambda text:text[text.index('function sceneHTML('):text.index('/* =====================================================================',text.index('function sceneHTML('))]
 assert static_function(original_text)==static_function(source)
 static_proof=dict(embedded_photos=9,embedded_resource_sha256={k:hashlib.sha256(v.encode()).hexdigest() for k,v in original_photos.items()},scene_and_compare_markup_sha256=hashlib.sha256(static_function(source).encode()).hexdigest(),state='PASS',scope='Exact9embeddedresources and sceneHTML/compareHTML function source remain identical; caption-only content edits cannot affect existing exportedOSD-hidden static inputs.')
 manifest=dict(state='REFERENCE_AND_CAPTION_GENERATED',static_source_proof=static_proof,source_html=dict(path=str(original),sha256=sha(original)),derived_html=dict(path=str(derived),sha256=sha(derived)),stage=[640,480],chrome=dict(path=str(a.chrome),version=version,sha256=sha(a.chrome)),font_files=fonts,font_policy='Original CSS font stacks; installed Noto Sans SC/Noto Serif SC + Segoe UI. Accepted229glyph atlas retained exactly; only new codepoints rasterized. No font installation/copy.',references=[r for r in browser.records if 'width' in r],browser_attempts=browser.records,runtime=runtime_result,caption=cap,static_media_assessment=dict(state='UNCHANGED',reason='Edits confined to removed sprite and dynamic OSD. Existing6sceneBMP +4independentpanelPNG and HFXL inputs excluded these layers; source inputs preserved, not rerendered.',files=[dict(path=str(p.relative_to(ROOT)),sha256=sha(p),bytes=p.stat().st_size) for p in static_paths]),removed_bot_roms=removed,scope='Browser reference and generated ROM assets; no actualRTL pixels, hardware or TD builds.',differences=['Full RGB browser antialiasing differs from FPGA RGB565/2bit glyph coverage and fixed-point animation.','New signature retains original10.5px font; header band160px; card remains24,386,486,72.','InstalledChrome154 home caption DOM baseline415 is normalized to existingFPGA band416, a1px difference; unchanged captions retain all accepted coordinates.','Browser visualizer illustrative; actualWAV FPGA visualizer verified separately.'])
 write(out/'assets/manifest.json',json.dumps(manifest,ensure_ascii=False,indent=2));print(json.dumps(dict(out=str(out),references=len(manifest['references']),runtime=runtime_result['state'],glyph_words=cap['glyph_words'],column_words=cap['column_words'],glyphs=cap['glyphs']),ensure_ascii=False))
if __name__=='__main__':
 start=time.monotonic();record=dict(started_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),pid=os.getpid(),python=sys.version,script_sha256=sha(Path(__file__)),argv=sys.argv,exit_code=None)
 path=ROOT/'output/html_fidelity/no_bot/assets/generator_attempts.json'
 try:
  main();record['exit_code']=0
 except BaseException:
  record.update(exit_code=1,exception=traceback.format_exc());raise
 finally:
  record['wall_seconds']=round(time.monotonic()-start,3)
  ledger=json.loads(path.read_text(encoding='utf-8')) if path.exists() else []
  ledger.append(record);write(path,json.dumps(ledger,ensure_ascii=False,indent=2))
