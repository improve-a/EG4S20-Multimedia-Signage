"""Large contiguous stereo WAV card for shared-reader bandwidth simulation."""
from pathlib import Path
import struct,json
r=Path(__file__).parent
frames=2304
pcm=b''.join(struct.pack('<hh',-30000+(i%600)*97,25000-(i%500)*83) for i in range(frames))
def chunk(tag,data):return tag+struct.pack('<I',len(data))+data+(b'\0' if len(data)&1 else b'')
fmt=struct.pack('<HHIIHH',1,2,48000,192000,4,16)
body=b'WAVE'+chunk(b'fmt ',fmt)+chunk(b'JUNK',bytes(513))+chunk(b'data',pcm)
file=b'RIFF'+struct.pack('<I',len(body))+body
card=bytes(1024)+file;card+=bytes((-len(card))%512)
(r/'audio_arbiter_card.hex').write_text(''.join(f'{b:02x}\n' for b in card))
(r/'audio_arbiter_vectors.json').write_text(json.dumps(dict(frames=frames,card_bytes=len(card),wav_bytes=len(file),file_start_lba=2,file_sectors=(len(file)+511)//512),indent=2))
