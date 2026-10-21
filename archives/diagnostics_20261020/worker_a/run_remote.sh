#!/usr/bin/env bash
# Reproducible, read-only pipeline for Worker A's mapped-netlist comparison.
# Writes only to D:\FPGA\EG4S20-NoBot-RCA-20261020\worker_a on the ThinkPad.
# The source builds and D:\FPGA\EG4S20-NoBot-Frozen are never written.
set -euo pipefail

SSH=thinkpad
R='D:\FPGA\EG4S20-NoBot-RCA-20261020\worker_a'
P='D:/FPGA/EG4S20-NoBot-RCA-20261020/worker_a'

# --- 1. create scratch dir (independent of any other worker) -----------------
# worker_a/t21_mkdir.ps1 does exactly this; run it via the local helper:
python3 ../scripts/remote_ps.py ps/t21_mkdir.ps1

# --- 2. copy the two mapped DBs (5.1 / 5.2 MB); no build is run -------------
python3 ../scripts/remote_ps.py ps/t23_copy_db.ps1

# --- 3. read-only export to flattened gate-level Verilog ---------------------
#     dump_a.tcl / dump_b.tcl contain:
#       import_device eagle_s20.db -package EG4S20BG256
#       import_db D:/FPGA/EG4S20-NoBot-RCA-20261020/worker_a/a_gate.db
#       write_verilog D:/FPGA/EG4S20-NoBot-RCA-20261020/worker_a/a_gate.v -nobuf
#       exit
python3 ../scripts/remote_ps.py ps/mk_tcl_dump.ps1
python3 ../scripts/remote_ps.py ps/mk_tcl_dump_b.ps1

# --- 4. ship the analysis scripts --------------------------------------------
scp netcmp.py seqdiff.py listseq.py ffsum.py subtree.py pindiff.py pduniq.py \
    luthist.py cone.py leaves.py brampins.py toplist.py findnet.py regstats.py \
    fanout.py obs_check.py cone_tt.py "$SSH:$P/"

# --- 5. structural comparisons ----------------------------------------------
ssh "$SSH" "cd /d $R && python netcmp.py summary a_gate.v b_gate.v > summary.json"
ssh "$SSH" "cd /d $R && python ffsum.py a_gate.v b_gate.v > ffsum.txt"
ssh "$SSH" "cd /d $R && python seqdiff.py a_gate.v b_gate.v u_video_rgb_to_axis_640x480 > seq_rgb.txt"
ssh "$SSH" "cd /d $R && python seqdiff.py a_gate.v b_gate.v u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver > seq_rx.txt"
ssh "$SSH" "cd /d $R && python brampins.py a_gate.v b_gate.v > bram.txt"
ssh "$SSH" "cd /d $R && python subtree.py a_gate.v b_gate.v u_hdmi_1_4b_transmitter_core_wrapper > subtree.txt"

# a_gate.v (8.5 MB) and b_gate.v (8.8 MB) stay on the ThinkPad by design.
# Collected outputs: worker_a/evidence.json and worker_a/evidence/
