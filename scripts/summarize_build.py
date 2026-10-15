#!/usr/bin/env python3
"""Summarize collected TD evidence; a generated STA report is not a timing PASS.

Coverage/constraint adequacy still requires engineering review. This script
never edits constraints, runs TD, or promotes numerical timing to hardware proof.
"""
import argparse
import hashlib
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]


def summarize(run_id):
    base = ROOT / 'evidence/builds' / run_id
    run = base / 'runs' / run_id
    status = json.loads((run / 'status.json').read_text())
    stages = {}
    for line in (run / 'stages.tsv').read_text().splitlines():
        _, stage, value = line.split('\t')
        stages[stage] = value
    report_path = run / 'final_timing.rpt'
    timing = report_path.read_text() if report_path.exists() else ''
    timing_numbers = {}
    for key in ('SWNS', 'STNS', 'HWNS', 'HTNS'):
        match = re.search(r'\b' + key + r':\s*([-+\d.]+)ns', timing)
        timing_numbers[key] = float(match[1]) if match else None
    coverage = re.search(r'STA coverage\s*:\s*([\d.]+)%', timing)
    corners = all(re.search(r'^' + corner + r'\s*\|\s*yes\s+yes', timing, re.M)
                  for corner in ('Slow', 'Fast'))
    routed = bool(re.search(r'Confidence\s*:\s*Routed', timing))
    numerical_pass = (all(v is not None and v >= 0 for v in timing_numbers.values())
                      and corners and routed)
    area_path = run / 'final_area.rpt'
    area = area_path.read_text() if area_path.exists() else ''
    resources = {}
    for key in ('lut', 'reg', 'bram', 'dsp', 'pll'):
        match = re.search(r'^#' + key + r'\s+(\d+)\s+out of\s+(\d+)\s+([\d.]+)%', area, re.M)
        if match:
            resources[key] = dict(used=int(match[1]), available=int(match[2]), percent=float(match[3]))
    artifacts = json.loads((run / 'artifacts.json').read_text())
    recorded = {row['path'].replace('\\', '/'): row for row in artifacts}
    bits = []
    for path in sorted(base.rglob('*.bit')):
        name = path.relative_to(base).as_posix()
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        expected = recorded.get(name)
        bits.append(dict(path=name, bytes=path.stat().st_size, sha256=digest,
                         matches_supervisor=bool(expected and expected['sha256'] == digest)))
    errors = []
    for log in ('stdout.log', 'stderr.log'):
        path = run / log
        if path.exists():
            errors.extend(line for line in path.read_text(errors='replace').splitlines()
                          if re.search(r'\bERROR\s*:', line))
    flow_pass = (status['state'] == 'FINISHED' and status['exit_code'] == 0
                 and status.get('flow_complete') is True
                 and all(stages.get(s) == 'PASS' for s in ('LOAD', 'SYN', 'PNR', 'BITGEN', 'STA_REPORT'))
                 and bool(bits) and all(b['matches_supervisor'] for b in bits) and not errors)
    result = dict(run_id=run_id, stages=stages, flow_pass=flow_pass,
                  sta_numerical='PASS' if numerical_pass else 'FAIL_OR_MISSING',
                  build='PENDING_COVERAGE_REVIEW' if flow_pass and numerical_pass else 'FAIL_OR_INCOMPLETE',
                  timing_ns=timing_numbers, coverage_percent=float(coverage[1]) if coverage else None,
                  routed=routed, both_corners_setup_hold=corners, resources=resources,
                  bits=bits, error_lines=errors, provenance=status,
                  scope='Offline implementation only. Review check_timing/constraints separately; hardware unverified.')
    out = ROOT / 'evidence/build_summaries' / (run_id + '.json')
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('run_id')
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9_-]+', args.run_id):
        parser.error('Invalid run id')
    summarize(args.run_id)
