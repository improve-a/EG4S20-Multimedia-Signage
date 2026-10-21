"""Prepare one controlled source-ZIP derivative and run the inherited TD flow.

Windows only. No hardware commands, no edits to a source baseline, no retries.
The only HDL changes are exact, counted replacements in experiment JSON.
"""
import argparse, base64, datetime, hashlib, json, pathlib, re, subprocess, sys, zipfile

def sha(data): return hashlib.sha256(data).hexdigest()

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--config',type=pathlib.Path,required=True)
    p.add_argument('--baseline-zip',type=pathlib.Path,required=True)
    p.add_argument('--build-root',type=pathlib.Path,required=True)
    args=p.parse_args()
    config=json.loads(args.config.read_text(encoding='utf-8'))
    repo=pathlib.Path(__file__).resolve().parents[1]
    assert sha(args.baseline_zip.read_bytes())==config['baseline_zip_sha256']
    id=config['run_id']; assert re.fullmatch(r'[a-zA-Z0-9_-]+',id)
    dest=args.build_root/id
    if dest.exists(): raise RuntimeError(f'Refusing to overwrite {dest}')
    busy=subprocess.run(['powershell','-NoProfile','-Command','Get-Process td_commands_prompt,td,fdp,synpwrap -ErrorAction SilentlyContinue | Select-Object Id,ProcessName | ConvertTo-Json'],capture_output=True)
    if busy.stdout.strip(): raise RuntimeError('TD is already present: '+repr(busy.stdout))
    with zipfile.ZipFile(args.baseline_zip) as z:
        files={n:z.read(n) for n in z.namelist() if not n.endswith('/')}
        original_manifest=json.loads(files['audit/baseline_manifest.json'])
    changes=[]
    for item in config['replacements']:
        key='work/design/'+item['path']
        before=files[key]
        old=item['old'].encode(); new=item['new'].encode()
        assert before.count(old)==item.get('count',1),(item['path'],'replacement count')
        files[key]=before.replace(old,new)
        changes.append({'path':item['path'],'before_sha256':sha(before),'after_sha256':sha(files[key])})
    # Relocate every absolute asset/project reference together, preserving bytes otherwise.
    old_root=config['baseline_build_root'].encode()
    new_root=dest.as_posix().encode()
    for key,data in list(files.items()):
        if key.startswith('work/design/') and key.endswith(('.v','.sv','.al')):
            files[key]=data.replace(old_root,new_root)
    selected=[{'path':k[len('work/design/'):],'sha256':sha(v),'bytes':len(v)} for k,v in sorted(files.items()) if k.startswith('work/design/')]
    commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip()
    manifest={**original_manifest,'task_root':str(args.build_root.parent),'run_id':id,'source':'controlled derivative of hash-verified frozen source ZIP','selected':selected,'snapshot_sha256':sha(json.dumps(selected,sort_keys=True).encode()),'created_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'git_commit':commit,'git_branch':subprocess.check_output(['git','branch','--show-current'],cwd=repo,text=True).strip(),'git_status':subprocess.check_output(['git','status','--short'],cwd=repo,text=True).splitlines(),'experiment':config,'source_changes':changes}
    if manifest['git_status']: raise RuntimeError('Commit the experimental recipe before building: '+repr(manifest['git_status']))
    files['audit/baseline_manifest.json']=json.dumps(manifest,indent=2).encode()
    files['audit/rca_config.json']=args.config.read_bytes()
    package=args.build_root.parent/'delivery'/(id+'_source.zip')
    package.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(package,'x',zipfile.ZIP_DEFLATED) as z:
        for k,v in files.items():z.writestr(k,v)
    dest.mkdir(parents=True,exist_ok=False)
    with zipfile.ZipFile(package) as z:z.extractall(dest)
    (dest/'audit/package_sha256.txt').write_text(sha(package.read_bytes()))
    (dest/'work/design/td_project/hx4s20_basic_Runs').mkdir(exist_ok=True)
    (args.build_root.parent/'audit').mkdir(exist_ok=True)
    checks=repo/config.get('verify_script','scripts/rca_checks.py')
    subprocess.run([sys.executable,str(checks),'--build',str(dest),'--baseline-zip',str(args.baseline_zip)],check=True)
    # Existing status files are UTF-8, including localized exception messages.
    command=subprocess.list2cmdline([sys.executable,'-X','utf8',str(dest/'harness/windows_job.py'),'--root',str(dest),'--run-id',id,'--timeout','1800'])
    ps="$r=Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine='"+command.replace("'","''")+"';CurrentDirectory='"+str(dest).replace("'","''")+"'}; $r | Select-Object ReturnValue,ProcessId | ConvertTo-Json; if($r.ReturnValue -ne 0){exit 1}"
    launch=subprocess.run(['powershell','-NoProfile','-NonInteractive','-EncodedCommand',base64.b64encode(ps.encode('utf-16le')).decode()],capture_output=True,check=True)
    (dest/'audit/dispatch.log').write_bytes(launch.stdout+launch.stderr)
    print('LAUNCHED '+id+' '+commit,flush=True)
    status=dest/'runs'/id/'status.json'
    # Wait on the process, not status.json: Windows file readers can prevent
    # the inherited supervisor's atomic rename (observed WinError 5 in A001).
    pid=int(json.loads(launch.stdout.decode('utf-8-sig'))['ProcessId'])
    wait=subprocess.run(['powershell','-NoProfile','-NonInteractive','-Command',f'$p=Get-Process -Id {pid} -ErrorAction SilentlyContinue; if($p){{$p | Wait-Process -Timeout 1900 -ErrorAction Stop}}; exit 0'],capture_output=True)
    if wait.returncode:raise RuntimeError('Supervisor wait failed: '+repr(wait.stderr))
    state=json.loads(status.read_text(encoding='utf-8'))
    print(json.dumps(state,indent=2),flush=True)
    if state['state']!='FINISHED':raise SystemExit(1)

if __name__=='__main__':main()
