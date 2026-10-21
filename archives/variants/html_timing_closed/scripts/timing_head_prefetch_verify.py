#!/usr/bin/env python3
"""Exact source-block FIFO head equivalence using the established Icarus runner."""
import datetime,hashlib,importlib.util,json,re,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def sha(b):return hashlib.sha256(b).hexdigest()
def extract(s,name):
 start=s.index(' reg[59:0]entries[0:7];reg[2:0]wp,rp;');end=s.index(' wire[20:0]head_addr',start)
 block=s[start:end]
 accept=re.search(r' wire front_accept=.*?;',s).group(0)
 write=re.search(r'    if\(mapped_valid\)begin entries\[wp\]<=.*?end',s).group(0)
 read=re.search(r'    if\(front_accept\)rp<=.*?;',s).group(0)
 count=re.search(r'    case\(\{mapped_valid,front_accept\}\).*?endcase',s).group(0)
 valid='queued!=0&&head_valid'if'head_valid'in block else'queued!=0'
 assert '.i_valid('+valid+'),.i_ready(frontend_ready)'in s
 fields='{mapped_addr,mapped_packed,mapped_half,mapped_black,source_x,source_y,logical_x,source_page,source_old,source_dual,source_repeat}'
 wrapper='module '+name+'(input mem_clk,rst,frame_latch,mapped_valid,frontend_ready,input[59:0]word_in,output valid,output[59:0]head_out,output accepted,output[3:0]count_out,output[2:0]wp_out,rp_out);\nreg[3:0]queued;wire[20:0]mapped_addr;wire mapped_packed,mapped_half,mapped_black,source_old,source_dual;wire[9:0]source_x,logical_x;wire[8:0]source_y;wire[2:0]source_page;wire[1:0]source_repeat;\nassign '+fields+'=word_in;\n'+block+accept+'\nassign valid='+valid+';assign head_out=head;assign accepted=front_accept;assign count_out=queued;assign wp_out=wp;assign rp_out=rp;\nalways@(posedge mem_clk)begin if(rst||frame_latch)begin queued<=0;wp<=0;rp<=0;end else begin\n'+write+'\n'+read+'\n'+count+'\nend end\nendmodule\n'
 return wrapper,dict(block_sha256=sha(block.encode()),accept=accept.strip(),write=write.strip(),read=read.strip(),count=count.strip())
def main():
 reference='d3716457c5438cd2c2e27ae6e61e3d8701f0bc21:rtl/ext/html_layer_memory_bridge.v';current=ROOT/'rtl/ext/html_layer_memory_bridge.v'
 out=ROOT/'output/html_fidelity/timing_fix'/('head_prefetch_'+datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ'));out.mkdir(parents=True)
 old=subprocess.run(['git','show',reference],cwd=ROOT,capture_output=True,check=True).stdout;new=current.read_bytes();a,ap=extract(old.decode(),'queue_before');b,bp=extract(new.decode(),'queue_after')
 payloads={'tests/timing_head_prefetch_tb.v':(ROOT/'tests/timing_head_prefetch_tb.v').read_bytes(),'generated/queue_extracted.v':(a+b).encode(),'snapshots/before.v':old,'snapshots/after.v':new}
 for n,v in payloads.items():p=out/n;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(v)
 plan={'tests':[dict(id='timing_head_prefetch',recipe_reference='Current exactqueuehead/accounting sourceblocks against preservedoriginalasyncqueue; independentorderedscoreboard',top='timing_head_prefetch_tb',sources=['tests/timing_head_prefetch_tb.v','generated/queue_extracted.v','snapshots/after.v'],inputs=list(payloads),parameters=[],timeout=30)],'source_sha256':{n:sha(v)for n,v in payloads.items()},'reference_git_object':reference,'extraction_before':ap,'extraction_after':bp,'entry_script_sha256':sha(Path(__file__).read_bytes()),'scope':'Cycleexactqueuehead/control equivalence only; no fullrenderer/encryptedIP/STA/hardware claim.'}
 (out/'plan.json').write_text(json.dumps(plan,indent=2));spec=importlib.util.spec_from_file_location('existing',ROOT/'scripts/run_regression.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);(out/'existing_runner.py').write_text(m.REMOTE_RUNNER)
 start=time.monotonic();cmd=[sys.executable,'-X','utf8',str(out/'existing_runner.py'),str(out)]
 with(out/'dispatch.log').open('w')as log:p=subprocess.Popen(cmd,cwd=out,stdout=log,stderr=subprocess.STDOUT);code=p.wait(timeout=120)
 summary=json.loads((out/'results/regression_summary.json').read_text())if(out/'results/regression_summary.json').exists()else{}
 summary.update(dispatch_pid=p.pid,dispatch_exit=code,dispatch_wall_seconds=time.monotonic()-start,command=cmd,production_unchanged=current.read_bytes()==new,scope=plan['scope'])
 (out/'verification.json').write_text(json.dumps(summary,indent=2));print((out/'dispatch.log').read_text());print('HEAD_PREFETCH_EVIDENCE='+str(out));return 0 if code==0 and summary.get('status')=='PASS'and summary['production_unchanged']else 1
if __name__=='__main__':raise SystemExit(main())
