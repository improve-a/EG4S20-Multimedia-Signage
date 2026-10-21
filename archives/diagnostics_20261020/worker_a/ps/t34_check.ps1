$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$f='D:\FPGA\EG4S20-NoBot-Frozen\probe_hw_pass_20261020\reports\check_timing.rpt'
Get-Content $f -TotalCount 120
"### grep unconstrained counts"
Select-String -Path $f -Pattern 'unconstrained|no_clock|No clock|unclocked|coverage|latch|loop|generated' -CaseSensitive:$false | ForEach-Object { $_.LineNumber.ToString()+": "+$_.Line.Trim() } | Select-Object -First 40
