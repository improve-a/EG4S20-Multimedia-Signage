"""One controlled infer_add toggle; no HDL/constraint/asset edits, no retries."""
import argparse,datetime,difflib,hashlib,json,pathlib,re,subprocess,sys,zipfile
R=pathlib.Path(__file__).resolve().parents[1]
C=json.loads((R/'experiments/bot_probe_infer_add_off.json').read_text())
ID=C['run_id'];D=R/'output/html_fidelity/builds'/ID
sha=lambda b:hashlib.sha256(b).hexdigest()
def main():
 a=argparse.ArgumentParser();a.add_argument('action',choices=['prepare','run']);x=a.parse_args()
 if x.action=='run':
  assert not (D/'runs'/ID).exists(),'Single attempt only'
  import bot_probe_build
  bot_probe_build.ID=ID;bot_probe_build.D=D
  return bot_probe_build.main()
 assert not D.exists(),'No overwrite'
 baseline=R/C['baseline_zip'];assert sha(baseline.read_bytes())==C['baseline_sha256']
 with zipfile.ZipFile(baseline) as z:f={k:z.read(k) for k in z.namelist()}
 before=dict(f);m=json.loads(f['audit/baseline_manifest.json'])
 for row in m['selected']:assert sha(f['work/design/'+row['path']])==row['sha256'],row['path']
 al='work/design/td_project/hx4s20_basic.al';t=f[al].decode()
 assert 'infer_add' not in t
 oldprop='    <Property>\n    </Property>'
 newprop='    <Property>\n        <DesignProperty>\n            <infer_add>off</infer_add>\n        </DesignProperty>\n    </Property>'
 oldsyn='            <Strategy Name="Default_Synthesis_Strategy">\n            </Strategy>'
 newsyn='            <Strategy Name="Default_Synthesis_Strategy">\n                <DesignProperty>\n                    <infer_add>off</infer_add>\n                </DesignProperty>\n            </Strategy>'
 for old,new in [(oldprop,newprop),(oldsyn,newsyn)]:
  assert t.count(old)==1,old;t=t.replace(old,new)
 oldroot=(R/'output/html_fidelity/builds/bot_hdmi_probe_001').as_posix()
 assert t.count(oldroot)==1
 t=t.replace(oldroot,D.as_posix());f[al]=t.encode()
 # No source path rewriting: all HDL and constraints stay byte-for-byte identical.
 unchanged=[k for k in before if k.startswith('work/design/') and k!=al]
 assert all(before[k]==f[k] for k in unchanged)
 assert all(before[k]==f[k] for k in before if k.startswith('harness/'))
 # Existing absolute ROM init dependencies are frozen baseline files; verify each.
 assets=[]
 for k,v in f.items():
  if k.endswith(('.v','.sv')):
   for path in re.findall(rb'"(D:/FPGA/[^"\r\n]+)"',v):
    if oldroot.encode() not in path:continue
    p=pathlib.Path(path.decode());key='work/design/'+path.decode().split('/work/design/',1)[1]
    assert p.read_bytes()==before[key],str(p)
    assets.append(dict(path=str(p),sha256=sha(p.read_bytes())))
 diff=''.join(difflib.unified_diff(before[al].decode().splitlines(True),t.splitlines(True),fromfile='baseline/hx4s20_basic.al',tofile='infer_add_off/hx4s20_basic.al'))
 commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip()
 dirty=subprocess.check_output(['git','diff','HEAD','--name-only'],cwd=R,text=True).strip();assert not dirty,dirty
 audit=dict(config=C,source_commit=commit,baseline_commit=m['git_commit'],unchanged_design_inputs=unchanged,external_verified_assets=assets,changed_design_inputs=[al],harness_byte_identical=True)
 selected=[dict(path=k[len('work/design/'):],sha256=sha(v),bytes=len(v)) for k,v in sorted(f.items()) if k.startswith('work/design/')]
 m.update(run_id=ID,git_commit=commit,git_status=[],selected=selected,snapshot_sha256=sha(json.dumps(selected,sort_keys=True).encode()),experiment=audit,created_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
 f['audit/baseline_manifest.json']=json.dumps(m,indent=2).encode()
 f['audit/infer_add_audit.json']=json.dumps(audit,indent=2).encode()
 f['audit/infer_add_only.diff']=diff.encode()
 package=R/'artifacts'/(ID+'_source.zip')
 with zipfile.ZipFile(package,'x',zipfile.ZIP_DEFLATED) as z:
  for k,v in f.items():z.writestr(k,v)
 D.mkdir(parents=True)
 with zipfile.ZipFile(package) as z:z.extractall(D)
 (D/'audit/package_sha256.txt').write_text(sha(package.read_bytes()))
 (D/'work/design/td_project/hx4s20_basic_Runs').mkdir(exist_ok=True)
 print(json.dumps(dict(source_commit=commit,source_zip=str(package),sha256=sha(package.read_bytes()),unchanged_design_inputs=len(unchanged),assets_verified=len(assets)),indent=2));print(diff)
if __name__=='__main__':main()
