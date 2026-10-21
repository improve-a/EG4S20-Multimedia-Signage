import sys, json
for p in sys.argv[1:]:
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
    total=len(blocks); rec=rem=0; target=0
    for b in blocks:
        typ=f(b,"Check Type")
        if typ in ("recovery","removal"):
            rec += typ=="recovery"; rem += typ=="removal"
            beg=f(b,"Begin Point"); end=f(b,"End Point")
            if "O_video_locked_reg_syn_8" in beg and "u_w24_d1024_fifo" in end and ".sr" in end:
                target += 1
    print(json.dumps({"file":p,"blocks":total,"recovery":rec,"removal":rem,"target_locked_to_fifo_sr":target}))
