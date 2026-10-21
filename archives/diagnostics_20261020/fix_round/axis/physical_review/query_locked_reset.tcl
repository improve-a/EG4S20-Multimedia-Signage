import_device eagle_s20.db -package EG4S20BG256
import_db {D:/FPGA/EG4S20-NoBot-Fix-20261020/physical_review/A_pr.db}
set fromreg [get_regs -o *O_video_locked*]
set topins [get_pins -o *u_w24_d1024_fifo*.sr]
puts "FROM $fromreg"
puts "TO_COUNT [llength $topins]"
puts "TO $topins"
report_timing_path -file locked_to_fifo_sr.txt -from $fromreg -to $topins -ep_num 1000 -path_num 1
exit
