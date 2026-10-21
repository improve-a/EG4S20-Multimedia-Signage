"""Fresh Root spot-check of two DS media testcases; fail on log errors too."""
import hashlib,json,pathlib,subprocess,time
r=pathlib.Path(r'D:\FPGA\EG4S20-NoBot-Fix-20261020');h=pathlib.Path(r'D:\FPGA\EG4S20-NoBot-RCA-20261020\builds\rca_locked_only_001\work\design\user_source\hdl_source')
cases=[('commit7','tb_commit_chain',['-Ptb_commit_chain.PHASE_NS=7'],[h/'display_commit.v',h/'ext/video_transition.v'],'SUMMARY PHASE_NS=7 errors=0'),('audio200','tb_audio_fifo_seq',['-Ptb_audio_fifo_seq.AUDIO_REL_NS=200'],[h/'ext/audio_async_fifo.v'],'SUMMARY AUDIO_REL_NS=200 errors=0')]
receipts=[]
for tag,top,params,rtl,expected in cases:
 tb=r/'media/tb'/(top+'.v');out=r/'root_tests'/('review_'+tag+'.vvp')
 commands=[[r'C:\iverilog\bin\iverilog.exe','-g2012','-s',top,*params,'-o',str(out),str(tb),*map(str,rtl)],[r'C:\iverilog\bin\vvp.exe',str(out)]]
 steps=[]
 for command in commands:
  t=time.monotonic();p=subprocess.run(command,capture_output=True,timeout=30)
  steps.append({'command':command,'exit':p.returncode,'seconds':time.monotonic()-t,'stdout':p.stdout.decode(errors='replace'),'stderr':p.stderr.decode(errors='replace')})
  assert p.returncode==0,steps
 assert expected in steps[-1]['stdout'] and 'FAIL' not in steps[-1]['stdout'],steps
 receipts.append({'tag':tag,'steps':steps,'hashes':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in [tb,*rtl]}})
(r/'root_tests/review_media_receipt.json').write_text(json.dumps(receipts,indent=2))
print(json.dumps(receipts,indent=2))
