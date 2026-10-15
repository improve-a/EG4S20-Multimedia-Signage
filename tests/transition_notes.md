# Transition contract and evidence

`video_transition` outputs RGB/HS/VS/DE with one registered pixel-clock cycle.
`frame_start` is a one-cycle video-domain pulse before active video, from the
existing raw read-frame boundary. It controls offsets independently of VS.
Candidate toggles are synchronized with two flops. The caller supplies the real
video-domain `display_commit` acknowledgement; no ACK is generated here.

Modes: 0 direct, 1 wipe through black, 2 shift right through black. Code 3 falls
back to direct. Mode is captured when accepting a new animated request. A first
image with `enable=0` forwards immediately, preserving the existing initial
commit path. Direct requests also forward immediately; `transition_busy` stays
high until their real ACK matches. In animated modes the old image closes over
20 frames with default STEP=32 and WIDTH=640. Only at complete black does the
candidate toggle forward. The stage remains entirely black until a real matching
ACK and a subsequent frame boundary. Opening takes another 20 frames; a queued
candidate is accepted after opening completes. Intermediate candidate toggles
are not a queue: the upstream producer must retain normal one-outstanding-buffer
ownership. Reset this module and the commit owner together.

Wipe replaces x<offset with black. Slide outputs black for x<offset and reads
pixel x-offset from a 640x24 line RAM for the remaining pixels. Offset zero
bypasses RAM, avoiding same-address read/write ambiguity. Other reads reference
pixels already written in the current line; the RAM is not reset. The read is a
dedicated, unreset synchronous RAM output register, with TD's inherited
`fehdl force_ram=1, ram_style="bram"` memory annotation. The bypass/mask color
and RAM select are registered alongside HS/VS/DE; their output mux preserves
one-cycle latency. Reset clears the select and bypass output, so uninitialized
RAM/read-register values cannot reach RGB. Right-side
pixels are clipped, and there is no additional SDRAM read traffic. The final ext_full_005 synthesis hierarchy maps line_store to three BRAM9K
blocks; full routed timing and bit generation also complete in that snapshot.

`transition_tb.v` exercises the default 640-pixel/32-step implementation:
direct/first-image bypass, mode lock, request forwarding only after full black,
delayed real ACK, extra black frames, a second candidate, per-pixel slide source
positions, wipe mask positions, reset during animation, illegal mode, and RGB/
HS/VS/DE alignment including VS offset from frame_start. Runs through the
existing Windows Icarus snapshot runner. This remains UNIT_SIM_PASS; it does
not establish board timing, buffer ownership integration, or hardware behavior.

## Joint commit handshake test

`transition_commit_tb.v` instantiates the real `video_transition` and
`display_commit`, matching production's frame_start from raw_read_req rising.
It models a 100 MHz SD producer that retains its candidate buffer and refuses
to write its owned front until the true acknowledgement crosses back through
two synchronizer flops. A 25 MHz SDRAM reader model captures active_buf and
delays mem_read_ack by 40 clocks. The test covers the first-image bypass, mode
0/1/2, black-only forwarding, acknowledgement before opening, a candidate
prepared during opening, and an event submitted just before a frame boundary
that must defer to the next boundary. Per-frame changing pixel encodings expose
stale line-RAM data. It also checks active read-base stability during pixels.

The final `transition_commit_003` run checks 86 simulated read-frame boundaries,
each carrying one 640-pixel active line, for 55,040 RGB/sync checks and five
acknowledged buffer swaps. These are deliberately shortened frames for control
sequence testing, not 86 full 640x480 frames. The SD and SDRAM models represent
ownership/read-base/ACK behavior only; SD SPI transfers, DDR data transfers,
HDMI encryption/IP, timing closure and board behavior are outside this test.


After the full002 resource report mapped the original line store to Logic DRAM,
this local synchronous-read inference repair is verified separately by
`transition_bram_001` and `transition_commit_bram_001`. Simulation verifies
behavior only; BRAM mapping and resource reduction require a fresh TD report.


The following full003 synthesis still reported SYN5042 for transition RAM and
expanded the forced memory to flip-flops. The current follow-up isolates a
standard simple-dual-port RAM in `video_transition_line_ram` in the same source
file: exact 10-bit addresses, 1024-word padded depth, a single always block,
conditional write and unconditional registered read. Validity masks stay in
the parent, outside the memory template. This removes the 11-bit/non-power-of-two
array indexing and read-enable/output-control coupling suspected in inference.
Locations 640..1023 and any read before initialization are never selected for RGB.
`transition_sdp_001` and `transition_commit_sdp_001` both pass their unchanged
behavioral regressions. The later ext_full_005 fresh synthesis confirms three BRAM9K for line_store;
this mapping evidence is separate from the simulation results.
