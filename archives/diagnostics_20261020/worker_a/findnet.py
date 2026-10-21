import re
import sys

needle = sys.argv[1]
for path in sys.argv[2:]:
    text = open(path, encoding="utf-8", errors="replace").read()
    print("#####", path)
    n = 0
    for i, line in enumerate(text.splitlines(), 1):
        if needle in line:
            print(i, " ".join(line.split()))
            n += 1
            if n > 40:
                print("...")
                break
