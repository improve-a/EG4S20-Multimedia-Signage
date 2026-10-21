import_device eagle_s20.db -package EG4S20BG256
import_db {D:/FPGA/EG4S20-NoBot-Fix-20261020/physical_review/A_pr.db}
puts "LOCKED_REGS [get_regs -o *O_video_locked_reg*]"
puts "FIFO_SR_LOWER [get_pins -o *u_w24_d1024_fifo*.sr]"
puts "FIFO_SR_UPPER [get_pins -o *u_w24_d1024_fifo*.SR]"
puts "FIFO_ALL [get_pins -o *u_w24_d1024_fifo*]"
exit
