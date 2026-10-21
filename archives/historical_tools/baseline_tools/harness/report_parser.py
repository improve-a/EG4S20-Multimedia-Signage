"""Conservative TD baseline parser; missing evidence can never become PASS."""
import argparse,collections,datetime,hashlib,json,pathlib,re

def text(p):return p.read_text(encoding='utf-8',errors='replace') if p.exists() else ''
def area(s):
 result={}
 for label,key in [('lut(?:6)?','LUT'),('reg','FF'),('slice\\*?','SLICE'),('eram','ERAM'),('bram','BRAM'),('dsp','DSP'),('pll','PLL'),('mipi_rx','MIPI_RX')]:
  m=re.search(r'^#'+label+r'\s+(\d+)(?:\s+out of\s+(\d+)\s+([\d.]+)%)?',s,re.M)
  if m:result[key]={'used':int(m[1]),'available':int(m[2]) if m[2] else None,'percent':float(m[3]) if m[3] else None}
 if 'FF' in result:
  m=re.search(r'^\s+#slice reg\s+(\d+)\s+out of\s+(\d+)\s+([\d.]+)%',s,re.M)
  if m:result['FF'].update(available=int(m[2]),percent=float(m[3]))
 return result

def timing(s):
 result={}
 for mode in ['Setup','Hold']:
  m=re.search(mode+r'\s*:\s*WNS\s+(-?[\d.]+)\s*(ps|ns)\s+TNS\s+(-?[\d.]+)\s*(ps|ns)\s+NUM_FEPS\s+(\d+)',s,re.I)
  if m:result[mode.lower()]={'wns_ns':float(m[1])/(1000 if m[2].lower()=='ps' else 1),'tns_ns':float(m[3])/(1000 if m[4].lower()=='ps' else 1),'failing_endpoints':int(m[5])}
 for mode,prefix in [('setup','S'),('hold','H')]:
  if mode not in result:
   m=re.search(prefix+r'WNS:\s*(-?[\d.]+)ns,\s*'+prefix+r'TNS:\s*(-?[\d.]+)ns',s)
   if m:result[mode]={'wns_ns':float(m[1]),'tns_ns':float(m[2]),'failing_endpoints':None}
 return result

