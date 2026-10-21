"""Analysis-only scoped STA of independently audited reset-entry replicas.

Never edits source SDC, routed DB or bit. Keeps a fresh raw report alongside
the scoped result. These exclusions restore the existing RTL sync-entry intent;
they do not fix a hardware fault and do not prove the NoBot root cause.
"""
import hashlib,json,pathlib,shutil,subprocess,time
r=pathlib.Path(r'D:\FPGA\EG4S20-NoBot-Fix-20261020');b=r/'builds/media_status_001'
audit=json.loads((r/'audit/root_reset_structure.json').read_text())
assert audit['classification_counts']=={'second_stage_reset_replica':19,'no_q_output_unconsumed_FF_SR_not_data':1}
out=r/'reviewed_reset_sta_003';out.mkdir(exist_ok=False)
db=b/'work/design/td_project/hx4s20_basic_Runs/phy_1/hx4s20_basic_pr.db'
sdc=b/'work/design/user_source/constraints_source/timing.sdc'
bit=b/'work/design/td_project/hx4s20_basic_Runs/phy_1/hx4s20_basic.bit'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
before={str(p):sha(p) for p in (db,sdc,bit)}
copy=out/'review_only.db';shutil.copy2(db,copy)
lines=[f'import_device eagle_s20.db -package EG4S20BG256',f'import_db {{{copy.as_posix()}}}','update_timing -mode final',f'report_timing_summary -file {{{(out/"raw.rpt").as_posix()}}} -ep_num 128 -path_num 2','namespace eval ::rca_review {}','set ::rca_review::source [get_regs {rst_all}]','puts [list AUDITED_SOURCE [get_regs -o {rst_all}]]','if {[llength $::rca_review::source] != 1} {error "Expected exactly one reset source"}']
for e in sorted(audit['negative_cells'],key=lambda x:x['name']):
 pin=e['name']+'.sr'
 lines += [f'# {e["classification"]}: exact pin; no wildcard/downstream data endpoints.',f'set ::rca_review::sink [get_pins {{{pin}}}]',f'puts [list AUDITED_PIN {{{pin}}} [get_pins -o {{{pin}}}]]','if {[llength $::rca_review::sink] != 1} {error "Expected exactly one audited SR pin"}','set_false_path -hold -from $::rca_review::source -to $::rca_review::sink']
lines += ['update_timing -mode final',f'report_timing_summary -file {{{(out/"scoped.rpt").as_posix()}}} -ep_num 128 -path_num 2',f'report_timing_ignored -file {{{(out/"ignored.rpt").as_posix()}}} -ep_num 128 -path_num 2',f'report_timing_exception -file {{{(out/"exceptions.rpt").as_posix()}}} -ep_num 128 -path_num 2','puts REVIEW_ONLY_COMPLETE','exit 0']
tcl=out/'review.tcl';tcl.write_text('\n'.join(lines)+'\n')
command=f'if {{[catch {{source {{{tcl.as_posix()}}}}} err]}} {{puts stderr $err; exit 2}}\nexit 2\n'
start=time.monotonic()
with (out/'stdout.log').open('wb') as so,(out/'stderr.log').open('wb') as se:
 p=subprocess.run([r'G:\anlu\bin\td_commands_prompt.exe'],cwd=out,input=command.encode(),stdout=so,stderr=se,timeout=120)
unchanged=all(sha(pathlib.Path(k))==v for k,v in before.items())
receipt={'scope':'ANALYSIS_ONLY: 19 verified second-stage asynchronous reset inputs plus one unused FF SR. No RTL/production-SDC/DB/bit changes. NOT A ROOT CAUSE FIX.','exit':p.returncode,'seconds':time.monotonic()-start,'source_hashes':before,'source_files_unchanged':unchanged,'audited_targets':[{k:e[k] for k in ('name','classification','slack')} for e in audit['negative_cells']]}
(out/'receipt.json').write_text(json.dumps(receipt,indent=2))
print(json.dumps(receipt,indent=2))
assert p.returncode==0 and unchanged,receipt
