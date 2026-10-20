"""Short probe tests and actual-top elaboration, without media simulation."""
from pathlib import Path
import datetime
import hashlib
import json
import subprocess
import time
import sys
import re
ROOT=Path(__file__).resolve().parents[1]
out=ROOT/"evidence/hdmi_probe"/sys.argv[1]
out.mkdir(parents=True,exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
r={"started_utc":datetime.datetime.now(datetime.timezone.utc).isoformat(),"steps":[],"tools":{}}
for t in ["iverilog","vvp"]:
 p=Path("C:/iverilog/bin")/(t+".exe")
 v=subprocess.run([str(p),"-V"],capture_output=True)
 r["tools"][t]={"path":str(p),"sha256":sha(p),"version":(v.stdout+v.stderr).decode(errors="replace")}
def run(cmd):
 start=time.monotonic()
 p=subprocess.Popen(cmd,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
 try:a,b=p.communicate(timeout=60)
 except subprocess.TimeoutExpired:
  p.kill();a,b=p.communicate()
 e={"command":cmd,"pid":p.pid,"exit_code":p.returncode,"wall_seconds":time.monotonic()-start,
    "stdout":a.decode(errors="replace"),"stderr":b.decode(errors="replace")}
 r["steps"].append(e)
 (out/"receipt.json").write_text(json.dumps(r,indent=2))
 if p.returncode:raise RuntimeError(e)
for top in ["tb","display_tb"]:
 run(["C:/iverilog/bin/iverilog.exe","-g2012","-s",top,"-o",str(out/(top+".vvp")),
      "tests/hdmi_probe_tb.v","rtl/ext/hdmi_probe.v","rtl/video_rgb_to_axis_640x480.v"])
 run(["C:/iverilog/bin/vvp.exe",str(out/(top+".vvp"))])
baseline=Path("D:/FPGA/EG4S20-NoBot")
a=(baseline/"rtl/top_tf_hdmi_audio.v").read_text(encoding="utf-8")
b=(ROOT/"rtl/top_tf_hdmi_audio.v").read_text(encoding="utf-8")
# No existing functional instance other than the old display may change.
instance=r"(?m)^(\w+)\s+(?:#\s*\(.*?\)\s*)?(\w+)\s*\((.*?)\);"
old={m[2]:(m[1],m[3]) for m in re.finditer(instance,a,re.S)}
new={m[2]:(m[1],m[3]) for m in re.finditer(instance,b,re.S)}
checks={}
for name,value in old.items():
 if name in ["seg_decoder_m0","seg_scan_m0"]:continue
 actual=new.get(name)
 if name=="u_hdmi_1_4b_transmitter_core_wrapper":
  actual=(actual[0],actual[1].replace("(probe_video_locked)","()"))
 checks[name]=actual==value
assert checks and all(checks.values()),checks
# Entire original RTL and constraints unchanged except top; source set addition only.
changed=[]
for f in (baseline/"rtl").rglob("*"):
 if f.is_file():
  d=ROOT/f.relative_to(baseline)
  if not d.exists() or sha(f)!=sha(d):changed.append(f.relative_to(baseline).as_posix())
assert changed==["rtl/top_tf_hdmi_audio.v"],changed
for n in ["pin.adc","timing.sdc"]:
 assert sha(baseline/"project/user_source/constraints_source"/n)==sha(ROOT/"project/user_source/constraints_source"/n)
r["unchanged_functional_instances"]=checks
r["changed_existing_rtl"]=changed
boot=Path("D:/FPGA/EG4S20-NoBot-HWFix/output/hardware/no_bot_20261019T140608Z/debug/actual_top_boot_05")
old_run=json.loads((boot/"status.json").read_text())
files=[x for x in old_run["compile_command"] if x.startswith("rtl/") and x.endswith(".v")]
leaves=boot/"tests/no_bot_actual_top_leaves.v"
run(["C:/iverilog/bin/iverilog.exe","-g2012","-DHTML_SIM","-Irtl/SD","-s","top","-o",str(out/"top.vvp")]
    +files+["rtl/ext/hdmi_probe.v",str(leaves)])
r["elaboration_scope"]="Actual top elaboration only; protected/physical leaves replaced, no full-system simulation."
r["source_sha256"]={n:sha(ROOT/n) for n in files+["rtl/ext/hdmi_probe.v","tests/hdmi_probe_tb.v","scripts/apply_hdmi_probe.py"]}
r["external_leaves"]={"path":str(leaves),"sha256":sha(leaves)}
r["finished_utc"]=datetime.datetime.now(datetime.timezone.utc).isoformat()
r["state"]="SCOPED_PASS"
(out/"receipt.json").write_text(json.dumps(r,indent=2))
print(json.dumps(r,indent=2))
