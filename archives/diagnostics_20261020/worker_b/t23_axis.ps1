$ErrorActionPreference='Stop'
$sets=@(
 @('FAIL','D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\runs\no_bot_legacy_004\final_timing.rpt'),
 @('PASS','D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\runs\hdmi_probe_001\final_timing.rpt'))
foreach($p in $sets){
 $t=$p[0];$f=$p[1]
 "##### $t axis mentions in final_timing"
 (Select-String -Path $f -Pattern 'axis_s|I_axis|O_axis|video_rgb_to_axis').Count
 Select-String -Path $f -Pattern 'axis_s|I_axis|O_axis|video_rgb_to_axis' | Select-Object -First 8 | ForEach-Object { "{0}: {1}" -f $_.LineNumber,$_.Line.Trim() }
 "##### $t ignored_timing coverage head/tail"
 Get-Content $f -TotalCount 1
}
