import sys
t = open(sys.argv[1], encoding="utf-8", errors="replace").read()
for n in sys.argv[2:]:
    key = "\\" + n + " ("
    i = t.find(key)
    print("----", n, i)
    if i >= 0:
        print(t[i:i+1600])
