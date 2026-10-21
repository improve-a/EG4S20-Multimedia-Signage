import sys, re
t = open(sys.argv[1], encoding="utf-8", errors="replace").read()
need = sys.argv[2]
for m in re.finditer(re.escape(need), t):
    i = m.start()
    print("---- at", i)
    print(t[max(0, i-500):i+700])
    print()
