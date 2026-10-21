import sys, re
p = sys.argv[1]
keys = sys.argv[2:]
t = open(p, encoding="utf-8", errors="replace").read().splitlines()
for k in keys:
    idx = [i for i, l in enumerate(t) if k in l]
    print("==== KEY", k, "count", len(idx))
    for i in idx[:12]:
        lo = max(0, i-4); hi = min(len(t), i+12)
        print("---- line", i+1)
        for j in range(lo, hi):
            print("%6d %s" % (j+1, t[j]))
