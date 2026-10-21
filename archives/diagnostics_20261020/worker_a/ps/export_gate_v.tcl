# Template: fill __DB__ and __OUT__, run with
#   G:\anlu\bin\td_commands_prompt.exe export_gate_v.tcl
# Read-only: no optimize/place/route/bitgen. Use a DB copy in scratch.
import_device eagle_s20.db -package EG4S20BG256
import_db {__DB__}
write_verilog {__OUT__} -nobuf
exit
