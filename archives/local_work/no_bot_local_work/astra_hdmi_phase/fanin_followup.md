# Read-only receiver boundary check

No simulation extension or RTL change was made for this follow-up.

The actual TD004 mapped text contains zero references to `I_axis_s_last`, `O_video_last`, or `axis_s_last`. Its mapped cell data also contains no `u_video_rgb_to_axis_640x480/S_x_cnt` nodes. The generated TLAST/count logic was optimized out in this implementation; it is not an omitted receiver-control input.

The source SOF net has one FF driver (mapped line 114898) and one receiver load (116677). The source SOL net likewise has one driver (103210) and one receiver load (116653). FIFO requested-read enable comes from the register at 114858, with D = `S_v_en && O_video_guard_band_n6`, i.e. active rows at/after 45 and columns at/after 160 within the 800x525 counter range. This registered active/blank qualifier is present in the local testbench. All fourteen horizontal counter FFs use `!pause` as their sole clock enable; all fourteen vertical counter FFs use the column-15 update decode. No independent blank-state feedback into receiver lock or source-counter enable was found.

The model explicitly abstracts the common core reset and pixel clock. Its valid conclusion remains: with normal reset/clock operation and the verified native valid/SOF stream, the extra two-cycle delay is insufficient to cause persistent receiver unlock or FIFO-full dropped writes. This is not evidence of correct complete HDMI output.

The narrowest still-unverified shared downstream implementation boundary is `u_hdmi_data_distribution` → `u0/u1/u2_hdmi_tmds_encode` → `hdmi_phy_wrapper/lane_lvds_10_1`, including their actual mapped clock/reset distribution. Video and audio-island data meet there. Pixel BRAM data values and audio packet assembly remain outside this review. This identifies a coverage boundary, not a proven fault. Prioritizing that shared boundary requires the separate actual-top test to show sustained nonzero RGB and PCM at the transmitter inputs; two independent upstream failures are not yet disproven by receiver-control checks.
