$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$d='D:\FPGA\EG4S20-NoBot-RCA-20261020\worker_a'
$s=@'
foreach c {print_netlist get_cells get_nets get_pins report_dangling report_hierarchy_connections report_design_cell_num report_cells import_db import_device} {
  puts "===== $c"
  if {[catch {help $c} m]} { puts "ERR $m" } else { puts $m }
}
exit
'@
Set-Content -Path "$d\help.tcl" -Value $s -Encoding ascii
Set-Location $d
& 'G:\anlu\bin\td_commands_prompt.exe' 'D:/FPGA/EG4S20-NoBot-RCA-20261020/worker_a/help.tcl' 2>&1
