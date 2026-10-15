"""Independent integer golden model; all channels, settings, signed extrema."""
from pathlib import Path
import argparse

def adjust(pixel, brightness, contrast):
    quarters = contrast + 2 if contrast < 7 else 4
    return min(255, max(0, ((pixel - 128) * quarters) // 4 + 128 + brightness))

def main():
    ap=argparse.ArgumentParser();ap.add_argument('output');args=ap.parse_args()
    path=Path(args.output);path.parent.mkdir(parents=True,exist_ok=True)
    count=0
    with path.open('w') as f:
        for b in (-256,-255,-129,-128,-1,0,1,127,128,254,255):
            for c in range(8):
                for r in range(256):
                    channels=(r,255-r,(r*73)%256)
                    rgb=sum(p << shift for p,shift in zip(channels,(16,8,0)))
                    golden=sum(adjust(p,b,c) << shift for p,shift in zip(channels,(16,8,0)))
                    f.write(f'{rgb:06x} {b&511:03x} {c:x} {golden:06x}\n');count+=1
    print(f'{count} RGB vectors; {count*3} independent channel comparisons')
if __name__=='__main__':main()
