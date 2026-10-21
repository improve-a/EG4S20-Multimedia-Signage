$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$d='D:\FPGA\EG4S20-NoBot-RCA-20261020\worker_a'
$s=@'
puts "===CMDS==="
foreach c [lsort [info commands]] {
  if {[string match *verilog* $c] || [string match *netlist* $c] || [string match *db* $c] || [string match *write* $c] || [string match *report* $c] || [string match *cell* $c] || [string match *pin* $c] || [string match *get_* $c]} { puts $c }
}
puts "===END==="
exit
'@
Set-Content -Path "$d\cmds.tcl" -Value $s -Encoding ascii
Set-Location $d
& 'G:\anlu\bin\td_commands_prompt.exe' 'D:/FPGA/EG4S20-NoBot-RCA-20261020/worker_a/cmds.tcl' 2>&1 | Select-Object -First 300
