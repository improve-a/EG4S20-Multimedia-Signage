import re
import sys

path = sys.argv[1]
pat = sys.argv[2]
text = open(path, encoding="utf-8", errors="replace").read()
for m in re.finditer(r"\b" + pat + r"\b[^;]*;", text):
    print(m.group(0)[:2000])
    print("-" * 20)
    break
