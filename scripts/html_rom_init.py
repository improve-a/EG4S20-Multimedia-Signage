# Export explicit-width binary init files for TD EG_LOGIC_BRAM INIT_FILE.
# The TD macro reader treats the supplied raw init format as binary. Simulation
# retains the source hexadecimal file; round-trip equality is checked here.
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[1]

def generate(root=ROOT):
    results=[]
    specs=[("bot_body_argb4444.hex",10400,16),("html_glyph_coverage.hex",9120,16)]
    if (Path(root)/"rtl/ext/html_assets/html_caption_columns.hex").exists():
        specs.append(("html_caption_columns.hex",8114,18))
    # Every optional layer/animation resource keeps simulation hex and TD binary
    # initialization numerically identical in the immutable build snapshot.
    optional=[("html_eye_radius.hex",1024,9),
              ("html_osd_swap_palette.hex",576,8),
              ("html_motion_alpha_scale.hex",1536,16),
              ("html_motion_offset.hex",1536,16),
              ("html_layer_palette.hex",3072,24),
              ("html_layer_palette_r.hex",3072,8),
              ("html_layer_palette_g.hex",3072,8),
              ("html_layer_palette_b.hex",3072,8),
              ("html_layer_headers.hex",96,32),
              ("html_layer_descriptors.hex",768,32),
              ("html_layer_descriptors16.hex",1536,16)]
    specs.extend(spec for spec in optional if (Path(root)/"rtl/ext/html_assets"/spec[0]).exists())
    for name,count,width in specs:
        source=Path(root)/"rtl/ext/html_assets"/name
        words=[int(x,16) for x in source.read_text().split()]
        assert len(words)==count and all(0<=x<(1<<width) for x in words),name
        text="".join(format(x,"0"+str(width)+"b")+"\n" for x in words)
        assert [int(x,2) for x in text.split()]==words
        dest=source.with_name(source.name+".bin");dest.write_bytes(text.encode("ascii"))
        results.append(dict(path=str(dest),words=count,source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),sha256=hashlib.sha256(dest.read_bytes()).hexdigest()))
    return results

if __name__=="__main__":print(json.dumps(generate(),indent=2))
