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
for b in blocks:
    typ=f(b,"Check Type")
    if typ not in ("recovery","removal"): continue
    beg=f(b,"Begin Point"); end=f(b,"End Point")
    hit = ("u_w24_d1024_fifo" in end and ".sr" in end) or ("O_video_locked" in beg) or ("I_rst_syn_7" in beg) or ("u_w24_d1024_fifo" in beg and ".sr" in beg)
    if hit:
        print("---- line %d slack=%s type=%s process=%s" % (b["line"],f(b,"Slack"),typ,f(b,"Process")))
        print(" Begin:",beg)
        print(" End  :",end)
