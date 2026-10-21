import hashlib, os
CB = r'D:\FPGA\EG4S20-NoBot\output\hardware\no_bot_20261019T140608Z\card_before\files'
I1 = r'D:\FPGA\EG4S20-Multimedia-Signage\output\html_fidelity\card_images\unified_003adc1b.img'
I2 = r'D:\FPGA\EG4S20-Multimedia-Signage\output\html_fidelity\card_images\unified_003adc1b_v2.img'
lbas=[2081,6032,10751,15420,20145,24868]
sizes=[2022912,2416128,2390528,2419200,2418176,2080256]
def sha_bytes(b): return hashlib.sha256(b).hexdigest()
for i in range(6):
    p=os.path.join(CB,'UI%02d.BMP'%(i+1))
    d=open(p,'rb').read()
    s=sha_bytes(d)
    with open(I1,'rb') as f: f.seek(lbas[i]*512); a=f.read(sizes[i])
    with open(I2,'rb') as f: f.seek(lbas[i]*512); b=f.read(sizes[i])
    pad = d[54:512]
    print('UI%02d card=%s v1=%s v2=%s  54..511_all_zero=%s' % (
        i+1, s[:12], 'MATCH' if s==sha_bytes(a) else 'no', 'MATCH' if s==sha_bytes(b) else 'no', all(x==0 for x in pad)))
