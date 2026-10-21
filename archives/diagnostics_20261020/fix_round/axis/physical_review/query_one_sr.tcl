import_device eagle_s20.db -package EG4S20BG256
import_db {D:/FPGA/EG4S20-NoBot-Fix-20261020/physical_review/A_pr.db}
set fromreg [get_regs {u_hdmi_1_4b_transmitter_core_wrapper/O_video_locked}]
set topin [get_pins {u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_640.sr}]
puts "FROM $fromreg"
puts "TO $topin"
report_timing_path -file locked_to_one_sr.txt -from $fromreg -to $topin -ep_num 10 -path_num 1
exit
