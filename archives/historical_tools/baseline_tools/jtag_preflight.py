"""Root read-only live CYUSB + JTAG identity evidence. No programming operations."""
from pathlib import Path
import sys,json,subprocess
sys.path.insert(0,str(Path(__file__).parent/'harness'))
from windows_runner import remote_python
run_id=sys.argv[1]
assert run_id.replace('_','').isalnum()
ps=r'''$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'
[Console]::OutputEncoding=New-Object System.Text.UTF8Encoding($false)
$os=Get-CimInstance Win32_OperatingSystem
$dev=@(Get-PnpDevice -PresentOnly | Where-Object {$_.InstanceId -like 'USB\VID_0547&PID_1002\*'} | ForEach-Object {
$d=$_;[ordered]@{id=$d.InstanceId;name=$d.FriendlyName;status=$d.Status;properties=@(Get-PnpDeviceProperty -InstanceId $d.InstanceId | Where-Object {$_.KeyName -match 'HardwareIds|ProblemCode|ProblemStatus|IsRebootRequired|DriverInfPath|DriverVersion|DriverProvider|Device_Service|Device_Stack'} | Select-Object KeyName,Data)}})
[ordered]@{utc=[DateTime]::UtcNow.ToString('o');boot_utc=$os.LastBootUpTime.ToUniversalTime().ToString('o');devices=$dev;cyusb=@(Get-CimInstance Win32_SystemDriver -Filter "Name='CYUSB'" | Select-Object Name,State,Started,PathName)} | ConvertTo-Json -Depth 7
'''
tcl='''puts "HARNESS_READ_ONLY_ID_BEGIN"
set rc [catch {list_cable} result]
puts "LIST_CABLE_TCL_RC=$rc RESULT=$result"
if {$rc} {exit 2}
set rc [catch {read_device_id -cable 0} result]
puts "READ_DEVICE_ID_TCL_RC=$rc RESULT=$result"
if {$rc || $result ne "EG4S20BG256"} {exit 3}
puts "HARNESS_READ_ONLY_ID_PASS"
exit
'''
code=f'''import pathlib,base64,subprocess,json,time,datetime,hashlib
r=pathlib.Path(r'D:\\FPGA\\hx4s20_contest1_20261013');o=r/'reports/hardware'/{run_id!r};o.mkdir(parents=True,exist_ok=False)
ps={ps!r};(o/'driver.ps1').write_text(ps)
p=subprocess.run(['powershell.exe','-NoProfile','-NonInteractive','-EncodedCommand',base64.b64encode(ps.encode('utf-16le')).decode()],capture_output=True,timeout=35)
(o/'driver.json').write_bytes(p.stdout);(o/'driver_stderr.log').write_bytes(p.stderr)
assert p.returncode==0,p.stderr
j=json.loads(p.stdout.decode('utf-8-sig'));assert len(j['devices'])==1
assert j['devices'][0]['status']=='OK'
pr={{x['KeyName']:x['Data'] for x in j['devices'][0]['properties']}};assert pr['DEVPKEY_Device_ProblemCode']==0
assert any(d['State']=='Running' and d['Started'] for d in j['cyusb'])
e=pathlib.Path(r'G:\\anlu\\bin\\bw_commands_prompt.exe');sha=hashlib.sha256(e.read_bytes()).hexdigest()
assert sha=='513b024c8c1853825441939c9c51feb0156c2c6c2043f854a39e805c38064401'
f=o/'read_id.tcl';f.write_text({tcl!r});t=time.monotonic();start=datetime.datetime.now(datetime.timezone.utc).isoformat()
p=subprocess.Popen([str(e)],cwd=o,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
a,b=p.communicate(('source {{'+f.as_posix()+'}}\\nexit\\n').encode(),timeout=40)
(o/'stdout.log').write_bytes(a);(o/'stderr.log').write_bytes(b)
m=dict(utc=start,pid=p.pid,exit_code=p.returncode,elapsed_seconds=time.monotonic()-t,exe=str(e),exe_sha256=sha,tcl_sha256=hashlib.sha256(f.read_bytes()).hexdigest(),read_only=True)
(o/'metadata.json').write_text(json.dumps(m,indent=2));print(json.dumps(m));print(a.decode(errors='replace'));print(b.decode(errors='replace'))
assert p.returncode==0 and b'HARNESS_READ_ONLY_ID_PASS' in a
'''
r=remote_python(code,timeout=90)
local=Path(__file__).resolve().parent.parent/'reports/hardware';local.mkdir(exist_ok=True)
(local/(run_id+'_dispatch.txt')).write_text(r);print(r)
subprocess.run(['scp','-r','thinkpad:D:/FPGA/hx4s20_contest1_20261013/reports/hardware/'+run_id,str(local)],check=True)
