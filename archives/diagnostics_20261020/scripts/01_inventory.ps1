$roots = @('D:\FPGA\EG4S20-NoBot-Frozen\probe_hw_pass_20261020','D:\FPGA\EG4S20-NoBot','D:\FPGA\EG4S20-NoBot-HDMIProbe')
foreach ($p in $roots) {
  Write-Output "=== ROOT $p ==="
  if (!(Test-Path $p)) { Write-Output 'MISSING'; continue }
  Get-ChildItem $p -Force | Select-Object Mode,Name,Length | Format-Table -AutoSize
  if (Test-Path "$p\.git") {
    git -C $p status --short
    git -C $p log -5 --oneline
    git -C $p tag -l '*probe*'
  }
  Get-ChildItem $p -Recurse -File | Where-Object { $_.Name -match 'manifest|freeze|frozen|delivery|build.*json|\.bundle$|\.bit$|\.sdc$|\.adc$|\.tdc$|\.al$|\.rpt$|\.log$|\.ps1$|\.tcl$|\.md$|\.v$|\.db$' } | Select-Object FullName,Length | Format-Table -AutoSize
}
