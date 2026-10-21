"""Exhaustive spring bounds and optional real-DUT width equivalence regression.
Targets may change arbitrarily eachframe, including all signed2 directions.
This overapproximates page-event timing. Shape remains16bits because syllable
input may override its damping. No motion-frame assets or external dependency.
"""
import argparse,hashlib,json,re,shutil,subprocess,time
from collections import deque
from pathlib import Path
SETS=[('gaze_x',[-288,-144,-112,-80,-64,0,64,80,144,160],3,1,10,8,8),('gaze_y',[-64,-48,-32,-16,0],3,1,8,5,5),('tilt',[-576,-288,-112,0,112,224,288],5,2,11,8,7),('hop',[-64,-16,0],4,2,8,5,4)]
BENCH='`timescale 1ns/1ps\nmodule spring_width_tb;\nreg clk=0;always #20 clk=~clk;reg rst=1;\nhtml_bot_overlay dut(.clk(clk),.rst(rst),.i_hs(1\'b0),.i_vs(1\'b1),.i_de(1\'b0),.i_rgb(24\'d0),.enable(1\'b1),.page_event(1\'b0),.page_direction(2\'sd1),.speaking(1\'b0),.syllable(1\'b0),.audio_level(8\'d0));html_bot_overlay_reference refdut(.clk(clk),.rst(rst),.i_hs(1\'b0),.i_vs(1\'b1),.i_de(1\'b0),.i_rgb(24\'d0),.enable(1\'b1),.page_event(1\'b0),.page_direction(2\'sd1),.speaking(1\'b0),.syllable(1\'b0),.audio_level(8\'d0));\nreg[49:0]vectors[0:1221489];reg[49:0]word_;reg signed[15:0]pos,vel,target;integer n,checks=0;\ninitial begin\n $readmemh("vectors.hex",vectors);repeat(3)@(negedge clk);rst=0;\n for(n=0;n<=1221489;n=n+1)begin\n @(negedge clk);word_=vectors[n];pos=word_[47:32];vel=word_[31:16];target=word_[15:0];dut.prev_vs=0;refdut.prev_vs=0;\n force dut.gx_target=target[9:0];force refdut.gx_target=target;\n force dut.gy_target=target[7:0];force refdut.gy_target=target;\n force dut.tilt_target=target[10:0];force refdut.tilt_target=target;\n force dut.hop_target=target[7:0];force refdut.hop_target=target;\n\n case(word_[49:48])\n 0:begin dut.gaze_x=pos;dut.gaze_vx=vel;refdut.gaze_x=pos;refdut.gaze_vx=vel;end\n 1:begin dut.gaze_y=pos;dut.gaze_vy=vel;refdut.gaze_y=pos;refdut.gaze_vy=vel;end\n 2:begin dut.tilt=pos;dut.tilt_v=vel;refdut.tilt=pos;refdut.tilt_v=vel;end\n 3:begin dut.hop=pos;dut.hop_v=vel;refdut.hop=pos;refdut.hop_v=vel;end\n endcase\n @(posedge clk);#1;\n case(word_[49:48])\n 0:if($signed(dut.gaze_x)!==$signed(refdut.gaze_x)||$signed(dut.gaze_vx)!==$signed(refdut.gaze_vx))$fatal(1,"gazeX difference n%0d",n);\n 1:if($signed(dut.gaze_y)!==$signed(refdut.gaze_y)||$signed(dut.gaze_vy)!==$signed(refdut.gaze_vy))$fatal(1,"gazeY difference n%0d",n);\n 2:if($signed(dut.tilt)!==$signed(refdut.tilt)||$signed(dut.tilt_v)!==$signed(refdut.tilt_v))$fatal(1,"tilt difference n%0d",n);\n 3:if($signed(dut.hop)!==$signed(refdut.hop)||$signed(dut.hop_v)!==$signed(refdut.hop_v))$fatal(1,"hop difference n%0d",n);\n endcase\n checks=checks+1;\n end\n $display("SPRING_WIDTH_RTL_EXHAUSTIVE_PASS %0d",checks);$finish;end\nendmodule\n'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def fits(v,b):return -(1<<(b-1))<=v<(1<<(b-1))
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]);ap.add_argument('--output-dir',required=True,type=Path);ap.add_argument('--run-rtl',action='store_true');a=ap.parse_args();out=a.output_dir;out.mkdir(parents=True,exist_ok=True);rows=[];bounds={}
 for channel,(name,targets,k,d,xb,vb,ab) in enumerate(SETS):
  seen={(0,0)};queue=deque(seen);lo=[0]*4;hi=[0]*4
  while queue:
   x,v=queue.popleft()
   for target in targets:
    diff=target-x;acc=(diff>>k)-(v>>d);nv=v+acc;nx=x+nv
    assert fits(diff,xb) and fits(acc,ab) and fits(nv,vb) and fits(nx,xb) and fits(x+v,xb)
    for i,value in enumerate([nx,nv,acc,diff]):lo[i]=min(lo[i],value);hi[i]=max(hi[i],value)
    rows.append((channel<<48)|((x&65535)<<32)|((v&65535)<<16)|(target&65535))
    if (nx,nv) not in seen:seen.add((nx,nv));queue.append((nx,nv))
  bounds[name]={'reachable_pairs':len(seen),'arbitrary_targets':targets,'position_bits':xb,'velocity_bits':vb,'acceleration_bits':ab,'ranges':dict(zip(['position','velocity','acceleration','target_minus_position'],zip(lo,hi)))}
 (out/'vectors.hex').write_bytes(''.join(f'{v:013x}\n' for v in rows).encode());report={'state':'BOUNDS_PASS','bounds':bounds,'rtl_transitions':len(rows),'vectors_sha256':sha(out/'vectors.hex'),'scope':'Allclosedreachable state/target transitions; signed2direction overapproximation; no shape narrowing'}
 if a.run_rtl:
  source=(a.root/'rtl/ext/html_bot_overlay.v').read_text(encoding='utf8');reference=source.replace('module html_bot_overlay #(','module html_bot_overlay_reference #(',1)
  names={'gaze_x','gaze_y','gaze_vx','gaze_vy','tilt','tilt_v','shape','shape_v','hop','hop_v','gx_target','gy_target','tilt_target','shape_target','hop_target','gx_acc','gy_acc','tilt_acc','shape_acc','hop_acc'}
  def widen(match):
   declared={v.strip() for v in match.group(1).split(',')}
   if declared&names:
    if not declared<=names:raise ValueError('mixed spring/non-spring declaration')
    return 'reg signed [15:0] '+match.group(1)+';'
   return match.group(0)
  reference=re.sub(r'reg\s+signed\s*\[\d+:0\]\s*([^;]+);',widen,reference)
  (out/'html_bot_overlay.v').write_bytes(source.encode());(out/'html_bot_overlay_reference.v').write_bytes(reference.encode());(out/'spring_width_tb.v').write_bytes(BENCH.encode())
  files=['html_bot_overlay.v','html_bot_overlay_reference.v','spring_width_tb.v','rtl/ext/html_eye_radius_rom.v','rtl/ext/html_rom16.v']
  for name in files[3:]+['rtl/ext/html_assets/bot_body_argb4444.hex','rtl/ext/html_assets/html_eye_radius.hex']:
   target=out/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(a.root/name,target)
  report['sources']={name:sha(out/name) for name in files};report['steps']=[]
  for label,cmd in [('compile',[r'C:\iverilog\bin\iverilog.exe','-g2012','-DHTML_SIM','-s','spring_width_tb','-o','sim.vvp']+files),('simulation',[r'C:\iverilog\bin\vvp.exe','sim.vvp'])]:
   started=time.time()
   with (out/(label+'.log')).open('wb') as log:
    child=subprocess.Popen(cmd,cwd=out,stdout=log,stderr=subprocess.STDOUT);step={'name':label,'pid':child.pid,'command':cmd};report['steps'].append(step)
    try:exit_code=child.wait(timeout=1200)
    except subprocess.TimeoutExpired:child.kill();child.wait();exit_code=-999
   step.update(exit_code=exit_code,wall_seconds=time.time()-started)
   if exit_code:report['state']='FAIL';break
  else:
   if 'SPRING_WIDTH_RTL_EXHAUSTIVE_PASS' not in (out/'simulation.log').read_text():raise ValueError('missing realDUT passmarker')
   report['state']='BOUNDS_RTL_EQUIVALENCE_PASS'
 (out/'verification.json').write_bytes(json.dumps(report,indent=2).encode());print(json.dumps(report,indent=2));return 0 if report['state']!='FAIL' else 1
if __name__=='__main__':raise SystemExit(main())
