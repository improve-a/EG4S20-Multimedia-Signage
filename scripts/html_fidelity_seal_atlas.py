#!/usr/bin/env python3
"""Content-address HFXL set ID over every final payload byte with header w13 zeroed."""
import argparse,hashlib,json,struct
from pathlib import Path

def seal(root):
 m=json.loads((root/'hfxl_payload_manifest.json').read_text(encoding='utf8'));parts=[]
 for p in m['pages']:
  b=bytearray((root/p['path']).read_bytes());struct.pack_into('<I',b,52,0);parts.append(b)
 digest=hashlib.sha256(b''.join(parts)).hexdigest();setid=int(digest[:8],16)
 assert setid!=0
 for p,b in zip(m['pages'],parts):
  struct.pack_into('<I',b,52,setid);(root/p['path']).write_bytes(b);p['sha256']=hashlib.sha256(b).hexdigest()
 combined=b''.join(parts);(root/'hfxl_global_atlas.bin').write_bytes(combined);(root/'hfxl_global_atlas.hex').write_text(''.join('%08x\n'%v[0]for v in struct.iter_unpack('<I',combined)),encoding='ascii')
 evidence={'algorithm':'SHA256 over all six complete padded little-endian payloads in page_index order, each header word13 zero; set_id = integer of first 8 digest hex digits','zeroed_payload_sha256':digest,'bytes_hashed':len(combined),'covered':'all header fields except self-ID, descriptors, palette, BG indices, component RGBA, padding'}
 s=json.loads((root/'hfxl_schema.json').read_text(encoding='utf8'));s['set_id']=setid;s['set_id_derivation']=evidence;(root/'hfxl_schema.json').write_text(json.dumps(s,indent=2),encoding='utf8')
 m.update(set_id=setid,set_id_derivation=evidence,global_sha256=hashlib.sha256(combined).hexdigest(),schema_sha256=hashlib.sha256((root/'hfxl_schema.json').read_bytes()).hexdigest());(root/'hfxl_payload_manifest.json').write_text(json.dumps(m,indent=2),encoding='utf8');print(json.dumps({'set_id_hex':'%08x'%setid,**evidence}));return setid
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--layers',type=Path,required=True);seal(p.parse_args().layers)
