"""Short, scoped checks on a prepared RCA build. No full media simulation."""
import argparse,hashlib,json,pathlib,re,subprocess,sys,time,zipfile

p=argparse.ArgumentParser();p.add_argument('--build',type=pathlib.Path,required=True);p.add_argument('--baseline-zip',type=pathlib.Path,required=True);a=p.parse_args()
repo=pathlib.Path(__file__).resolve().parents[1]
out=a.build/'rca_checks';out.mkdir(exist_ok=False)
hdl=a.build/'work/design/user_source/hdl_source'
with zipfile.ZipFile(a.baseline_zip) as z:original=z.read('work/design/user_source/hdl_source/top_tf_hdmi_audio.v').decode('utf-8')
actual=(hdl/'top_tf_hdmi_audio.v').read_text(encoding='utf-8')
instance=r'(?m)^(\w+)\s+(?:#\s*\(.*?\)\s*)?(\w+)\s*\((.*?)\);'
old={m[2]:(m[1],m[3]) for m in re.finditer(instance,original,re.S)}
new={m[2]:(m[1],m[3]) for m in re.finditer(instance,actual,re.S)}
checks={k:new.get(k)==v for k,v in old.items() if k not in ('probe','probe_display')}
assert checks and all(checks.values()),checks
result={'functional_instances_unchanged':checks,'steps':[],'scope':'Actual top elaboration with inherited encrypted/physical leaf stubs; observer unit tests. Not a full HDMI or media simulation.'}
def run(command,cwd):
 t=time.monotonic();s=subprocess.run(command,cwd=cwd,capture_output=True,timeout=120)
 e={'command':list(map(str,command)),'exit_code':s.returncode,'seconds':time.monotonic()-t,'stdout':s.stdout.decode(errors='replace'),'stderr':s.stderr.decode(errors='replace')}
 result['steps'].append(e);(out/'receipt.json').write_text(json.dumps(result,indent=2))
 assert s.returncode==0,e
boot=pathlib.Path(r'D:\FPGA\EG4S20-NoBot-HWFix\output\hardware\no_bot_20261019T140608Z\debug\actual_top_boot_05')
cmd=json.loads((boot/'status.json').read_text())['compile_command']
sources=[str(hdl/x[4:]) for x in cmd if x.startswith('rtl/') and x.endswith('.v')]
leaves=boot/'tests/no_bot_actual_top_leaves.v'
run(['C:/iverilog/bin/iverilog.exe','-g2012','-DHTML_SIM','-I'+str(hdl/'SD'),'-s','top','-o',str(out/'top.vvp')]+sources+[str(hdl/'ext/hdmi_probe.v'),str(leaves)],repo)
for top in ('tb','display_tb'):
 run(['C:/iverilog/bin/iverilog.exe','-g2012','-s',top,'-o',str(out/(top+'.vvp')),str(repo/'tests/hdmi_probe_tb.v'),str(hdl/'ext/hdmi_probe.v'),str(hdl/'video_rgb_to_axis_640x480.v')],repo)
 run(['C:/iverilog/bin/vvp.exe',str(out/(top+'.vvp'))],repo)
result['source_hashes']={str(x):hashlib.sha256(x.read_bytes()).hexdigest() for x in [hdl/'top_tf_hdmi_audio.v',hdl/'ext/hdmi_probe.v',leaves,repo/'tests/hdmi_probe_tb.v']}
result['state']='SCOPED_PASS'
(out/'receipt.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
