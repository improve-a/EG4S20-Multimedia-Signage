import_device eagle_s20.db -package EG4S20BG256
import_db {D:/FPGA/EG4S20-NoBot-Fix-20261020/physical_review/A_pr.db}
set clk [get_clocks video_clk]
set topin [get_pins {u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_640.sr}]
puts "CLK $clk"
puts "TOPIN $topin"
report_timing_path -file clk_to_sr640.txt -from $clk -to $topin -ep_num 100 -path_num 10
exit
