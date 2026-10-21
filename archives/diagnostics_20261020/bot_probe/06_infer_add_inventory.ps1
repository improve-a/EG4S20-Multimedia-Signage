$r='D:\FPGA\EG4S20-Bot-HDMIProbe'
$d="$r\output\html_fidelity\builds\bot_hdmi_probe_001"
git -C $r status --short
git -C $r log -3 --oneline
Get-Content "$d\runs\bot_hdmi_probe_001\exported_phy.tcl" -Encoding UTF8
Get-Content "$d\runs\bot_hdmi_probe_001\exported_syn.tcl" -Encoding UTF8
Select-String -Path "$d\work\design\td_project\hx4s20_basic.al" -Pattern 'infer|Strategy|Property' -Context 3,3
Get-ChildItem G:\anlu -Directory | Select-Object Name
Get-FileHash G:\anlu\bin\td_commands_prompt.exe -Algorithm SHA256
