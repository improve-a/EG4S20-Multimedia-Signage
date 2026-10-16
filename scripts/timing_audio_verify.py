#!/usr/bin/env python3
"""Replay existing audio/arbiter tests from a fresh Windows source snapshot."""
import argparse,datetime,hashlib,importlib.util,json,os,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def sha(b):return hashlib.sha256(b).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--select',nargs='+');args=ap.parse_args()
 stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
 out=ROOT/'output/html_fidelity/timing_fix'/('audio_'+stamp);out.mkdir(parents=True,exist_ok=False)
 spec=importlib.util.spec_from_file_location('existing_runner',ROOT/'scripts/run_regression.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
 recipes=json.loads((ROOT/'output/venue_emergency_ui/evidence/regression_recipes.json').read_text())['recipes']
 payloads={};cases=[]
 for key in ['audio_fifo_bram_001','audio_player_bram_001','audio_media_pipeline_boundary_001','audio_arbiter_pipeline_001','audio_visual_bram_001','video_audio_integration_004']:
  q=recipes[key]
  for n in q['inputs']:payloads[n]=(ROOT/n).read_bytes()
  cases.append(dict(id=key,recipe_reference=key,top=q['top'],sources=q['sources'],inputs=list(q['inputs']),parameters=q['parameters'],timeout=q['timeout']))
 base=recipes['audio_media_pipeline_boundary_001'];inputs=list(base['inputs'])
 for name in ['audio_card.hex','audio_card_mono.hex','audio_card_short.hex']:
  n='tests/'+name;payloads[n]=(ROOT/n).read_bytes();inputs.append(n)
 for name,params in [('stereo',[]),('mono',['MONO=1']),('short',['SHORT=1','MONO=1']),('pending_pause',['REQUEST_PAUSE=1']),('no_wav',['FAULT=1']),('truncated',['FAULT=2']),('sd_error',['FAULT=3'])]:
  cases.append(dict(id='audio_media_'+name,recipe_reference='existing audio_media_tb modes',top=base['top'],sources=base['sources'],inputs=inputs,parameters=['audio_media_tb.'+p for p in params],timeout=600))
 if args.select:
  assert set(args.select)<=set(c['id']for c in cases),'Unknown selected case'
  cases=[c for c in cases if c['id']in args.select]
  needed={n for c in cases for n in c['inputs']};payloads={n:b for n,b in payloads.items()if n in needed}
 for n,b in payloads.items():
  p=out/n;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b)
 plan=dict(tests=cases,source_sha256={n:sha(b)for n,b in payloads.items()},entry_script_sha256=sha(Path(__file__).read_bytes()),existing_runner_sha256=sha((ROOT/'scripts/run_regression.py').read_bytes()),scope='Actual audio RTL and shared arbiter; existing ideal byte transport, PCM identity/cadence, FIFO, visualizer and video/audio control. No encrypted HDMI/hardware validation.')
 (out/'plan.json').write_text(json.dumps(plan,indent=2));(out/'existing_runner.py').write_text(m.REMOTE_RUNNER)
 start=time.monotonic();cmd=[sys.executable,'-X','utf8',str(out/'existing_runner.py'),str(out)]
 with (out/'dispatch.log').open('w',encoding='utf-8') as log:
  p=subprocess.Popen(cmd,cwd=out,stdout=log,stderr=subprocess.STDOUT);code=p.wait(timeout=7800)
 summary=json.loads((out/'results/regression_summary.json').read_text()) if(out/'results/regression_summary.json').exists()else{}
 summary.update(dispatch_pid=p.pid,dispatch_exit=code,dispatch_wall_seconds=time.monotonic()-start,dispatch_command=cmd,driver_pid=os.getpid(),scope=plan['scope'],live_source_unchanged=all(sha((ROOT/n).read_bytes())==v for n,v in plan['source_sha256'].items()))
 (out/'verification.json').write_text(json.dumps(summary,indent=2));print((out/'dispatch.log').read_text());print('EVIDENCE='+str(out));return int(code!=0 or summary.get('status')!='PASS' or not summary['live_source_unchanged'])
if __name__=='__main__':raise SystemExit(main())
