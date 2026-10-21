import json,pathlib,re,sys
r=pathlib.Path(r'D:\FPGA\EG4S20-NoBot-Fix-20261020');id=sys.argv[1]
p=pathlib.Path(sys.argv[2]) if len(sys.argv)>2 else r/'builds'/id/'runs'/id/'final_timing.rpt';s=p.read_text(errors='replace')
records=[]
for block in re.split(r'(?=Slack\s+:)',s):
 m=re.match(r'Slack\s+:\s*(-?[\d.]+)ns',block)
 if not m:continue
 def field(name):
  m=re.search(r'^'+name+r'\s*:\s*(.*)',block,re.M);return m[1].strip() if m else None
 v=float(m[1]);records.append({'slack':v,'type':field('Check Type'),'begin':field('Begin Point'),'end':field('End Point'),'budget':field('Budget'),'delay':field('Data Path Delay'),'skew':field('Clock Skew'),'text':block[:11000] if v<0 else None})
result={'id':id,'header':s[:s.index('Clock Summary')],'groups':[x for x in s.splitlines() if re.search(r'Viol Endpoints',x)],'class_minima':{t:min(x['slack'] for x in records if x['type']==t) for t in sorted({x['type'] for x in records})},'negative_records':[x for x in records if x['slack']<0]}
(r/'audit'/('sta_'+id+'.json')).write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
