import pathlib,zipfile,json,hashlib,re,difflib,sys
sys.stdout.reconfigure(encoding='utf-8')
r=pathlib.Path(r'D:\FPGA\EG4S20-NoBot-RCA-20261020')
ids=['no_bot_legacy_004','hdmi_probe_001']
maps=[];out={}
for id in ids:
 z=zipfile.ZipFile(r/'baseline_copies'/(id+'_source.zip'))
 prefix='work/design/'
 m={n[len(prefix):]:z.read(n) for n in z.namelist() if n.startswith(prefix)}
 norm={k:re.sub(rb'D:/FPGA/[^"\r\n]*?/work/design/',b'@DESIGN@/',v.replace(b'\r\n',b'\n')) for k,v in m.items()}
 maps.append(norm)
 al=m['td_project/hx4s20_basic.al'].decode().replace('\r\n','\n')
 sourcefiles=re.findall(r'<File Path="([^"]+)"',al)
 post=(r/'baseline_copies'/id/'work/design/td_project/hx4s20_basic.al').read_text().replace('\r\n','\n')
 out[id]={'files':len(m),'project_source_list':sourcefiles,'project_build_rewrite':''.join(difflib.unified_diff(al.splitlines(True),post.splitlines(True)))}
 print(id,'#source_files',len(sourcefiles))
 print('POSTBUILD_PROJECT_REWRITE\n'+out[id]['project_build_rewrite'])
changes=[]
for name in sorted(maps[0].keys()|maps[1].keys()):
 if maps[0].get(name)!=maps[1].get(name):changes.append(name)
out['normalized_changes']=changes
out['added_project_sources']=sorted(set(out[ids[1]]['project_source_list'])-set(out[ids[0]]['project_source_list']))
out['removed_project_sources']=sorted(set(out[ids[0]]['project_source_list'])-set(out[ids[1]]['project_source_list']))
print('NORMALIZED_CHANGES',changes)
print('ADDED_SOURCES',out['added_project_sources'],'REMOVED_SOURCES',out['removed_project_sources'])
print('PREBUILD_PROJECT_DIFF\n'+''.join(difflib.unified_diff(maps[0]['td_project/hx4s20_basic.al'].decode().splitlines(True),maps[1]['td_project/hx4s20_basic.al'].decode().splitlines(True))))
(r/'compact_inputs.json').write_text(json.dumps(out,indent=2))
