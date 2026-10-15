"""Deterministic WAV and raw-card vectors; stdlib only, no FAT assumptions."""
import pathlib,struct
root=pathlib.Path(__file__).parent
def chunk(tag,data):return tag+struct.pack('<I',len(data))+data+(b'\0' if len(data)&1 else b'')
def wav(channels,rate=48000,extra=b'',frames=300):
    pcm=b''.join(struct.pack('<hh',-30000+i*97,25000-i*83) if channels==2 else struct.pack('<h',-30000+i*97) for i in range(frames))
    fmt=struct.pack('<HHIIHH',1,channels,rate,rate*channels*2,channels*2,16)
    body=b'WAVE'+chunk(b'fmt ',fmt)+extra+chunk(b'data',pcm)
    return b'RIFF'+struct.pack('<I',len(body))+body
stereo=wav(2,extra=chunk(b'JUNK',bytes(513)))
mono=wav(1,frames=100)
bad_rate=wav(2,rate=44100)
bad_size=bytearray(wav(2));bad_size[40:44]=struct.pack('<I',65536)
for name,data in [('stereo',stereo),('mono',mono),('bad_rate',bad_rate),('bad_size',bad_size)]:
    (root/f'audio_{name}.hex').write_text(''.join(f'{b:02x}\n' for b in data))
card=bytes(1024)+stereo
card+=bytes((-len(card))%512)
card_mono=bytes(1024)+mono
card_mono+=bytes(3072-len(card_mono))
boundary=wav(1,extra=chunk(b'JUNK',bytes(458)),frames=1)
assert len(boundary)==512
card_boundary=bytes(1024)+boundary
card_boundary+=bytes(3072-len(card_boundary))
(root/'audio_card_boundary.hex').write_text(''.join(f'{b:02x}\n' for b in card_boundary))
card_short=bytes(1024)+wav(1,frames=1)
card_short+=bytes(3072-len(card_short))
(root/'audio_card_short.hex').write_text(''.join(f'{b:02x}\n' for b in card_short))
(root/'audio_card_mono.hex').write_text(''.join(f'{b:02x}\n' for b in card_mono))
(root/'audio_card.hex').write_text(''.join(f'{b:02x}\n' for b in card))
(root/'audio_vectors.json').write_text(__import__('json').dumps(dict(stereo_bytes=len(stereo),mono_bytes=len(mono),card_bytes=len(card)),indent=2))
