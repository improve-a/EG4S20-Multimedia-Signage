import_device eagle_s20.db -package EG4S20BG256
import_db {D:/FPGA/EG4S20-NoBot-Fix-20261020/physical_review/A_pr.db}
puts "LOCKED_REG_WILD [get_regs -o *O_video_locked*]"
puts "LOCKED_PIN_WILD [get_pins -o *O_video_locked*]"
puts "I_RST_PIN_WILD [get_pins -o *I_rst_syn_7*]"
puts "I_RST_REG_WILD [get_regs -o *I_rst*]"
exit
