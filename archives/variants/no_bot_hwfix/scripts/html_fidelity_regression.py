#!/usr/bin/env python3
"""Fresh Windows-primary preservation regressions, existing runner/recipes only.
Additional authored tests cover actual HFXC gap and real-WAV dynamic gain/mute.
"""
import argparse,datetime,hashlib,importlib.util,json,os,struct,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def sha(b):return hashlib.sha256(b).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument("--only",action="append",default=[],help="Run only a named case; repeat to select multiple cases");args=ap.parse_args()
 spec=importlib.util.spec_from_file_location('existing_regression',ROOT/'scripts/run_regression.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
 stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ');out=ROOT/'output/html_fidelity/regression'/stamp;out.mkdir(parents=True,exist_ok=False)
 recipes=json.loads((ROOT/'output/venue_emergency_ui/evidence/regression_recipes.json').read_text(encoding='utf-8'))['recipes'];cases=[];payloads={}
 def add(key,id=None,parameters=None,extra_inputs=None,sources=None):
  rec=recipes[key];inp=list(rec['inputs']);src=list(rec['sources']);ident=id or rec['top']
  if extra_inputs:inp+=extra_inputs
  if sources:src=sources
  for n in inp:
   if n not in payloads:payloads[n]=(ROOT/n).read_bytes()
  case=dict(id=ident,recipe_reference=key,top=rec['top'],sources=src,inputs=inp,parameters=rec['parameters'] if parameters is None else parameters,timeout=rec['timeout']);cases.append(case);return case
 for key in m.RECIPES:add(key,id=recipes[key]['top']+('_case3' if key=='scale_case3_01' else ''))
 for i in [0,1,2,4,5,6,7]:
  rec=recipes['scale_case3_01'];inp=[n.replace('_3.hex',f'_{i}.hex') for n in rec['inputs']]
  for n in inp:payloads[n]=(ROOT/n).read_bytes()
  cases.append(dict(id=f'scale_case{i}',recipe_reference='scale_case3_01 with original CASE vector',top='scale_tb',sources=rec['sources'],inputs=inp,parameters=[f'scale_tb.CASE={i}'],timeout=600))
 # True six-to-eight catalog bounds, both decoder configurations.
 for scale in [0,1]:
  inp=['tests/unified_storage_tb.v','rtl/SD/bmp_read.v','rtl/ext/bmp_scale.v']
  for n in inp:payloads[n]=(ROOT/n).read_bytes()
  cases.append(dict(id=f'catalog_six_eight_scale{scale}',recipe_reference='existing unified_storage_tb',top='unified_storage_tb',sources=inp,inputs=inp,parameters=[f'unified_storage_tb.ENABLE_SCALE={scale}'],timeout=600))
 # Actual extended product BMP, including full metadata gap, independent clean goldens.
 bmp=(ROOT/'output/html_fidelity/media/UI02.BMP').read_bytes();off=struct.unpack_from('<I',bmp,10)[0];pixel_end=off+921600
 assert off==250368 and struct.unpack_from('<I',bmp,2)[0]==len(bmp) and bmp[80:84]==b'HFXL'
 scene_offset,payload_bytes=struct.unpack_from('<II',bmp,88);assert scene_offset>=pixel_end and scene_offset+payload_bytes==len(bmp)
 # Preserve the actual formal header, including its full declared HFXL tail.
 # The BMP decoder consumes only the prefix through the final native pixel;
 # scene transport is independently checked across every trailer byte.
 payloads['tests/html_hfxc_card.hex']=''.join(f'{v:02x}\n' for v in bmp[:pixel_end]).encode();gold=bmp[off:pixel_end];assert len(gold)==921600
 payloads['tests/html_hfxc_golden.hex']=''.join(f'{gold[i+2]:02x}{gold[i+1]:02x}{gold[i]:02x}\n' for i in range(0,len(gold),3)).encode()
 inp=['tests/html_hfxc_bmp_tb.v','rtl/SD/bmp_read.v','rtl/ext/bmp_scale.v','rtl/ext/html_resource_locator.v','tests/html_hfxc_card.hex','tests/html_hfxc_golden.hex']
 for n in inp:
  if n not in payloads:payloads[n]=(ROOT/n).read_bytes()
 cases.append(dict(id='real_hfxl_hfxc_native_bmp',recipe_reference='actual formal HFXL header/HFXC gap/native pixels; explicit HFXL decoder enabled',top='html_hfxc_bmp_tb',sources=inp[:4],inputs=inp,parameters=['html_hfxc_bmp_tb.ENABLE_HFXL=1'],timeout=600))
 cases.append(dict(id='real_hfxl_rejected_without_optin',recipe_reference='same formal header must retain strict ordinary-BMP tail limit without HFXL opt-in',top='html_hfxc_bmp_tb',sources=inp[:4],inputs=inp,parameters=['html_hfxc_bmp_tb.ENABLE_HFXL=0','html_hfxc_bmp_tb.EXPECT_REJECT=1'],timeout=60))
 # Existing real-WAV media variants and failure boundaries.
 base=recipes['audio_media_pipeline_boundary_001'];audio_sources=base['sources']
 for ident,params in [('real_wav_stereo',[]),('real_wav_mono',['audio_media_tb.MONO=1']),('real_wav_pending_pause',['audio_media_tb.REQUEST_PAUSE=1']),('real_wav_no_wav',['audio_media_tb.FAULT=1']),('real_wav_short_sector',['audio_media_tb.FAULT=2']),('real_wav_sd_error',['audio_media_tb.FAULT=3'])]:
  extra=['tests/audio_card.hex','tests/audio_card_mono.hex'];add('audio_media_pipeline_boundary_001',id=ident,parameters=params,extra_inputs=extra)
 # Golden PCM is parsed from actual RIFF chunks rather than duplicating RTL formulas.
 card=bytes(int(v,16) for v in (ROOT/'tests/audio_card.hex').read_text(encoding='ascii').split());start=card.index(b'RIFF');pos=start+12;pcm=None
 while pos+8<=len(card):
  name=card[pos:pos+4];size=struct.unpack_from('<I',card,pos+4)[0]
  if name==b'data':pcm=card[pos+8:pos+8+size];break
  pos+=8+size+(size&1)
 assert pcm is not None and len(pcm)==1200
 payloads['tests/html_real_wav_pcm.hex']=''.join(f'{struct.unpack_from("<H",pcm,i)[0]:04x}{struct.unpack_from("<H",pcm,i+2)[0]:04x}\n' for i in range(0,len(pcm),4)).encode()
 inp=[n.replace('tests/audio_media_tb.v','tests/html_real_wav_volume_tb.v') for n in base['inputs'] if not n.endswith('audio_card_boundary.hex')]+['tests/audio_card.hex','tests/html_real_wav_pcm.hex']
 src=[n.replace('tests/audio_media_tb.v','tests/html_real_wav_volume_tb.v') for n in audio_sources]
 for n in inp:
  if n not in payloads:payloads[n]=(ROOT/n).read_bytes()
 cases.append(dict(id='real_wav_dynamic_volume_mute_eof',recipe_reference='authored actual-WAV scoreboard at FIFO pops and audio output',top='html_real_wav_volume_tb',sources=src,inputs=inp,parameters=[],timeout=600))
 if args.only:
  known={c["id"] for c in cases};unknown=set(args.only)-known
  if unknown:ap.error("Unknown cases: "+", ".join(sorted(unknown)))
  cases=[c for c in cases if c["id"] in args.only];needed={n for c in cases for n in c["inputs"]};payloads={n:b for n,b in payloads.items() if n in needed}
 for n,b in payloads.items():
  f=out/n;f.parent.mkdir(parents=True,exist_ok=True);f.write_bytes(b)
 plan=dict(tests=cases,source_sha256={n:sha(b)for n,b in sorted(payloads.items())},entry_script_sha256=sha(Path(__file__).read_bytes()),baseline_entry_sha256=sha((ROOT/'scripts/run_regression.py').read_bytes()),ui02_bmp_sha256=sha(bmp),real_wav_pcm_sha256=sha(pcm),recipe_policy='Current Windows primary sources. Existing recipes are command references only; no historical reports reused.')
 (out/'plan.json').write_text(json.dumps(plan,indent=2),encoding='utf8');(out/'remote_runner.py').write_text(m.REMOTE_RUNNER,encoding='utf8')
 start=time.monotonic();cmd=[sys.executable,'-X','utf8',str(out/'remote_runner.py'),str(out)];p=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf8',cwd=out)
 with (out/'dispatch.log').open('w',encoding='utf8') as log:
  for line in p.stdout:print(line,end='',flush=True);log.write(line);log.flush()
 code=p.wait();(out/'dispatch.json').write_text(json.dumps(dict(pid=p.pid,exit=code,wall_seconds=time.monotonic()-start,command=cmd),indent=2),encoding='utf8');print('REGRESSION_EVIDENCE='+str(out),flush=True)
 summary=json.loads((out/'results/regression_summary.json').read_text(encoding='utf8')) if (out/'results/regression_summary.json').exists() else {};return 0 if code==0 and summary.get('status')=='PASS' else 1
if __name__=='__main__':raise SystemExit(main())
