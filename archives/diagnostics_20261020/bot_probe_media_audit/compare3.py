import hashlib, os
CB = r'D:\FPGA\EG4S20-NoBot\output\hardware\no_bot_20261019T140608Z\card_before\first64MiB.bin'
I1 = r'D:\FPGA\EG4S20-Multimedia-Signage\output\html_fidelity\card_images\unified_003adc1b.img'
I2 = r'D:\FPGA\EG4S20-Multimedia-Signage\output\html_fidelity\card_images\unified_003adc1b_v2.img'
def sha(p):
    h=hashlib.sha256()
    with open(p,'rb') as f:
        for c in iter(lambda:f.read(1<<20),b''): h.update(c)
    return h.hexdigest()
a=sha(CB); print('card_before/first64MiB.bin', a, os.path.getsize(CB))
for p in (I1,I2):
    b=sha(p); print(os.path.basename(p), b, 'MATCH' if a==b else 'differs')
# sector-level diff counts
with open(CB,'rb') as f: x=f.read()
for p in (I1,I2):
    with open(p,'rb') as f: y=f.read(64*1024*1024)
    d=sum(1 for i in range(0,len(x),512) if x[i:i+512]!=y[i:i+512])
    print('differing sectors vs', os.path.basename(p), d)
