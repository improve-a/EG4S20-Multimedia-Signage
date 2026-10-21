$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
[Console]::OutputEncoding=New-Object System.Text.UTF8Encoding($false)
$script=@'
puts "HARNESS_LIVE_CABLE_SCAN_BEGIN"
set rc [catch {list_cable} cables]
puts "LIST_CABLE_RC=$rc"
puts "LIST_CABLE_RESULT=$cables"
puts "HARNESS_LIVE_CABLE_SCAN_END"
if {$rc} {exit 2}
exit
'@
[IO.File]::WriteAllText('D:\FPGA\hx4s20_usb_jtag_harness_20261013\root_live_cable.tcl',$script,(New-Object Text.UTF8Encoding($false)))
python 'D:\FPGA\hx4s20_usb_jtag_harness_20261013\root_bw_run.py' 'root_live_cable.tcl'
exit $LASTEXITCODE
