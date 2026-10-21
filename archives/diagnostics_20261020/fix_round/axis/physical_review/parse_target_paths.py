import sys, re, json, collections
p=sys.argv[1]
t=open(p,encoding="utf-8",errors="replace").read().splitlines()
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
        if l.startswith(n) and ":" in l: return l.split(":",1)[1].strip()
    return ""
rows=[]
for b in blocks:
    typ=f(b,"Check Type")
    if typ not in ("recovery","removal"): continue
    beg=f(b,"Begin Point"); end=f(b,"End Point")
    if ("O_video_locked_reg_syn_8" in beg) and ("u_w24_d1024_fifo" in end) and (".sr" in end):
        rows.append({
            "line":b["line"], "slack":f(b,"Slack"), "type":typ, "process":f(b,"Process"),
            "begin":beg.split(" (")[0], "end":end.split(" (")[0],
            "data_delay":f(b,"Data Path Delay"), "clock_skew":f(b,"Clock Skew"),
            "required":f(b,"Required"), "arrival":f(b,"Arrival"),
        })
print("TARGET_PATHS",len(rows))
for r in rows:
    print(json.dumps(r))
# summary min slack numeric
def ns(s):
    m=re.search(r"(-?\d+\.?\d*)",s); return float(m.group(1)) if m else None
g=collections.defaultdict(list)
for r in rows:
    g[(r["type"],r["process"])].append(ns(r["slack"]))
print("SUMMARY")
for k,v in sorted(g.items()):
    print(k,"count",len(v),"min",min(v),"max",max(v))
json.dump(rows,open("A_locked_fifo_sr_paths.json","w"),indent=1)
