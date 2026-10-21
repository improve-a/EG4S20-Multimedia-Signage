import sys
p=sys.argv[1]; t=open(p,encoding="utf-8",errors="replace").read().splitlines()
blocks=[]; cur=None
for i,l in enumerate(t):
    if l.startswith("Slack               :"):
        if cur: blocks.append(cur)
        cur={"line":i+1,"lines":[l]}
    elif cur is not None:
        cur["lines"].append(l)
if cur: blocks.append(cur)
def f(b,n):
    for l in b["lines"]:
        if l.startswith(n): return l.split(":",1)[1].strip()
    return ""
from collections import Counter
c=Counter()
for b in blocks:
    typ=f(b,"Check Type")
    if typ not in ("recovery","removal"): continue
    end=f(b,"End Point"); beg=f(b,"Begin Point")
    # classify hierarchy
    hier = end.split('.')[0]
    c[(typ,hier)] += 1
for k,v in sorted(c.items()):
    print(v, k[0], k[1])
