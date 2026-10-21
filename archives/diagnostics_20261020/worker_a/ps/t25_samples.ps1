$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$d='D:\FPGA\EG4S20-NoBot-RCA-20261020\worker_a'
"### around rgb_to_axis instance (A)"
$l=(Select-String -Path "$d\a_gate.v" -Pattern 'video_rgb_to_axis' | Select-Object -First 3)
$l | ForEach-Object { $_.LineNumber.ToString()+": "+$_.Line.Trim() }
"### first LUT/DFF lines"
Select-String -Path "$d\a_gate.v" -Pattern '^\s+(LUT[1-6]|DFF|DFFE|DFFR|DFFS|RAM|GND|VCC)\b' | Select-Object -First 6 | ForEach-Object { $_.LineNumber.ToString()+": "+$_.Line.Trim() }
"### search O_axis_s_ready net"
Select-String -Path "$d\a_gate.v" -Pattern 'axis_s_ready|O_axis_s_ready' | ForEach-Object { $_.LineNumber.ToString()+": "+$_.Line.Trim() } | Select-Object -First 30
