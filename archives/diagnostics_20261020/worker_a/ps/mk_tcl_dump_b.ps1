$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$d='D:\FPGA\EG4S20-NoBot-RCA-20261020\worker_a'
$s=@'
set d D:/FPGA/EG4S20-NoBot-RCA-20261020/worker_a
import_device eagle_s20.db -package EG4S20BG256
if {[catch {import_db $d/b_gate.db} m]} { puts "IMPORT_ERR $m"; exit 1 }
puts "IMPORTED_B"
if {[catch {write_verilog $d/b_gate.v -nobuf} m]} { puts "WRITE_ERR $m" } else { puts "WROTE_B" }
exit
'@
Set-Content -Path "$d\dump_b.tcl" -Value $s -Encoding ascii
Set-Location $d
& 'G:\anlu\bin\td_commands_prompt.exe' 'D:/FPGA/EG4S20-NoBot-RCA-20261020/worker_a/dump_b.tcl' 2>&1 | Select-Object -Last 12
if(Test-Path "$d\b_gate.v"){ "size=" + (Get-Item "$d\b_gate.v").Length } else { "no file" }
