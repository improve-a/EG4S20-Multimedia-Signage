import_device eagle_s20.db -package EG4S20BG256
import_db {D:/FPGA/EG4S20-NoBot-Fix-20261020/physical_review/A_pr.db}
set topin [get_pins {u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_640.sr}]
set fp0 [get_pins {u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/O_video_locked_reg_syn_8.q[0]}]
set fp1 [get_pins {u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/O_video_locked_reg_syn_8.q[1]}]
puts "TOPIN $topin"
puts "FP0 $fp0"
puts "FP1 $fp1"
report_timing_path -file locked_q0_to_one_sr.txt -from $fp0 -to $topin -ep_num 10 -path_num 1
report_timing_path -file locked_q1_to_one_sr.txt -from $fp1 -to $topin -ep_num 10 -path_num 1
exit
