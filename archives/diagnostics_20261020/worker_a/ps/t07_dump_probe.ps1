$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$r='D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design\user_source\hdl_source'
"### hdmi_probe.v"
Get-Content "$r\ext\hdmi_probe.v" | ForEach-Object -Begin {$i=0} -Process { $i++; "{0,4}: {1}" -f $i,$_ }
"### reset_sync.v"
Get-Content "$r\reset_sync.v" | ForEach-Object -Begin {$i=0} -Process { $i++; "{0,4}: {1}" -f $i,$_ }
"### video_rgb_to_axis_640x480.v"
Get-Content "$r\video_rgb_to_axis_640x480.v" | ForEach-Object -Begin {$i=0} -Process { $i++; "{0,4}: {1}" -f $i,$_ }
