import struct, os

IMAGES = [
 r'D:\FPGA\EG4S20-Multimedia-Signage\output\html_fidelity\card_images\unified_003adc1b.img',
 r'D:\FPGA\EG4S20-Multimedia-Signage\output\html_fidelity\card_images\unified_003adc1b_v2.img',
 r'D:\FPGA\EG4S20-Multimedia-Signage\output\hardware\hw_20261016T095019Z\card_before_first64MiB.img',
 r'D:\FPGA\EG4S20-NoBot\output\html_fidelity\no_bot\media\no_bot_fat32.img',
 r'D:\FPGA\EG4S20-NoBot\output\hardware\no_bot_20261019T140608Z\card_deployed\post_unlock64MiB.img',
]

def hdr(b):
    (sig, fsize, r1, r2, off) = struct.unpack_from('<2sIHHI', b, 0)
    dib = struct.unpack_from('<I', b, 14)[0]
    w, h, planes, bpp = struct.unpack_from('<iiHH', b, 18)
    comp = struct.unpack_from('<I', b, 30)[0]
    return sig, fsize, off, dib, w, h, planes, bpp, comp

def hfxl(b):
    if b[80:84] != b'HFXL':
        return None
    scene_sector = (b[89] >> 1) | ((b[90] & 0x1f) << 7)
    payload_blocks = (b[93] >> 2) | ((b[94] & 0x3f) << 6)
    base_blocks = b[97] | ((b[98] & 0x1f) << 8)
    page = b[100] & 0x7
    set_id = struct.unpack_from('<I', b, 104)[0]
    return dict(scene_sector=scene_sector, scene_offset=scene_sector*512,
                payload_blocks=payload_blocks, payload_bytes=payload_blocks*1024,
                base=base_blocks*256, words_hint=payload_blocks*256 if False else None,
                page=page, set_id=hex(set_id))

for path in IMAGES:
    print('='*100)
    print(path)
    if not os.path.exists(path):
        print('  MISSING'); continue
    with open(path, 'rb') as f:
        data = f.read(16*1024*1024)  # first 16 MiB only
    print('  scanned bytes:', len(data))
    hits = []
    for s in range(0, len(data)-512, 512):
        b = data[s:s+512]
        if b[0:2] == b'BM':
            try:
                h = hdr(b)
            except Exception:
                continue
            hits.append((s//512, h, hfxl(b)))
    print('  BM headers found:', len(hits))
    for lba, h, x in hits[:14]:
        sig, fsize, off, dib, w, hh, planes, bpp, comp = h
        line = '  LBA %8d size=%9d off=%7d dib=%d %dx%d planes=%d bpp=%d comp=%d' % (
            lba, fsize, off, dib, w, hh, planes, bpp, comp)
        if x:
            line += '\n              HFXL page=%d set_id=%s scene_off=%d payload=%d base=%d' % (
                x['page'], x['set_id'], x['scene_offset'], x['payload_bytes'], x['base'])
        else:
            line += '\n              no HFXL locator'
        print(line)
    if hits:
        print('  HFXL count:', sum(1 for _,_,x in hits if x), 'of', len(hits))
        for lba,h,x in hits:
            if x:
                sig, fsize, off, dib, w, hh, planes, bpp, comp = h
                ok = (fsize == x['scene_offset'] + x['payload_bytes'])
                print('    page %d file_len %d vs scene+payload %d -> %s' % (
                    x['page'], fsize, x['scene_offset']+x['payload_bytes'], 'OK' if ok else 'MISMATCH'))
