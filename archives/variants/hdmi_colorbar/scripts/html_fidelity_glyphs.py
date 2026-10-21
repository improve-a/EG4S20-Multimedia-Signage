#!/usr/bin/env python3
"""Extract proportional DOM caption layout and 2-bit canvas glyph coverage ROM."""
import argparse,html,json,re,subprocess
from pathlib import Path

def main():
 p=argparse.ArgumentParser();p.add_argument('--temp',type=Path,required=True);p.add_argument('--rtl',type=Path,required=True);a=p.parse_args(); t=a.temp
 src=(t/'local_temp/reference_home.html').read_text(encoding='utf-8')
 js=r'''<script>
const all=[],glyphs=[],ids=new Map();
function gid(ch,font){let k=font+'|'+ch;if(!ids.has(k)){ids.set(k,glyphs.length);glyphs.push({ch,font});}return ids.get(k);}
function run(selector,caption){const el=$(selector),text=el.textContent,cs=getComputedStyle(el),font=cs.fontWeight+' '+cs.fontSize+' '+cs.fontFamily;
 const n=el.firstChild;if(!n||n.nodeType!==3)return[];
 let out=[];for(let i=0;i<text.length;i++){let r=document.createRange();r.setStart(n,i);r.setEnd(n,i+1);let q=r.getBoundingClientRect();out.push({id:gid(text[i],font),x:Math.round(q.x),y:Math.round(q.y),w:Math.max(1,Math.round(q.width)),i,caption});}return out;}
for(let dual=0;dual<2;dual++)for(let page=0;page<6;page++){
 S.page=page;S.cmp=!!dual;updateOSD(false);$('#vizTag').textContent='音频';sayEl.textContent=dual?cmpLine():PAGES[page].say;
 let runs=run('#say',true).concat(run('.who b',false),run('#cardWho',false),run('#osdN',false),run('#osdT',false),run('#vizTag',false));
 all.push({page,dual,text:sayEl.textContent,runs});
}
let cvs=document.createElement('canvas');cvs.width=16;cvs.height=20;let ctx=cvs.getContext('2d');
for(let g of glyphs){ctx.clearRect(0,0,16,20);ctx.fillStyle='#fff';ctx.font=g.font;ctx.textBaseline='alphabetic';ctx.fillText(g.ch,0,13);let d=ctx.getImageData(0,0,16,20).data;g.alpha=Array.from({length:320},(_,i)=>Math.round(d[i*4+3]*3/255));}
document.body.innerHTML='<pre id="export">'+JSON.stringify({all,glyphs})+'</pre>';
</script>'''
 f=t/'glyph_export.html';f.write_text(src.replace('</body>',js+'</body>'))
 cmd=['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome','--headless','--disable-gpu','--no-first-run',f'--user-data-dir={t/"chrome_glyph"}','--dump-dom',f.as_uri()]
 r=subprocess.run(cmd,capture_output=True,text=True,check=True);m=re.search(r'<pre id="export">(.*?)</pre>',r.stdout,re.S);assert m
 data=json.loads(html.unescape(m[1]));assert len(data['glyphs'])<=256,len(data['glyphs'])
 (t/'caption_layout.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
 words=[]
 for g in data['glyphs']:
  for i in range(0,320,8):
   v=0
   for a2 in g['alpha'][i:i+8]:v=(v<<2)|a2
   words.append(f'{v:04x}')
 (t/'html_glyph_coverage.hex').write_text('\n'.join(words)+'\n')
 lines=['// Generated from prototype DOM, source font stack, 2bit coverage.','module html_caption_map(input [2:0] page_index,input dual_enable,input [9:0] x,y,input [6:0] typing_index,output reg [7:0] glyph_id,output reg [3:0] glyph_x,output reg [4:0] glyph_y,output reg [6:0] char_index,output reg is_caption,is_text,output reg [6:0] total_chars,output reg punctuation_pause);','always @* begin','glyph_id=0;glyph_x=0;glyph_y=0;char_index=0;is_caption=0;is_text=0;total_chars=0;punctuation_pause=0;','case ({dual_enable,page_index})']
 for layout in data['all']:
  key=layout['dual']*8+layout['page'];lines.append(f"4'd{key}: begin total_chars=7'd{len(layout['text'])};")
  pauses=[i for i,c in enumerate(layout['text']) if c in '，。；、']
  if pauses:lines.append('case(typing_index) '+','.join(f"7'd{i}" for i in pauses)+': punctuation_pause=1; default:punctuation_pause=0; endcase')
  # Nonoverlapping x cells: range width clips glyph edge under narrow ASCII cells.
  for n,rn in enumerate(layout['runs']):
   # DOM range has ink line box y417; atlas baseline13 matches this box.
   xx,yy,w=rn['x'],rn['y'],min(16,rn['w']);gid=rn['id']
   if not(0<=xx<640 and 0<=yy<480):continue
   lines.append(f"if(x>=10'd{xx} && x<10'd{xx+w} && y>=10'd{yy} && y<10'd{yy+20}) begin is_text=1;is_caption=1'b{int(rn['caption'])};glyph_id=8'd{gid};glyph_x=x-10'd{xx};glyph_y=y-10'd{yy};char_index=7'd{rn['i']};end")
  lines.append('end')
 lines+=['default:begin end','endcase','end','endmodule']
 a.rtl.parent.mkdir(parents=True,exist_ok=True);a.rtl.write_text('\n'.join(lines)+'\n')
 print(json.dumps({'glyph_count':len(data['glyphs']),'atlas_bits':len(words)*16,'body_bits':10400*16,'total_texture_bits':len(words)*16+10400*16,'layouts':len(data['all'])}))
if __name__=='__main__':main()
