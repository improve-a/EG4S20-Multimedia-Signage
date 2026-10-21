$r='D:\FPGA\EG4S20-NoBot-RCA-20261020\repo'
New-Item -ItemType Directory -Force "$r\docs\rca","$r\scripts\rca" | Out-Null
Copy-Item 'D:\FPGA\EG4S20-NoBot-RCA-20261020\scripts\provenance_audit.py' "$r\scripts\rca\provenance_audit.py"
Copy-Item 'D:\FPGA\EG4S20-NoBot-RCA-20261020\scripts\05_source_audit.py' "$r\scripts\rca\source_audit.py"
Copy-Item 'D:\FPGA\EG4S20-NoBot-RCA-20261020\scripts\07_compact_inputs.py' "$r\scripts\rca\compact_inputs.py"
git -C $r add scripts/rca scripts/rca_build.py docs/rca/RCA_REPORT.md
git -C $r commit -m 'analysis: freeze exact NoBot failure and Probe build provenance'
if($LASTEXITCODE -ne 0) {throw 'common commit failed'}
git -C $r status --short
