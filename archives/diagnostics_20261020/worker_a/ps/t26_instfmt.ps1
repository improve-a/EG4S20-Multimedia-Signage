$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$d='D:\FPGA\EG4S20-NoBot-RCA-20261020\worker_a'
"### count DFF"
(Select-String -Path "$d\a_gate.v" -Pattern 'DFF').Count
"### sample DFF/LUT lines"
Select-String -Path "$d\a_gate.v" -Pattern 'DFF|LUT' | Select-Object -First 8 | ForEach-Object { $_.LineNumber.ToString()+": "+$_.Line.Trim() }
"### sample around line 6900-6960"
Get-Content "$d\a_gate.v" | Select-Object -Skip 6899 -First 60
