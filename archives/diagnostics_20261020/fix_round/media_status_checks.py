"""Observer-only change checks and short tests; no HDMI hardware claim."""
import argparse,hashlib,json,pathlib,re,subprocess,time,zipfile
p=argparse.ArgumentParser();p.add_argument('--build',type=pathlib.Path,required=True);p.add_argument('--baseline-zip',type=pathlib.Path,required=True);a=p.parse_args()
repo=pathlib.Path(__file__).resolve().parents[1]
out=a.build/'rca_checks';out.mkdir(exist_ok=False)
hdl=a.build/'work/design/user_source/hdl_source'
with zipfile.ZipFile(a.baseline_zip) as z:
 oldtop=z.read('work/design/user_source/hdl_source/top_tf_hdmi_audio.v').decode()
 oldprobe=z.read('work/design/user_source/hdl_source/ext/hdmi_probe.v').decode()
newtop=(hdl/'top_tf_hdmi_audio.v').read_text(encoding='utf-8')
newprobe=(hdl/'ext/hdmi_probe.v').read_text(encoding='utf-8')
assert oldprobe.replace('\r\n','\n').split('endmodule')[0]==newprobe.split('endmodule')[0]
instance=r'(?m)^(\w+)\s+(?:#\s*\(.*?\)\s*)?(\w+)\s*\((.*?)\);'
def instances(s):return {m[2]:(m[1],m[3]) for m in re.finditer(instance,s,re.S)}
old=instances(oldtop.replace('\r\n','\n'))
# The media instance adds one output-only observer port; all functional ports
# and every executable media statement must remain byte-equivalent.
new=instances(newtop.replace('    .diagnostic_catalog_ready(diagnostic_catalog_ready),\n',''))
with zipfile.ZipFile(a.baseline_zip) as z:
 oldmedia=z.read('work/design/user_source/hdl_source/ext/legacy_exhibit_media.v').decode().replace('\r\n','\n')
newmedia=(hdl/'ext/legacy_exhibit_media.v').read_text(encoding='utf-8')
stripped=newmedia.replace(' output diagnostic_catalog_ready,\n','').replace(' assign diagnostic_catalog_ready=catalog_ready; // Read-only diagnostic output.\n','')
assert stripped==oldmedia,'Non-observer media code changed'
checks={k:new.get(k)==v for k,v in old.items() if k!='probe_display'}
assert checks and all(checks.values()),checks
result={'scope':'Observer display test plus actual top elaboration using inherited encrypted/physical leaf stubs. Not full-system simulation or hardware validation.','functional_instances_unchanged':checks,'probe_video_domain_module_unchanged':True,'steps':[]}
def run(cmd):
 start=time.monotonic();s=subprocess.run(cmd,cwd=repo,capture_output=True,timeout=120)
 result['steps'].append({'command':cmd,'exit':s.returncode,'seconds':time.monotonic()-start,'stdout':s.stdout.decode(errors='replace'),'stderr':s.stderr.decode(errors='replace')})
 (out/'receipt.json').write_text(json.dumps(result,indent=2))
 assert s.returncode==0,result['steps'][-1]
boot=pathlib.Path(r'D:\FPGA\EG4S20-NoBot-HWFix\output\hardware\no_bot_20261019T140608Z\debug\actual_top_boot_05')
cmd=json.loads((boot/'status.json').read_text(encoding='utf-8'))['compile_command']
sources=[str(hdl/x[4:]) for x in cmd if x.startswith('rtl/') and x.endswith('.v')]
run(['C:/iverilog/bin/iverilog.exe','-g2012','-DHTML_SIM','-I'+str(hdl/'SD'),'-s','top','-o',str(out/'top.vvp')]+sources+[str(hdl/'ext/hdmi_probe.v'),str(boot/'tests/no_bot_actual_top_leaves.v')])
for top,tb in [('tb',repo/'tests/hdmi_probe_tb.v'),('media_status_display_tb',repo/'tests/media_status_display_tb.v')]:
 run(['C:/iverilog/bin/iverilog.exe','-g2012','-s',top,'-o',str(out/(top+'.vvp')),str(tb),str(hdl/'ext/hdmi_probe.v'),str(hdl/'video_rgb_to_axis_640x480.v')])
 run(['C:/iverilog/bin/vvp.exe',str(out/(top+'.vvp'))])
result['source_hashes']={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (hdl/'top_tf_hdmi_audio.v',hdl/'ext/hdmi_probe.v',repo/'tests/media_status_display_tb.v')}
result['state']='SCOPED_PASS'
(out/'receipt.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
