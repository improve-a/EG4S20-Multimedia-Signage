import sys
sys.path.insert(0, r"D:\FPGA\EG4S20-NoBot-RCA-20261020\worker_a")
from netcmp import parse_netlist

path, label = sys.argv[1], sys.argv[2]
p = parse_netlist(path)
names = [
    "u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/S_video_in_ready_reg_syn_4",
    "u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/S_video_in_ready_reg",
    "u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/O_video_locked_reg_syn_4",
    "u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/O_video_source_pause_reg_syn_4",
    "u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_video_source/O_video_period_reg",
    "u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_video_source/O_video_period_n2_syn_1",
    "u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo[0]",
    "u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/I_rst_syn_7",
    "extensions/osd/clk_syn_856",
    "u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_380",
    "u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_390",
    "u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_400",
]
print("=====", label, path)
for n in names:
    v = p["insts"].get(n)
    print("----", n)
    if not v:
        print("  MISSING")
        continue
    print("  type", v["type"])
    print("  params", " ".join(v["params"].split()))
    for k, val in v["pins"].items():
        print("    .%s=%s" % (k, val))
