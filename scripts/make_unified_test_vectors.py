#!/usr/bin/env python3
"""Generate real UI06 loader vectors without changing the source bitmap."""
import hashlib, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=ROOT/'output/venue_unified_offline/media/UI06.BMP'
b=p.read_bytes()
assert b[:2]==b'BM' and len(b)==921654
padded=b+bytes((-len(b))%512)
card=ROOT/'tests/unified_ui06_card.hex';rgb=ROOT/'tests/unified_ui06_rgb.hex'
card.write_text(''.join(f'{v:02x}\n' for v in padded))
# Inherited SDRAM WRITE_V_FLIP consumes BMP file-order bottom-up RGB pixels.
# This independent oracle converts file BGR triplets directly to RGB words.
rgb.write_text(''.join(f'{b[i+2]:02x}{b[i+1]:02x}{b[i]:02x}\n' for i in range(54,len(b),3)))
m=dict(source=str(p.relative_to(ROOT)),source_sha256=hashlib.sha256(b).hexdigest(),pixel_count=307200,oracle='file-order BGR-to-RGB; inherited WRITE_V_FLIP',vectors={str(q.relative_to(ROOT)):hashlib.sha256(q.read_bytes()).hexdigest() for q in (card,rgb)})
(ROOT/'tests/unified_ui06_vectors.json').write_text(json.dumps(m,indent=2)+'\n')
print('UI06 vectors generated; 307200 expected pixels')
