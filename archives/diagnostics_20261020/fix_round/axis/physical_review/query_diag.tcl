import_device eagle_s20.db -package EG4S20BG256
import_db {D:/FPGA/EG4S20-NoBot-Fix-20261020/physical_review/A_pr.db}
puts "R1 [get_regs O_video_locked]"
puts "R2 [get_regs *O_video_locked*]"
puts "R3 [get_regs {u_hdmi_1_4b_transmitter_core_wrapper/O_video_locked}]"
puts "P1 [get_pins {u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/O_video_locked_reg_syn_8.q[1]}]"
puts "P2 [get_pins u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/O_video_locked_reg_syn_8.q]"
puts "P3 [get_cells u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/O_video_locked_reg_syn_8]"
catch {report_timing_path -file try_r2.txt -from [get_regs *O_video_locked*] -to [get_pins {u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_640.sr}] -ep_num 10 -path_num 1} m
puts "TRY_R2 $m"
catch {report_timing_path -file try_p1.txt -from [get_pins {u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/O_video_locked_reg_syn_8.q[1]}] -to [get_pins {u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_640.sr}] -ep_num 10 -path_num 1} m
puts "TRY_P1 $m"
exit
