# Export explicit-width binary init files for TD EG_LOGIC_BRAM INIT_FILE.
# The TD macro reader treats the supplied raw init format as binary. Simulation
# retains the source hexadecimal file; round-trip equality is checked here.
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[1]

def generate(root=ROOT):
    results=[]
    for name,count in [("bot_body_argb4444.hex",10400),("html_glyph_coverage.hex",9120)]:
        source=Path(root)/"rtl/ext/html_assets"/name
        words=[int(x,16) for x in source.read_text().split()]
        assert len(words)==count and all(0<=x<65536 for x in words),name
        text="".join(format(x,"016b")+"\n" for x in words)
        assert [int(x,2) for x in text.split()]==words
        dest=source.with_name(source.name+".bin");dest.write_bytes(text.encode("ascii"))
        results.append(dict(path=str(dest),words=count,source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),sha256=hashlib.sha256(dest.read_bytes()).hexdigest()))
    return results

if __name__=="__main__":print(json.dumps(generate(),indent=2))
