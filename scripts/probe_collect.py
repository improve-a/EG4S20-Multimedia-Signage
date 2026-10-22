#!/usr/bin/env python3
"""Collect final TD evidence and compare the immutable snapshot with this checkout."""
import argparse
import collections
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import zipfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def canonical(data, project=False):
    data = data.replace(b'\r\n', b'\n')
    if b'/work/design/user_source/hdl_source/ext/html_assets/' in data:
        data = re.sub(rb'[^"\s]*?/work/design/user_source/hdl_source/ext/html_assets/', b'rtl/ext/html_assets/', data)
    if project:
        data = re.sub(rb'(<Project Version="3" Minor="2" Path=")[^"]*', rb'\1SNAPSHOT', data)
    return data

def checkout_path(name):
    prefix = 'user_source/hdl_source/'
    return ROOT / ('rtl/' + name[len(prefix):] if name.startswith(prefix) else 'project/' + name)

def resources(p):
    return {k: int(v) for k, v in re.findall(r'^\s*#(lut|reg|bram9k|bram32k|dsp|pll)\s+(\d+)', p.read_text(), re.M)}

def project_semantics(data):
    # TD saves its UCode and renumbers existing CompileOrder attributes. These
    # are tool metadata, not source edits; compare every other XML field.
    tree = ET.fromstring(data.replace(b'P&R', b'P&amp;R'))
    for parent in tree.iter():
        for child in list(parent):
            if child.tag == 'UCode' or (child.tag == 'Attr' and child.get('Name') == 'CompileOrder'):
                parent.remove(child)
        if parent.text and not parent.text.strip(): parent.text = None
        if parent.tail and not parent.tail.strip(): parent.tail = None
    return ET.tostring(tree)

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('run_id')
    ap.add_argument('--baseline', type=Path, default=Path('D:/FPGA/EG4S20-NoBot-HDMIProbe/output/html_fidelity/builds/hdmi_probe_001'))
    ap.add_argument('--frozen-source', type=Path, default=Path('D:/FPGA/EG4S20-NoBot-HDMIProbe/output/hdmi_probe/delivery/hdmi_probe_001_source.zip'))
    a = ap.parse_args()
    base = ROOT / 'output/html_fidelity/builds' / a.run_id
    job = base / 'runs' / a.run_id
    spec = importlib.util.spec_from_file_location('report_parser', ROOT/'harness/report_parser.py')
    parser = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(parser)
    result = parser.parse(base, a.run_id)
    baseline = parser.parse(a.baseline, 'hdmi_probe_001')
    timing = (job/'final_timing.rpt').read_text()
    detail = collections.defaultdict(list)
    for value, kind in re.findall(r'Slack\s*:\s*(-?[\d.]+)ns(?:(?!Slack).)*?Check Type\s*:\s*(\w+)', timing, re.S):
        detail[kind.lower()].append(float(value))
    violations = [int(x) for x in re.findall(r'(\d+) Viol Endpoints', timing)]
    result.update(reported_path_min_ns={k:min(v) for k,v in detail.items()},
                  reported_path_count={k:len(v) for k,v in detail.items()},
                  listed_negative_paths={k:sum(x<0 for x in v) for k,v in detail.items()},
                  group_violation_counts=violations)
    result['STA_CONSTRAINED_PATHS_PASS'] = (bool(violations) and not any(violations)
        and all(k in detail and min(detail[k]) >= 0 for k in ('setup','hold','recovery','removal'))
        and all(result['timing'].get(k, {}).get('tns_ns', -1) == 0 for k in ('setup','hold'))
        and 'Check Corner        : Both (Slow and Fast)' in timing)
    result['FULL_INTERFACE_SIGNOFF'] = 'NOT_VERIFIED: inherited external-I/O/CDC coverage; no new constraints or exceptions.'
    before, after = resources(a.baseline/'runs/hdmi_probe_001/final_area.rpt'), resources(job/'final_area.rpt')
    result['resource_comparison'] = {k:{'baseline':before[k], 'candidate':after[k], 'delta':after[k]-before[k]} for k in before}
    result['baseline_warning_counts'] = baseline['warning_counts']
    result['baseline_critical_warnings'] = baseline['critical_warnings']
    result['timing_checks_unchanged'] = result['timing_coverage']['checks'] == baseline['timing_coverage']['checks']
    result['baseline_coverage'] = baseline['timing_coverage']
    manifest = json.loads((base/'audit/baseline_manifest.json').read_text())
    result['build_source_commit'] = manifest['git_commit']
    result['checkout_commit'] = subprocess.check_output(['git','rev-parse','HEAD'], cwd=ROOT, text=True).strip()
    verified = []
    source = ROOT/'artifacts'/(a.run_id+'_source.zip')
    with zipfile.ZipFile(source) as archive:
        project_input = archive.read('work/design/td_project/hx4s20_basic.al')
    started_inputs = {x['path']:x['sha256'] for x in json.loads((job/'inputs.json').read_text())}
    for item in manifest['selected']:
        name = item['path']
        snapshot = base/'work/design'/name
        live = checkout_path(name)
        data = snapshot.read_bytes()
        if name == 'td_project/hx4s20_basic.al':
            assert project_semantics(project_input) == project_semantics(data), 'TD changed project semantics'
            result['td_project_metadata'] = {'input_sha256':hashlib.sha256(project_input).hexdigest(),
                'after_td_sha256':sha(snapshot), 'source_list_and_settings_unchanged':True,
                'changes':'TD UCode and CompileOrder renumbering only'}
            data = project_input
        assert hashlib.sha256(data).hexdigest() == item['sha256'] == started_inputs[name], name
        assert canonical(live.read_bytes(), name.endswith('.al')) == canonical(data, name.endswith('.al')), name
        verified.append({'path':name, 'sha256':item['sha256']})
    result['verified_snapshot_inputs'] = verified
    differences = []
    with zipfile.ZipFile(a.frozen_source) as frozen:
        old = json.loads(frozen.read('audit/baseline_manifest.json'))
        for item in old['selected']:
            name = item['path']
            if name.endswith('.log'):
                continue
            data = frozen.read('work/design/'+name)
            if canonical(data, name.endswith('.al')) != canonical(checkout_path(name).read_bytes(), name.endswith('.al')):
                differences.append(name)
    result['production_changes_from_hardware_pass'] = differences
    result['classification'] = 'NEW_CANDIDATE_HARDWARE_NOT_TESTED'
    out = ROOT/'output/probe_audio_multires/delivery'/a.run_id
    out.mkdir(parents=True, exist_ok=False)
    shutil.copy2(source, out/source.name)
    result['source_archive'] = {'path':str(out/source.name), 'sha256':sha(source)}
    bit = base/'work/design/td_project/hx4s20_basic_Runs/phy_1/hx4s20_basic.bit'
    if result['BUILD_PASS']:
        target = out/(a.run_id+'_NEW_CANDIDATE_HARDWARE_NOT_TESTED.bit')
        shutil.copy2(bit, target)
        result['candidate_bit'] = {'path':str(target), 'bytes':target.stat().st_size, 'sha256':sha(target)}
    archive = out/(a.run_id+'_reports.zip')
    with zipfile.ZipFile(archive, 'x', zipfile.ZIP_DEFLATED) as z:
        for p in job.iterdir():
            if p.is_file() and p.suffix in ('.rpt','.log','.json','.tsv','.tcl'):
                z.write(p, 'build/'+p.name)
        for stage in ('syn_1','phy_1'):
            p = base/'work/design/td_project/hx4s20_basic_Runs'/stage/'run.log'
            z.write(p, 'build/'+stage+'_run.log')
        z.write(base/'audit/baseline_manifest.json','audit/build_source_manifest.json')
    result['reports_archive'] = {'path':str(archive), 'sha256':sha(archive)}
    (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
    print(json.dumps({k:result[k] for k in ('BUILD_PASS','STA_CONSTRAINED_PATHS_PASS','timing','reported_path_min_ns','resource_comparison','production_changes_from_hardware_pass')},indent=2))
    print(out)

if __name__ == '__main__':
    main()
