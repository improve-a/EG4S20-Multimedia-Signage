$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
[Console]::OutputEncoding=New-Object System.Text.UTF8Encoding($false)
$script=@'
puts "HARNESS_LIVE_JTAG_READ_ID_BEGIN"
set rc [catch {list_cable} result]
puts "LIST_CABLE_TCL_RC=$rc RESULT=$result"
if {$rc} {exit 2}
set rc [catch {read_device_id -cable 0} result]
puts "READ_DEVICE_ID_TCL_RC=$rc"
puts "READ_DEVICE_ID_RESULT=$result"
puts "HARNESS_LIVE_JTAG_READ_ID_END"
if {$rc} {exit 2}
exit
'@
[IO.File]::WriteAllText('D:\FPGA\hx4s20_usb_jtag_harness_20261013\root_live_read_id.tcl',$script,(New-Object Text.UTF8Encoding($false)))
python 'D:\FPGA\hx4s20_usb_jtag_harness_20261013\root_bw_run.py' 'root_live_read_id.tcl'
exit $LASTEXITCODE
