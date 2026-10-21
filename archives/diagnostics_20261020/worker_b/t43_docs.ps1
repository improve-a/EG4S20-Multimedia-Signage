$ErrorActionPreference='Stop'
$d='D:\FPGA\EG4S20-NoBot-Frozen\probe_hw_pass_20261020'
foreach($f in @('HARDWARE_PASS_BASELINE.md','evidence\PROBE_REPORT.md','delivery\HDMI_PROBE.md')){
 "##### $f"; Get-Content "$d\$f"
}
