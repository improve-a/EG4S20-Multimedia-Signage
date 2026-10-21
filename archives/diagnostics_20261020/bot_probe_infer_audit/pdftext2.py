import sys
sys.path.insert(0,'_libs')
from pypdf import PdfReader
p=sys.argv[1]
r=PdfReader(p)
out=[]
for i,pg in enumerate(r.pages,1):
    try: t=pg.extract_text() or ''
    except Exception as e: t=''
    out.append(f"\n===== PAGE {i} =====\n"+t)
sys.stdout.write(''.join(out))
