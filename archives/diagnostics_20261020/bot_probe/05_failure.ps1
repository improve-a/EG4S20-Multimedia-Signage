$d='D:\FPGA\EG4S20-Bot-HDMIProbe\output\html_fidelity\builds\bot_hdmi_probe_001'
Get-Content "$d\runs\bot_hdmi_probe_001\stages.tsv"
Get-Content "$d\runs\bot_hdmi_probe_001\stdout.log" -Tail 100
Get-Content "$d\runs\bot_hdmi_probe_001\stderr.log" -Tail 30
$f="$d\work\design\td_project\hx4s20_basic_Runs"
Get-Content "$f\phy_1\run.log" -Tail 110
Get-ChildItem "$f\syn_1" -Filter '*.area' | ForEach-Object {Get-Content $_.FullName -TotalCount 100}
Get-ChildItem "$f" -Recurse -Filter '*.bit' | Select-Object FullName,Length
