#!/usr/bin/env python3
"""Deterministic contiguous-sector BMP/WAV integration card, standard library."""
import pathlib,struct,json,hashlib
root=pathlib.Path(__file__).resolve().parent
bmp0=bytes.fromhex(''.join((root/'scale_card_1.hex').read_text().split()))
bmp1=bytes.fromhex(''.join((root/'scale_card_0.hex').read_text().split()))
assert len(bmp0)==339*512 and len(bmp1)==451*512
frames=6000
pcm=bytearray()
for n in range(frames):pcm.extend(struct.pack('<hh',-25000+(n%997)*41,22000-(n%991)*43))
wave=b'RIFF'+struct.pack('<I',36+len(pcm))+b'WAVEfmt '+struct.pack('<IHHIIHH',16,1,2,48000,192000,4,16)+b'data'+struct.pack('<I',len(pcm))+pcm
wave+=bytes((-len(wave))%512)
card=bmp0+bmp1+bytes((800-790)*512)+wave
assert len(card)==847*512
out=root/'media_integration_card.hex';out.write_text(''.join(f'{b:02x}\n' for b in card))
(root/'media_integration_vectors.json').write_text(json.dumps({'card_bytes':len(card),'card_sectors':847,'bmp0':{'lba':0,'source':[320,180],'golden':'tests/scale_golden_1.hex'},'bmp1':{'lba':339,'source':[320,240],'golden':'tests/scale_golden_0.hex'},'wav':{'lba':800,'frames':frames,'channels':2,'rate':48000,'bits':16},'raw_card_sha256':hashlib.sha256(card).hexdigest()},indent=2)+'\n')
