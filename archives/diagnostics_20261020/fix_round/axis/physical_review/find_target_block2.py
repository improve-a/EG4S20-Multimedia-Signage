import sys
p=sys.argv[1]; begneedle=sys.argv[2]; endneedle=sys.argv[3]; typneedle=sys.argv[4]
t=open(p,encoding="utf-8",errors="replace").read().splitlines()
blocks=[]; cur=None
for i,l in enumerate(t):
    if l.startswith("Slack               :"):
        if cur: blocks.append(cur)
        cur={"line":i+1,"lines":[l]}
    elif cur is not None:
        cur["lines"].append(l)
if cur: blocks.append(cur)
for b in blocks:
    txt="\n".join(b["lines"])
    if begneedle in txt and endneedle in txt and ("Check Type          : "+typneedle) in txt:
        print("\n".join(b["lines"][:110])); print("=== END",b["line"]); break
