"""Save source provenance and readable official-to-work-copy diffs; does not run EDA."""
import difflib,hashlib,json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
base=root/'reference/official/lab_ex4_tf/src/user_source/hdl_source'
files=['SD/sd_card_top.v','SD/sd_card_cmd.v','SD/sd_card_sec_read_write.v','SD/bmp_read.v','SD/frame_read_write.v','SD/frame_fifo_read.v','SD/frame_fifo_write.v','SD/video_timing_data.v','video_rgb_to_axis_640x480.v']
manifest=[];diff=[]
for rel in files:
 a=(base/rel).read_bytes();b=(root/'rtl'/rel).read_bytes()
 manifest.append({'file':rel,'official_sha256':hashlib.sha256(a).hexdigest(),'work_sha256':hashlib.sha256(b).hexdigest(),'modified':a!=b})
 diff.extend(difflib.unified_diff(a.decode().splitlines(True),b.decode().splitlines(True),fromfile='official/'+rel,tofile='rtl/'+rel))
(root/'reports/storage_source_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
(root/'reports/storage_changes.diff').write_text(''.join(diff))
print('saved',len(manifest),'source provenance entries')
