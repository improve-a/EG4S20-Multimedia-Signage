import datetime,hashlib,json,pathlib,subprocess
root=pathlib.Path(r'D:\FPGA\hx4s20_usb_jtag_harness_20261013')
tool=pathlib.Path(r'C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64\signtool.exe')
base=pathlib.Path('G:/macshare/嵌赛/HX4S20_Contest_202606/1_安路开发工具和常用软件/常用软件/常用软件/上位机软件/下载器驱动/driver')
rows=[]
for variant in ['win8_10_64','win7_64']:
 d=base/variant
 row={'path':str(d),'files':[],'checks':[]}
 for name in ['cyusb.inf','cyusb.sys','driver.cat']:
  f=d/name
  row['files'].append({'name':name,'exists':f.exists(),'sha256':hashlib.sha256(f.read_bytes()).hexdigest() if f.exists() else None})
 if not all((d/n).exists() for n in ['cyusb.inf','cyusb.sys','driver.cat']):
  rows.append(row);continue
 row['inf']= (d/'cyusb.inf').read_text(errors='replace')
 for policy in ['/pa','/kp']:
  args=[str(tool),'verify',policy,'/v','/c',str(d/'driver.cat'),str(d/'cyusb.sys')]
  p=subprocess.run(args,capture_output=True,timeout=40)
  row['checks'].append({'args':args,'exit':p.returncode,'stdout':p.stdout.decode('mbcs',errors='replace'),'stderr':p.stderr.decode('mbcs',errors='replace')})
 rows.append(row)
result={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'tool':str(tool),'tool_sha256':hashlib.sha256(tool.read_bytes()).hexdigest(),'operation':'read-only verification; no installation','packages':rows}
stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
(root/(stamp+'_local_alternatives.json')).write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(result,ensure_ascii=False,indent=2))
