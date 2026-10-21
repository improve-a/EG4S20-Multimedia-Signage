"""Private final evidence package. No build, hardware, or original-tree writes."""
import datetime,hashlib,json,pathlib,re,subprocess,zipfile
r=pathlib.Path(r'D:\FPGA\EG4S20-NoBot-Fix-20261020');repo=r/'repo';d=r/'delivery'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert not subprocess.check_output(['git','status','--short'],cwd=repo,text=True).strip()
id='media_status_001';b=r/'builds'/id;result=json.loads((d/'BUILD_RESULTS.json').read_text())[0]
assert result['states']['STA']=='FAIL' and result['HARDWARE_PASS'] is False
expected='6a99ffcc463f94c348452cded9fb18c982e09f1faf65a20aa4d95376e6e55166'
assert sha(d/(id+'.bit'))==sha(b/'work/design/td_project/hx4s20_basic_Runs/phy_1/hx4s20_basic.bit')==expected
assert sha(b/'work/design/user_source/constraints_source/timing.sdc')=='93d101bdc89fa6ddb75ba17edb7c42bc04dd3eeecade0a649bfafa0a966e4051'
def normalized(p):
 with zipfile.ZipFile(p) as z:
  return {n:re.sub(rb'D:/FPGA/[^"\r\n]*?/work/design/',b'@DESIGN@/',z.read(n).replace(b'\r\n',b'\n')) for n in z.namelist() if n.startswith('work/design/')}
old=normalized(pathlib.Path(r'D:\FPGA\EG4S20-NoBot-RCA-20261020\delivery\rca_locked_only_001_source.zip'))
new=normalized(d/(id+'_source.zip'))
changes=[n for n in sorted(old.keys()|new.keys()) if old.get(n)!=new.get(n)]
assert changes==['work/design/user_source/hdl_source/ext/hdmi_probe.v','work/design/user_source/hdl_source/ext/legacy_exhibit_media.v','work/design/user_source/hdl_source/top_tf_hdmi_audio.v'],changes
for name in ('FINAL_REPORT.md','STATUS_GUIDE.md','DO_NOT_DEPLOY.md'):
 (d/name).write_bytes((repo/'docs/fix_round'/name).read_bytes())
archive=d/'unattended_evidence_20261021.zip'
with zipfile.ZipFile(archive,'a',zipfile.ZIP_DEFLATED) as z:
 for directory in (r/'audit',r/'reviewed_reset_sta',r/'reviewed_reset_sta_002',r/'reviewed_reset_sta_003',r/'netcheck'/id):
  for p in directory.rglob('*'):
   if p.is_file() and p.suffix in ('.rpt','.json','.tcl','.sdc','.log'):
    name='windows/'+p.relative_to(r).as_posix()
    assert name not in z.namelist(),name
    z.write(p,name)
# Hash only after ZIP central directory has been closed.
files=[{'name':p.name,'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(d.iterdir()) if p.is_file() and p.name not in ('FINAL_MANIFEST.json','SHA256SUMS.txt')]
m={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'root_cause':'ROOT_CAUSE_UNRESOLVED','functional_fix':'NOT_IMPLEMENTED_NO_CONFIRMED_CAUSE','scoped_tests':'OFFLINE_VERIFIED','SYN':'PASS','PNR':'PASS','BITGEN':'PASS','STA':'FAIL','hardware':'HARDWARE_NOT_TESTED','release':'DO_NOT_DEPLOY','qualified_new_bitstream':None,'source_commit':result['source_commit'],'delivery_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip(),'branch':'codex/nobot-fix-20261020','worker_model':'deepseek/deepseek-flash (DeepSeek V4.1 Flash 1017)','new_full_builds':1,'new_diagnostic_designs':1,'production_sdc_changed':False,'source_changes':changes,'bit_sha256':expected,'raw_timing':result['timing'],'files':files}
with (d/'FINAL_MANIFEST.json').open('x',encoding='utf-8') as f:json.dump(m,f,indent=2)
with (d/'SHA256SUMS.txt').open('x',encoding='utf-8') as f:
 for p in sorted(d.iterdir()):
  if p.is_file() and p.name!='SHA256SUMS.txt':f.write(sha(p)+'  '+p.name+'\n')
assert all(sha(d/f['name'])==f['sha256'] for f in m['files'])
print(json.dumps(m,indent=2))
