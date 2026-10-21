import hashlib, os, struct

HF = r'D:\FPGA\EG4S20-NoBot\output\hardware\no_bot_20261019T140608Z\card_before\files'
NB = r'D:\FPGA\EG4S20-NoBot\output\html_fidelity\no_bot\media'
IMG = r'D:\FPGA\EG4S20-Multimedia-Signage\output\html_fidelity\card_images\unified_003adc1b.img'
IMG_V2 = r'D:\FPGA\EG4S20-Multimedia-Signage\output\html_fidelity\card_images\unified_003adc1b_v2.img'

def rd(p, off, n):
    with open(p,'rb') as f:
        f.seek(off); return f.read(n)

print('--- correct pixel comparison (HFXL pixel_offset vs NoBot 512) ---')
for i in range(1,7):
    p = os.path.join(HF, 'UI%02d.BMP' % i)
    nb = os.path.join(NB, 'UI%02d.BMP' % i)
    h = rd(p,0,64)
    off = struct.unpack_from('<I', h, 10)[0]
    a = rd(p, off, 921600)
    b = rd(nb, 512, 921600)
    print('UI%02d pixel_offset=%6d  pixels_equal=%s  hfxl_pix=%s' % (
        i, off, a==b, hashlib.sha256(a).hexdigest()[:16]))

print()
print('--- differing sectors v1 vs v2 ---')
a = rd(IMG,0,16*1024*1024); b = rd(IMG_V2,0,16*1024*1024)
for s in (1065472, 12732416):
    x, y = a[s:s+512], b[s:s+512]
    idx = [k for k in range(512) if x[k]!=y[k]]
    print('LBA %d differs at %d bytes: %s' % (s//512, len(idx), idx[:16]))
    print('  v1:', x[:112].hex())
    print('  v2:', y[:112].hex())

print()
print('--- NoBot media identity vs physical card_before WAV ---')
w1 = os.path.join(HF,'07_MUSIC.WAV'); w2 = os.path.join(NB,'07_MUSIC.WAV')
def sha(p):
    h=hashlib.sha256()
    with open(p,'rb') as f:
        for c in iter(lambda:f.read(1<<20), b''): h.update(c)
    return h.hexdigest()
print('card_before WAV sha', sha(w1))
print('nobot media WAV sha', sha(w2), 'equal', sha(w1)==sha(w2))
