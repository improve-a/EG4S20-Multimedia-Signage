"""Root-only SRAM download of a hash-bound, manually qualified build; never Flash."""
from pathlib import Path
import sys,json,hashlib,subprocess
sys.path.insert(0,str(Path(__file__).parent/'harness'))
from windows_runner import remote_python
build,attempt=sys.argv[1:]
assert all(x.replace('_','').isalnum() for x in [build,attempt])
root=Path(__file__).resolve().parent.parent
q=json.loads((root/'reports'/(build+'_acceptance.json')).read_text())
assert q['M5_GATE']=='PASS' and q['SRAM_DOWNLOAD_ALLOWED'] is True
assert q['run_id']==build and q['device']=='EG4S20BG256'
bit=q['windows_bit_path'];sha=q['bit_sha256'];snapshot=q['snapshot_sha256']
# Explicit supported jtag work mode targets volatile configuration SRAM.
tcl='''puts "HARNESS_SRAM_BEGIN"
set rc [catch {read_device_id -cable 0} result]
puts "PRE_ID_TCL_RC=$rc RESULT=$result"
if {$rc || $result ne "EG4S20BG256"} {exit 3}
set rc [catch {download -bit {BIT_PATH} -mode jtag -cable 0 -spd 6} result]
puts "DOWNLOAD_TCL_RC=$rc RESULT=$result"
if {$rc} {exit 4}
puts "HARNESS_SRAM_COMMAND_RETURNED"
set rc [catch {read_device_id -cable 0} result]
puts "POST_ID_TCL_RC=$rc RESULT=$result"
if {$rc || $result ne "EG4S20BG256"} {exit 5}
puts "HARNESS_SRAM_POST_ID_PASS"
exit
'''.replace('BIT_PATH',bit.replace('\\','/'))
code=f'''import pathlib,subprocess,hashlib,datetime,time,json,os
r=pathlib.Path(r'D:\\FPGA\\hx4s20_contest1_20261013');assert not(r/'audit/build.lock').exists()
s=json.loads((r/'builds'/{build!r}/'runs'/{build!r}/'status.json').read_text())
assert s['state']=='FINISHED' and s['exit_code']==0 and s['snapshot_sha256']=={snapshot!r}
b=pathlib.Path({bit!r});assert hashlib.sha256(b.read_bytes()).hexdigest()=={sha!r}
header=b.read_bytes()[:1024];assert b'# Package: EG4S20BG256' in header and b'# Design name: top' in header
exe=pathlib.Path(r'G:\\anlu\\bin\\bw_commands_prompt.exe');es=hashlib.sha256(exe.read_bytes()).hexdigest();assert es=='513b024c8c1853825441939c9c51feb0156c2c6c2043f854a39e805c38064401'
o=r/'reports/hardware'/{attempt!r};o.mkdir(parents=True,exist_ok=False)
(o/'gate.json').write_text({json.dumps(q,indent=2)!r});f=o/'sram.tcl';f.write_text({tcl!r})
lock=r/'audit/jtag.lock';fd=os.open(lock,os.O_CREAT|os.O_EXCL|os.O_WRONLY);os.close(fd)
m=dict(started_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),mode='jtag',persistent_flash_write=False,exe=str(exe),exe_sha256=es,tcl_sha256=hashlib.sha256(f.read_bytes()).hexdigest(),bit_sha256={sha!r},snapshot_sha256={snapshot!r},state='STARTING')
(o/'metadata.json').write_text(json.dumps(m,indent=2));t=time.monotonic()
try:
 p=subprocess.Popen([str(exe)],cwd=o,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE);m['pid']=p.pid
 (o/'metadata.json').write_text(json.dumps(m,indent=2))
 try:a,z=p.communicate(('source {{'+f.as_posix()+'}}\\nexit\\n').encode(),timeout=90)
 except subprocess.TimeoutExpired:
  p.kill();a,z=p.communicate();m['timeout']=True
 (o/'stdout.log').write_bytes(a);(o/'stderr.log').write_bytes(z)
 m.update(state='RETURNED',exit_code=p.returncode,elapsed_seconds=time.monotonic()-t,finished_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
 (o/'metadata.json').write_text(json.dumps(m,indent=2));print(json.dumps(m));print(a.decode(errors='replace'));print(z.decode(errors='replace'))
finally:lock.unlink()
'''
s=remote_python(code,timeout=105)
out=root/'reports/hardware';(out/(attempt+'_dispatch.txt')).write_text(s);print(s)
subprocess.run(['scp','-r','thinkpad:D:/FPGA/hx4s20_contest1_20261013/reports/hardware/'+attempt,str(out)],check=True)
# Native success output must be reviewed; a returned command is not functional HW PASS.
native=json.JSONDecoder().raw_decode(s[s.index('{'):])[0]
sys.exit(native['exit_code'] or (124 if native.get('timeout') else 0))
