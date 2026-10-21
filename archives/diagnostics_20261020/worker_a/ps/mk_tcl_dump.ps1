$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$d='D:\FPGA\EG4S20-NoBot-RCA-20261020\worker_a'
$s=@'
set d D:/FPGA/EG4S20-NoBot-RCA-20261020/worker_a
import_device eagle_s20.db -package EG4S20BG256
if {[catch {import_db $d/a_gate.db} m]} { puts "IMPORT_ERR $m"; exit 1 }
puts "IMPORTED_A"
if {[catch {write_verilog $d/a_gate.v -nobuf} m]} { puts "WRITE_ERR $m" } else { puts "WROTE_A" }
exit
'@
Set-Content -Path "$d\dump_a.tcl" -Value $s -Encoding ascii
Set-Location $d
& 'G:\anlu\bin\td_commands_prompt.exe' 'D:/FPGA/EG4S20-NoBot-RCA-20261020/worker_a/dump_a.tcl' 2>&1 | Select-Object -Last 40
"### file"
if(Test-Path "$d\a_gate.v"){ (Get-Item "$d\a_gate.v").Length } else { "no file" }
