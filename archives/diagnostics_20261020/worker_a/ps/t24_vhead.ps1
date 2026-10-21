$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$d='D:\FPGA\EG4S20-NoBot-RCA-20261020\worker_a'
"### head"
Get-Content "$d\a_gate.v" -TotalCount 60
"### grep receiver inst lines"
Select-String -Path "$d\a_gate.v" -Pattern 'u_video_axi_stream_receiver' | Select-Object -First 12 | ForEach-Object { $_.LineNumber.ToString()+": "+$_.Line.Trim() }
"### grep tready/ready names"
Select-String -Path "$d\a_gate.v" -Pattern 'ready' | Select-Object -First 25 | ForEach-Object { $_.LineNumber.ToString()+": "+$_.Line.Trim() }
