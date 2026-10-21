import pathlib,subprocess,zipfile
r=pathlib.Path(r'D:\FPGA\EG4S20-NoBot-Fix-20261020');repo=r/'repo'
assert not subprocess.check_output(['git','status','--short'],cwd=repo,text=True).strip(),'Unexpected working-tree changes'
with zipfile.ZipFile(r/'scripts/git_integration.zip') as z:
 assert all(n.startswith(('docs/fix_round/','scripts/fix_round/','tests/fix_round/')) and '..' not in pathlib.PurePosixPath(n).parts for n in z.namelist())
 z.extractall(repo)
subprocess.run(['git','add','docs/fix_round','scripts/fix_round','tests/fix_round'],cwd=repo,check=True)
subprocess.run(['git','commit','-m','analysis: seal unresolved RCA evidence and non-deployable status diagnostic'],cwd=repo,check=True)
bundle=r/'delivery/nobot_unattended_20261021.bundle'
assert not bundle.exists()
subprocess.run(['git','bundle','create',str(bundle),'codex/nobot-fix-20261020'],cwd=repo,check=True)
subprocess.run(['git','bundle','verify',str(bundle)],cwd=repo,check=True)
assert not subprocess.check_output(['git','status','--short'],cwd=repo,text=True).strip()
print('FINAL_COMMIT='+subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip())