def parse(base,run_id):
 job=base/'runs'/run_id;project=base/'work/design/td_project';flow=project/'hx4s20_basic_Runs'
 status=json.loads((job/'status.json').read_text());art=json.loads((job/'artifacts.json').read_text()) if (job/'artifacts.json').exists() else []
 indexed={p['path'].replace('\\','/'):p for p in art};started=datetime.datetime.fromisoformat(status['started_utc'])
 def fresh(p):
  entry=indexed.get(p.relative_to(base).as_posix())
  if not entry:return False
  if datetime.datetime.fromisoformat(entry['mtime_utc'])<started:return False
  return (hashlib.sha256(p.read_bytes()).hexdigest()==entry['sha256']) if p.exists() else False
 def recorded_fresh_db(p):
  e=indexed.get(p.relative_to(base).as_posix());return bool(e and e['bytes']>0 and datetime.datetime.fromisoformat(e['mtime_utc'])>=started)
 logs={'supervisor':text(job/'stdout.log')+'\n'+text(job/'stderr.log'),'SYN':text(flow/'syn_1/run.log'),'PNR':text(flow/'phy_1/run.log')}
 errors={k:re.findall(r'^.*\bERROR\s*:.*$',s,re.M) for k,s in logs.items()}
 critical={k:re.findall(r'^.*\bCRITICAL[- ]WARNING\s*:.*$',v,re.M) for k,v in logs.items()}
 warnings={k:dict(collections.Counter(re.findall(r'^([A-Z]+-\d+)\s+(?:CRITICAL[- ]WARNING|WARNING):',s,re.M))) for k,s in logs.items()}
 stages={'SIM':'NOT_RUN','SYN':'NOT_RUN','PNR':'NOT_RUN','STA':'NOT_VERIFIED','BITGEN':'NOT_RUN','HW':'NOT_VERIFIED'}
 for stage,folder,marker,db in [('SYN','syn_1','.opt_gate.end.f','hx4s20_basic_gate.db'),('PNR','phy_1','.opt_route.end.f','hx4s20_basic_pr.db')]:
  d=flow/folder
  if fresh(d/marker) and recorded_fresh_db(d/db) and not errors[stage]:stages[stage]='PASS'
  elif logs[stage]:stages[stage]='FAIL'
 d=flow/'phy_1';bits=[p for p in d.glob('*.bit') if p.stat().st_size>0 and fresh(p)]
 if bits and fresh(d/'.bitgen.end.f') and not errors['PNR']:stages['BITGEN']='PASS'
 elif (d/'.bitgen.begin.f').exists():stages['BITGEN']='FAIL'
 final=job/'final_timing.rpt';metrics=timing(text(final)) if fresh(final) else {}
 route_status=flow/'phy_1/route_flow.status'
 if fresh(route_status):
  detail=timing(text(route_status))
  for k,v in metrics.items():
   if k in detail and detail[k]['wns_ns']==v['wns_ns'] and detail[k]['tns_ns']==v['tns_ns']:v['failing_endpoints']=detail[k]['failing_endpoints']
 coverage_match=re.search(r'STA coverage\s*:\s*([\d.]+)%',text(final))
 checks={m[1]:{'count':int(m[2]),'severity':m[3]} for m in re.finditer(r'^\d+\. checking (.+?)\((\d+)\) \((HIGH|MEDIUM)\)',text(job/'check_timing.rpt'),re.M)}
 coverage={'checks':checks,'percent':float(coverage_match[1]) if coverage_match else None,'state':'NOT_VERIFIED','reason':'Requires review of check_timing, ignored paths, exceptions and IO/CDC intent'}
 if len(metrics)==2:
  if any(x['wns_ns']<0 or x['tns_ns']<0 or (x['failing_endpoints'] or 0)>0 for x in metrics.values()):stages['STA']='FAIL'
  else:stages['STA']='NOT_VERIFIED' # Positive slack alone is insufficient; no automatic coverage waiver.
 ar=job/'final_area.rpt';resource_source='final_area.rpt'
 if not fresh(ar):ar=flow/'syn_1/hx4s20_basic_gate.area';resource_source='synthesis_gate.area (not final)'
 resources=area(text(ar)) if fresh(ar) else {}
 identity={'tool':'Tang Dynasty v6.2.168116' in text(final),'device':bool(re.search(r'Device\s*:\s*EG4S20BG256',text(final))),'top':bool(re.search(r'Top Model\s*:\s*top',text(final))),'routed':bool(re.search(r'Confidence\s*:\s*Routed',text(final)))}
 build=all(stages[x]=='PASS' for x in ['SYN','PNR','BITGEN']) and not any(errors.values()) and status.get('flow_complete',False) and status.get('exit_code')==0 and all(identity.values())
 return {'schema_version':1,'run_id':run_id,'states':stages,'BUILD_PASS':build,'STA_PASS':stages['STA']=='PASS','HARDWARE_PASS':False,'job':status,'verified_identity':identity,'timing':metrics,'timing_coverage':coverage,'resources':resources,'resource_source':resource_source,'errors':errors,'critical_warnings':critical,'AUTOMATION_ACCEPTED':build and stages['STA']=='PASS' and not any(critical.values()),'warning_counts':warnings,'fresh_bitstreams':[str(p.relative_to(base)) for p in bits],'provenance':'File hashes and Windows UTC mtimes checked against artifacts.json; untransferred DBs validated only by manifest metadata'}

def main():
 ap=argparse.ArgumentParser();ap.add_argument('evidence');ap.add_argument('--run-id',required=True);a=ap.parse_args();base=pathlib.Path(a.evidence)
 result=parse(base,a.run_id);out=base/'result.json';out.write_text(json.dumps(result,ensure_ascii=False,indent=2));print(json.dumps(result,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
