"""Regenerate caption coverage from source ink on paper, retaining glyph layout.

The original white-on-transparent canvas mask is preserved as a separate ROM.
Chrome text rasterization depends on ink/background colors; its white mask is
not the linear-RGB coverage of dark text on the prototype's paper background.
"""
import argparse
import hashlib
import html
import json
import re
import subprocess
from pathlib import Path


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rom_bytes(glyphs):
    words = []
    for glyph in glyphs:
        if len(glyph["alpha"]) != 320:
            raise ValueError("glyph dimensions changed")
        for offset in range(0, 320, 8):
            word = 0
            for coverage in glyph["alpha"][offset:offset + 8]:
                if coverage not in range(4):
                    raise ValueError("coverage exceeds two bits")
                word = (word << 2) | coverage
            words.append(f"{word:04x}\n")
    return "".join(words).encode("ascii")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--layout", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--css", required=True, nargs="+", type=Path)
    parser.add_argument("--chrome", default="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
    args = parser.parse_args()
    css = "\n".join(path.read_text(encoding="utf-8") for path in args.css)
    if "#ede9e2" not in css.lower() or "color:#1a1916" not in css.lower():
        raise ValueError("prototype ink/paper colors require review")
    data = json.loads(args.layout.read_text(encoding="utf-8"))
    original = rom_bytes(data["glyphs"])
    selected = [dict(id=index, ch=glyph["ch"], font=glyph["font"])
                for index, glyph in enumerate(data["glyphs"])
                if glyph["font"].startswith("400 12.5px ")]
    if not selected:
        raise ValueError("source caption font was not found")
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / "original_glyph_coverage.hex").write_bytes(original)
    # Existing RTL interprets coverage codes as exact 0, 1/3, 2/3, 1.
    palette = [[(foreground * code + background * (3 - code) + 1) // 3
                for foreground, background in zip((26, 25, 22), (237, 233, 226))]
               for code in range(4)]
    script = r'''<!doctype html><meta charset="utf-8"><body><script>
const glyphs=GLYPHS,colors=COLORS,result=[];
let canvas=document.createElement('canvas');canvas.width=16;canvas.height=20;
let ctx=canvas.getContext('2d');
for(let glyph of glyphs){
 ctx.fillStyle='#ede9e2';ctx.fillRect(0,0,16,20);
 ctx.font=glyph.font;ctx.textBaseline='alphabetic';ctx.fillStyle='#1a1916';
 ctx.fillText(glyph.ch,0,13);
 let rgba=Array.from(ctx.getImageData(0,0,16,20).data),alpha=[];
 for(let pixel=0;pixel<320;pixel++){
  let best=0,error=1e9;
  for(let code=0;code<4;code++){
   let candidate=colors[code].reduce((sum,value,channel)=>sum+Math.abs(value-rgba[pixel*4+channel]),0);
   if(candidate<error){best=code;error=candidate;}
  }
  alpha.push(best);
 }
 result.push({id:glyph.id,ch:glyph.ch,font:glyph.font,alpha,rgba});
}
document.body.innerHTML='<pre id="export">'+JSON.stringify(result)+'</pre>';
</script>'''
    script = script.replace("GLYPHS", json.dumps(selected, ensure_ascii=True).replace("<", "\\u003c"))
    script = script.replace("COLORS", json.dumps(palette))
    page = args.out / "caption_dark_paper_export.html"
    page.write_bytes(script.encode("utf-8"))
    command = [args.chrome, "--headless", "--disable-gpu", "--no-first-run",
               "--user-data-dir=" + str((args.out / "chrome_profile").resolve()),
               "--dump-dom", page.resolve().as_uri()]
    process = subprocess.run(command, capture_output=True, text=True, timeout=60)
    (args.out / "chrome.stderr").write_bytes(process.stderr.encode("utf-8"))
    process.check_returncode()
    match = re.search(r'<pre id="export">(.*?)</pre>', process.stdout, re.S)
    if not match:
        raise ValueError("browser did not export source glyph samples")
    samples = json.loads(html.unescape(match[1]))
    changed = 0
    for glyph in samples:
        previous = data["glyphs"][glyph["id"]]
        if (previous["ch"], previous["font"]) != (glyph["ch"], glyph["font"]):
            raise ValueError("glyph identity changed")
        changed += sum(a != b for a, b in zip(previous["alpha"], glyph["alpha"]))
        previous["alpha"] = glyph["alpha"]
    target = args.out / "html_glyph_coverage.hex"
    target.write_bytes(rom_bytes(data["glyphs"]))
    (args.out / "caption_layout_darkpaper.json").write_bytes(json.dumps(data, ensure_ascii=False, indent=2).encode("utf-8"))
    (args.out / "source_rgb_samples.json").write_bytes(json.dumps(samples, ensure_ascii=False).encode("utf-8"))
    version = subprocess.run([args.chrome, "--version"], capture_output=True, text=True, check=True).stdout.strip()
    report = {"state": "CAPTION_COVERAGE_GENERATED", "chrome_version": version,
              "input_layout_sha256": sha(args.layout),
              "source_css_sha256": {str(path): sha(path) for path in args.css},
              "original_atlas_sha256": hashlib.sha256(original).hexdigest(),
              "candidate_atlas_sha256": sha(target), "glyph_count": len(data["glyphs"]),
              "word_count": len(data["glyphs"]) * 40, "caption_glyph_count": len(samples),
              "changed_coverage_pixels": changed, "palette": palette,
              "scope": "Only400/12.5px caption glyph coverage changes. Source ink/paper RGB sampled directly; nearest existing thirds palette, ties lower. IDs, dimensions, layout, baseline and RTL unchanged. This generates assets, never DUT frames."}
    (args.out / "verification.json").write_bytes(json.dumps(report, indent=2).encode("utf-8"))
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
