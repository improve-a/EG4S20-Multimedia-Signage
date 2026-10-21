$r='D:\FPGA\EG4S20-Multimedia-Signage'
foreach($f in @('AGENTS.md','docs/harness/FINAL_REPORT.md','scripts/prepare_snapshot.py','docs/harness/ROOT_CAUSE_AUDIT_20261018.md')) {
Write-Output "=== $f ==="
if($f -match 'ROOT_CAUSE') {Get-Content "$r\$f"} else {git -C $r show "20871da:$f"}
}
git -C $r ls-tree -r --name-only 20871da | Select-String 'top|assets|media' | Select-Object -First 65
