# Three video FIFO BRAMs: bounded static old/new comparison

Only u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_380, _390 and _400 were examined, using the two mapped exports identified in output_chain_review.md. No RTL edits, dynamic simulation, TD build or hardware access.

Result: all three BRAM parameter dictionaries and every connected port match, after the already-verified pixel-clock alias and unused open_n labels are normalized. Both use DP8K, 9-bit A/B widths, NOREG A/B, SYNC reset, NORMAL write mode, CEAMUX/OCEAMUX/OCEBMUX=1 and WEBMUX=0. Both clocks come from the same video PLL output; rsta/rstb, wea, ceb and both address buses have identical named connections. Neither version supplies bea/beb ports on these three instances; no new byte-enable discrepancy exists here.

All 24 payload bits are present, with unchanged mappings: AXIS[7:0] -> video CH0[7:0], [15:8] -> CH1[7:0], [23:16] -> CH2[7:0]. The RAM packing is 9+9+6 useful bits; the final three unused storage bits have unused outputs in both exports. The whole CH0 net is declared [7:0] in mapped Verilog, explicitly expanded during comparison.

The direct payload wire path from RAM outputs through video/island assembly to data-distribution outputs (encoder inputs) remains six registers per bit, with identical D nets, FF modes, clock/CE/reset configuration across all 144 bits. No dynamic payload correctness or routed RAM behavior is implied by this static comparison.

No repair candidate was found. Static scope PASS; OFFLINE_BUILD not run, TIMING not evaluated, RTL_REGRESSION no production change, VIDEO_PATH_SIMULATION no new dynamic run, AUDIO_PATH_SIMULATION not extended, HARDWARE_NOT_TESTED.
