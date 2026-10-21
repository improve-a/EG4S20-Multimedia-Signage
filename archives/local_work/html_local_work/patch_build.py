from pathlib import Path
r=Path('D:/FPGA/EG4S20-Multimedia-Signage')
p=r/'scripts/prepare_snapshot.py';s=p.read_text();s=s.replace("a.add_argument('--synth-top');x=a.parse_args()", "a.add_argument('--synth-top');a.add_argument('--build-root');x=a.parse_args()")
s=s.replace("dest=REMOTE+'\\\\builds\\\\'+x.run_id", "dest=str(pathlib.Path(x.build_root)/x.run_id) if x.build_root else REMOTE+'\\\\builds\\\\'+x.run_id")
s=s.replace("lookup={k.lower() for k in files}", "# Resolve initialization files to this immutable snapshot before synthesis.\nfor key in list(files):\n    if key.endswith(('.v','.sv')) and b'rtl/ext/html_assets/' in files[key]:\n        files[key]=files[key].replace(b'rtl/ext/html_assets/',(dest.replace('\\\\','/')+'/work/design/user_source/hdl_source/ext/html_assets/').encode())\nlookup={k.lower() for k in files}")
p.write_text(s)
p=r/'scripts/build.py';s=p.read_text();s=s.replace('import argparse,json,pathlib,subprocess,sys','import argparse,json,pathlib,subprocess,sys,os,zipfile,datetime')
s=s.replace("a.add_argument('--synth-top');x=a.parse_args()", "a.add_argument('--synth-top');a.add_argument('--build-root',type=pathlib.Path);x=a.parse_args()")
needle="dest=REMOTE+'\\\\builds\\\\'+x.run_id"
native='''if os.name=='nt':
    base=x.build_root or ROOT/'output/html_fidelity/builds'
    dest=base/x.run_id
    if x.action=='launch':
        check=subprocess.run(['powershell','-NoProfile','-Command','Get-Process td_commands_prompt,td,fdp,synpwrap -ErrorAction SilentlyContinue | Select-Object Id,ProcessName | ConvertTo-Json'],capture_output=True,text=True)
        if check.stdout.strip():raise RuntimeError('Heavy TD already present: '+check.stdout)
        subprocess.run([sys.executable,str(ROOT/'scripts/prepare_snapshot.py'),x.run_id,'--build-root',str(base)]+(['--synth-top',x.synth_top] if x.synth_top else []),check=True,cwd=ROOT)
        dest.mkdir(parents=True,exist_ok=False)
        archive=ROOT/'artifacts'/(x.run_id+'_source.zip')
        with zipfile.ZipFile(archive) as z:z.extractall(dest)
        (dest/'work/design/td_project/hx4s20_basic_Runs').mkdir(exist_ok=True)
        import hashlib
        (dest/'audit/package_sha256.txt').write_text(hashlib.sha256(archive.read_bytes()).hexdigest())
        cmd=[sys.executable,str(dest/'harness/windows_job.py'),'--root',str(dest),'--run-id',x.run_id,'--timeout',str(x.timeout)]
        with (dest/'audit/dispatch.log').open('wb') as log:
            proc=subprocess.Popen(cmd,cwd=dest,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NEW_PROCESS_GROUP|subprocess.DETACHED_PROCESS)
        print(json.dumps({'run_id':x.run_id,'pid':proc.pid,'root':str(dest),'command':cmd}))
    else:
        status=dest/'runs'/x.run_id/'status.json'
        print(status.read_text() if status.exists() else 'STATUS_NOT_CREATED')
        stages=status.parent/'stages.tsv'
        print(stages.read_text() if stages.exists() else '')
    raise SystemExit(0)
'''
assert needle in s;s=s.replace(needle,native+'\n'+needle);p.write_text(s)
print('PATCHED_NATIVE_BUILD')
