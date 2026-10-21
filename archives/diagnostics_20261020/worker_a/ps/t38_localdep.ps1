$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$r='D:\FPGA\EG4S20-NoBot-HDMIProbe'
"### git hash-object of snapshot hdmi_probe.v"
& git -C $r hash-object 'output/html_fidelity/builds/hdmi_probe_001/work/design/user_source/hdl_source/ext/hdmi_probe.v'
"### local_dependencies.json"
Get-Content "$r\docs\local_dependencies.json" -ErrorAction SilentlyContinue | Select-Object -First 60
