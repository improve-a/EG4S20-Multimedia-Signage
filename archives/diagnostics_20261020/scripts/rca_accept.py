"""Root acceptance evidence: source-only delta, pin invariance, scoped STA."""
import hashlib,json,pathlib,re,sys,zipfile
r=pathlib.Path(sys.argv[1]);ids=['rca_no_locked_003','rca_locked_only_001']
base=r/'baseline_copies/hdmi_probe_001';brun=base/'runs/hdmi_probe_001'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def io_rows(p):
 return [re.sub(r'\s+',' ',x.strip()) for x in p.read_text().splitlines() if re.match(r'^\s*\S+\s+(INPUT|OUTPUT|INOUT)\s+\S+',x)]
def critical(p):return sorted(set(re.findall(r'^([A-Z]+-\d+) CRITICAL-WARNING:',p.read_text(errors='replace'),re.M)))
def normalized_zip(p):
 with zipfile.ZipFile(p) as z:
  return {n:re.sub(rb'D:/FPGA/[^"\r\n]*?/work/design/',b'@DESIGN@/',z.read(n).replace(b'\r\n',b'\n')) for n in z.namelist() if n.startswith('work/design/')}
original=normalized_zip(r/'baseline_copies/hdmi_probe_001_source.zip')
results=[]
for id in ids:
 b=r/'builds'/id;run=b/'runs'/id
 text=(run/'final_timing.rpt').read_text(errors='replace')
 init=(r/'netcheck'/id/'init_timing.rpt').read_text(errors='replace')
 groups=[int(x) for x in re.findall(r'(\d+) Viol Endpoints',text)]
 igroups=[int(x) for x in re.findall(r'(\d+) Viol Endpoints',init)]
 assert groups and igroups and max(groups)==max(igroups)==0
 assert 'Check Corner        : Both (Slow and Fast)' in text
 rows=io_rows(run/'final_area.rpt');assert rows==io_rows(brun/'final_area.rpt')
 current=normalized_zip(r/'delivery'/(id+'_source.zip'))
 changed=[n for n in sorted(original.keys()|current.keys()) if original.get(n)!=current.get(n)]
 assert changed==['work/design/user_source/hdl_source/top_tf_hdmi_audio.v'],changed
 nc=json.loads((r/'netcheck'/id/'receipt.json').read_text())
 assert nc['state']=='SCOPED_PASS'
 receipt=json.loads((b/'rca_checks/receipt.json').read_text())
 assert receipt['state']=='SCOPED_PASS'
 c=critical(run/'stdout.log');bc=critical(brun/'stdout.log')
 result={'run_id':id,'OFFLINE_BUILD':'PASS','RTL_CHECKS':'SCOPED_PASS','STA':'PASS_WITH_INHERITED_MODEL_AND_INTERFACE_LIMITATIONS','HARDWARE':'NOT_TESTED','normal_group_statistics':len(groups),'init_group_statistics':len(igroups),'violating_endpoints_in_group_summaries':0,'IO_report_rows_identical_to_probe':len(rows),'normalized_source_changes':changed,'critical_warning_codes':c,'baseline_critical_warning_codes':bc,'new_critical_warning_codes':sorted(set(c)-set(bc)),'netcheck':nc,'BRAM32K':int(re.search(r'^#bram32k\s+(\d+)',(run/'final_area.rpt').read_text(),re.M)[1]),'scope':'No new production exceptions; normal/init slow+fast Max/Min reports have zero violating endpoints. TMDS/external I/O/CDC/startup remain outside full signoff. Generic parser STA=NOT_VERIFIED is retained, not rewritten.'}
 results.append(result)
 print(json.dumps({k:v for k,v in result.items() if k!='netcheck'},indent=2))
(r/'delivery/ROOT_ACCEPTANCE.json').write_text(json.dumps(results,indent=2))
