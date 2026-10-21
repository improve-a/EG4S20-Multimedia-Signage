$r='D:\FPGA\EG4S20-Multimedia-Signage'
git -C $r status --short
git -C $r log --all --oneline --decorate -55
git -C $r show --stat bcbc083
git -C $r show --stat 20871da
git -C $r ls-tree -r --name-only 20871da | Select-String 'REPORT|HANDOFF|DELIVERY|README|manifest|top_tf|\.al$|build.py|prepare_snapshot'
Get-ChildItem "$r\output\html_fidelity\builds" -Directory | Select-Object Name
