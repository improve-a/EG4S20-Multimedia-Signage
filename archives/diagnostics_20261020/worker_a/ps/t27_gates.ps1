$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$d='D:\FPGA\EG4S20-NoBot-RCA-20261020\worker_a'
$m=Select-String -Path "$d\a_gate.v" -Pattern '^  [A-Z][A-Z0-9_]+ ' | Select-Object -First 12
$m | ForEach-Object { $_.LineNumber.ToString()+": "+$_.Line.Trim() }
"### types histogram (python-less)"
$all=Select-String -Path "$d\a_gate.v" -Pattern '^  [A-Z][A-Z0-9_]+ ' | ForEach-Object { ($_.Line.Trim() -split '\s+')[0] }
$all | Group-Object | Sort-Object Count -Descending | Select-Object Count,Name | Format-Table -AutoSize | Out-String -Width 80
