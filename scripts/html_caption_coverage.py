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


def correct_current(data):
    old = "静态功耗低至 5 mA"
    new = "静态电流低至 5 mA"
    layouts = [layout for layout in data["all"] if layout["page"] == 1 and layout["dual"] == 0]
    if len(layouts) != 1 or old not in layouts[0]["text"]:
        raise ValueError("expected one Eagle current caption")
    layout = layouts[0]
    font = data["glyphs"][68]["font"]
    electric = next(i for i,g in enumerate(data["glyphs"]) if g["ch"] == "电" and g["font"] == font)
    if any(g["ch"] == "流" and g["font"] == font for g in data["glyphs"]):
        raise ValueError("new glyph unexpectedly exists")
    flow = len(data["glyphs"])
    if flow != 228:
        raise ValueError("review append-only glyph address")
    data["glyphs"].append(dict(ch="流", font=font, alpha=[0]*320))
    for run in layout["runs"]:
        if run["caption"] and run["i"] in (32,33):
            run["id"] = electric if run["i"] == 32 else flow
    layout["text"] = layout["text"].replace(old,new)
    return flow


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--layout", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--css", required=True, nargs="+", type=Path)
    parser.add_argument("--map", type=Path, help="Existing generated map; required for current wording correction")
    parser.add_argument("--correct-current", action="store_true", help="Correct mA caption power to current, append flow glyph228")
    parser.add_argument("--chrome", default="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
    args = parser.parse_args()
    css = "\n".join(path.read_text(encoding="utf-8") for path in args.css)
    if "#ede9e2" not in css.lower() or "color:#1a1916" not in css.lower():
        raise ValueError("prototype ink/paper colors require review")
    data = json.loads(args.layout.read_text(encoding="utf-8"))
    if args.correct_current and args.map is None:
        parser.error("--correct-current requires --map to preserve exact existing layout")
    new_glyph_id = correct_current(data) if args.correct_current else None
    original = rom_bytes(data["glyphs"])
    selected = [dict(id=index, ch=glyph["ch"], font=glyph["font"])
                for index, glyph in enumerate(data["glyphs"])
                if glyph["font"].startswith("400 12.5px ") and (new_glyph_id is None or index == new_glyph_id)]
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
 ctx.clearRect(0,0,16,20);ctx.fillStyle='#fff';ctx.fillText(glyph.ch,0,13);
 let whiteAlpha=Array.from(ctx.getImageData(0,0,16,20).data).filter((v,i)=>i%4===3).map(v=>Math.round(v*3/255));
 result.push({id:glyph.id,ch:glyph.ch,font:glyph.font,alpha,rgba,whiteAlpha});
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
    if new_glyph_id is not None:
        original_glyphs=json.loads(args.layout.read_text(encoding="utf-8"))["glyphs"]
        new_sample=next(g for g in samples if g["id"]==new_glyph_id)
        original_glyphs.append(dict(ch=new_sample["ch"],font=new_sample["font"],alpha=new_sample["whiteAlpha"]))
        original=rom_bytes(original_glyphs)
        (args.out / "original_glyph_coverage.hex").write_bytes(original)
    changed = 0
    for glyph in samples:
        previous = data["glyphs"][glyph["id"]]
        if (previous["ch"], previous["font"]) != (glyph["ch"], glyph["font"]):
            raise ValueError("glyph identity changed")
        changed += sum(a != b for a, b in zip(previous["alpha"], glyph["alpha"]))
        previous["alpha"] = glyph["alpha"]
    target = args.out / "html_glyph_coverage.hex"
    target.write_bytes(rom_bytes(data["glyphs"]))
    if args.correct_current:
        source_map=args.map.read_text(encoding="utf-8")
        lines=source_map.splitlines(keepends=True)
        current=None; changes=[]
        for index,line in enumerate(lines):
            match=re.match(r"4'd(\d+): begin total_chars",line)
            if match: current=int(match.group(1))
            if current==1 and "char_index=7'd32;" in line:
                if "glyph_id=8'd68;" not in line: raise ValueError("power glyph32 mismatch")
                lines[index]=line.replace("glyph_id=8'd68;","glyph_id=8'd122;");changes.append(32)
            if current==1 and "char_index=7'd33;" in line:
                if "glyph_id=8'd69;" not in line: raise ValueError("power glyph33 mismatch")
                lines[index]=line.replace("glyph_id=8'd69;","glyph_id=8'd228;");changes.append(33)
        if changes != [32,33]: raise ValueError("expected exactly two map edits")
        (args.out/"html_caption_map.v").write_bytes("".join(lines).encode("utf-8"))
        target.with_suffix(".hex.bin").write_bytes("".join(f"{int(word,16):016b}\n" for word in target.read_text().split()).encode("ascii"))
    (args.out / "caption_layout_darkpaper.json").write_bytes(json.dumps(data, ensure_ascii=False, indent=2).encode("utf-8"))
    (args.out / "source_rgb_samples.json").write_bytes(json.dumps(samples, ensure_ascii=False).encode("utf-8"))
    version = subprocess.run([args.chrome, "--version"], capture_output=True, text=True, check=True).stdout.strip()
    report = {"state": "CAPTION_COVERAGE_GENERATED", "chrome_version": version,
              "input_layout_sha256": sha(args.layout),
              "source_css_sha256": {str(path): sha(path) for path in args.css},
              "original_atlas_sha256": hashlib.sha256(original).hexdigest(),
              "candidate_atlas_sha256": sha(target), "glyph_count": len(data["glyphs"]),
              "word_count": len(data["glyphs"]) * 40, "current_wording_correction": args.correct_current, "appended_glyph_id": new_glyph_id, "caption_glyph_count": len(samples),
              "changed_coverage_pixels": changed, "palette": palette,
              "scope": "Only400/12.5px caption glyph coverage changes; optional explicit mA power-to-current correction appends glyph228 and swaps Eagle caption ordinals32/33, preserving positions/reveal timing. Source ink/paper RGB sampled directly; nearest existing thirds palette, ties lower. Existing IDs, coverage and dimensions are preserved in wording-correction mode; only two glyph references and one appended glyph change. RTL pipeline is unchanged; GLYPH_WORDS must be9160 for the appended glyph. This generates assets, never DUT frames."}
    (args.out / "verification.json").write_bytes(json.dumps(report, indent=2).encode("utf-8"))
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
