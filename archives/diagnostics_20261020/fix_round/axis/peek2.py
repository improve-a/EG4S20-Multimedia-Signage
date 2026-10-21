import sys
t = open(sys.argv[1], encoding="utf-8", errors="replace").read()
for n in sys.argv[2:]:
    i = t.find(n)
    print("----", n, i)
    if i >= 0:
        print(t[max(0, i-200):i+1800])
