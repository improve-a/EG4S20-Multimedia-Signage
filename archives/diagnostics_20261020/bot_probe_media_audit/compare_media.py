import hashlib, os, struct

HF = r'D:\FPGA\EG4S20-NoBot\output\hardware\no_bot_20261019T140608Z\card_before\files'
NB = r'D:\FPGA\EG4S20-NoBot\output\html_fidelity\no_bot\media'
IMG = r'D:\FPGA\EG4S20-Multimedia-Signage\output\html_fidelity\card_images\unified_003adc1b.img'
IMG_V2 = r'D:\FPGA\EG4S20-Multimedia-Signage\output\html_fidelity\card_images\unified_003adc1b_v2.img'

def sha(p):
    h = hashlib.sha256()
    with open(p,'rb') as f:
        for b in iter(lambda: f.read(1<<20), b''):
            h.update(b)
    return h.hexdigest()

def field(b, off, n=512):
    with open(b,'rb') as f:
        f.seek(off); return f.read(n)

print('--- HFXL loose files (card_before) ---')
for i in range(1,7):
    p = os.path.join(HF, 'UI%02d.BMP' % i)
    d = field(p, 0, 128)
    setid = struct.unpack_from('<I', d, 104)[0]
    print('UI%02d.BMP size=%9d sha=%s magic=%s page=%d setid=0x%x hfxl_scene=%d' % (
        i, os.path.getsize(p), sha(p), d[80:84].decode('latin1'), d[100]&7, setid,
        ((d[89]>>1)|((d[90]&0x1f)<<7))*512))

print()
print('--- byte compare: HFXL page files vs image slices vs NoBot plain BMPs ---')
def cmp_img(img, lba, path, n=921600, off=512):
    with open(img,'rb') as f:
        f.seek(lba*512 + off)
        a = f.read(n)
    with open(path,'rb') as f:
        f.seek(off)
        b = f.read(n)
    return hashlib.sha256(a).hexdigest(), hashlib.sha256(b).hexdigest(), a == b

lbas = [2081, 6032, 10751, 15420, 20145, 24868]
for i in range(1,7):
    hf = os.path.join(HF, 'UI%02d.BMP' % i)
    nb = os.path.join(NB, 'UI%02d.BMP' % i)
    ha, hb, eq = cmp_img(IMG, lbas[i-1], hf)
    hc = sha(nb)
    same_pix = None
    with open(hf,'rb') as f:
        f.seek(512); x = f.read(921600)
    with open(nb,'rb') as f:
        f.seek(512); y = f.read(921600)
    same_pix = (x == y)
    print('page%d  img_slice==loose_hfxl:%s   hfxl_pixels==nobot_pixels:%s' % (i, eq, same_pix))
    print('        hfxl_pix_sha=%s' % ha)
    print('        nobot_pix_sha=%s' % hc)

print()
print('--- whole-file identities ---')
for i in range(1,7):
    hf = os.path.join(HF,'UI%02d.BMP'%i)
    nb = os.path.join(NB,'UI%02d.BMP'%i)
    print('UI%02d  hfxl_bytes=%9d nobot_bytes=%9d  identical_files=%s' % (
        i, os.path.getsize(hf), os.path.getsize(nb), sha(hf)==sha(nb)))

print()
print('--- v1 vs v2 image diff (first 16MiB) ---')
with open(IMG,'rb') as f: a=f.read(16*1024*1024)
with open(IMG_V2,'rb') as f: b=f.read(16*1024*1024)
diffs=[i for i in range(0,len(a),512) if a[i:i+512]!=b[i:i+512]]
print('differing 512B sectors in first 16MiB:', len(diffs), 'first:', diffs[:8])
