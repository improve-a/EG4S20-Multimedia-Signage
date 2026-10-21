import sys
p=sys.argv[1]; needle=sys.argv[2]
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
    if needle in txt:
        print("\n".join(b["lines"][:120]))
        print("=== END BLOCK at line", b["line"])
        break
