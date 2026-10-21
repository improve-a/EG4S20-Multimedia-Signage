$r='D:\FPGA\EG4S20-NoBot-RCA-20261020\repo'
$d='D:\FPGA\EG4S20-NoBot-RCA-20261020\delivery'
git -C $r status --short
git -C $r add docs/rca scripts/rca scripts/rca_build.py scripts/rca_checks.py scripts/rca_collect.py scripts/rca_netcheck.py scripts/rca_accept.py experiments
git -C $r commit -m 'analysis: deliver audited DS evidence and two offline diagnostic variants'
if($LASTEXITCODE -ne 0) {throw 'final commit failed'}
git -C $r bundle create "$d\nobot_rca_20261020.bundle" 'codex/nobot-rca-20261020'
if($LASTEXITCODE -ne 0) {throw 'bundle failed'}
git -C $r bundle verify "$d\nobot_rca_20261020.bundle"
if($LASTEXITCODE -ne 0) {throw 'bundle verify failed'}
git -C $r log -8 --oneline
git -C $r status --short
