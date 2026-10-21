$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$j=Get-Content 'D:\FPGA\EG4S20-NoBot-HDMIProbe\docs\local_dependencies.json' -Raw | ConvertFrom-Json
$j.dependencies | Where-Object { $_.path -match 'top_tf|video_rgb_to_axis|video_delay|hdmi1.4b|hdmi_phy|system_clocks|video_clocks' } | Select-Object path,bytes | Format-Table -AutoSize | Out-String -Width 160
"count=" + $j.dependencies.Count
