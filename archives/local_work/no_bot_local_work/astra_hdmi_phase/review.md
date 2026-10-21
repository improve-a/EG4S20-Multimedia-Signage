# Independent offline HDMI receiver review

No production RTL, hardware, card, programmer, license, driver or tool installation was changed. This review does not identify a proven black-screen root cause or propose a speculative RTL repair.

## Actual mapped evidence

Input: `D:\FPGA\EG4S20-NoBot\output\html_fidelity\no_bot\verify\routed_init_no_bot_legacy_004\mapped.v`, SHA256 `36edbd1af5b40b4c0ade94c00ccb18408a9f9a5abff75afb9bfae30360a4d10d`.

- Lines 116638–116685 encode receiver state: `locked_next=(user && pause) || (locked && (!sol || valid))`; `pause_next=!locked && (sof || (!user && pause))`. All 64 input combinations were checked against the actual LUT INIT contents.
- Lines 114460–114476 encode FIFO reset `!locked || core_reset`.
- LUT enumeration gives internal source SOF decode at column 150, row 45; SOL decode at column 160 on active rows; column terminal 799; row update at column 15; row terminal 524. The source pauses at column 152 until incoming AXIS SOF, absorbing constant upstream latency.
- The actual final overlay protocol test reports first AXIS SOF at cycle 35392. The old four-stage extension implies cycle 35390 under the same timing. The latter is a structural inference, not a separate full-baseline RTL run.

## Executed discrimination experiments

1. `phase_model.py`: 17 initial phases, including 35390 and 35392, each over three frames. All lock at first incoming SOF with zero drops. The per-cycle state sequence after SOF is identical across phases for two frames, SHA256 `df424977ed34b023dd8f77d8219cadb72965b6e5857fec22f66f0d617f6c60e6`. Removing valid at actual SOL produces lock drops. Runtime 19.498 seconds. Counter arithmetic is summarized; Boolean receiver and decoder truth values come from mapped LUTs.
2. `extract_fifo.py` generates a bounded 81-FF/27-LUT-output receiver/FIFO control cone directly from physical-cell LUT parameters, FF D selectors, reset and enable attributes. Pixel BRAM data, HDMI audio packets, TMDS, EDID, and PHY are excluded. It is a netlist-derived control model, not a vendor simulation library.
3. `tb_receiver_control.v`, run 04: 40,000 native pixel clocks, including startup and approximately six active lines. Old/new first SOF is 35390/35392. Complete 10-bit RAM addresses, source counters, lock, pause, FIFO reset and read/write enables compare exactly after the two-cycle offset; unknown states are explicitly rejected. Both cases have zero blocked writes, zero lock drops, maximum accepted-write-minus-read occupancy 10. Both have one gated empty read at acquisition. The fill-only negative control accepts exactly 1024 writes, then blocks 38,963 attempts. Exit 0; wall 2.281 seconds.

The old/new accepted write counts differ by two (3809/3807) because the common end of the bounded window occurs two pixels apart in the shifted streams; this is not a lost-write result. Both input-valid minus actual-write checks are zero outside FIFO reset.

The initial testbench compilation rejected ANSI port initializers; these were moved into an initial block. A three-frame cone run hit its 120-second bound, and a one-frame cone run hit its 90-second bound; neither is reported as PASS. A five-second verbose diagnostic was also bounded. Run 04 is the sole completed FIFO-control simulation. Earlier phase-model three-frame results are a separate, simpler control-model test.

## Findings and limits

The new two-cycle complete-stream delay is not sufficient to cause persistent receiver unlock or full-induced dropped video under the verified native input protocol. Ignoring ready cannot be called this regression's root cause from these results. Do not add a new adapter/FSM, alter reset/clock architecture, or reduce the OSD pipeline solely on this hypothesis.

The configuration concatenation and unpacking agree at 51 bits; reset values brightness 0, contrast 2, volume 8 and mute 0 are consistent. Transition forwarding preserves HS/VS/DE continuously. The inherited tone-valid source remains active before WAV selection; thus a single loader pixel error alone does not explain permanently missing picture and sound.

No proven concrete RTL root cause has been found in this review. The root agent's actual-top pipeline and audio EOF tests are separate and must be reported on their own evidence.

Status: OFFLINE_BUILD not run here; TIMING not re-run; RTL_REGRESSION root cause unresolved; VIDEO_PATH_SIMULATION bounded mapped receiver control PASS only; AUDIO_PATH_SIMULATION not run here; HARDWARE_NOT_TESTED for any repair candidate. Historical hardware observations remain the separate source evidence.

Reproduce extraction locally beside the scripts with `python extract.py > cone.json`, then `python decode.py`, `python phase_model.py`, and `python extract_fifo.py`; compile the generated cone with the testbench using Icarus. `cone.json` contains vendor-derived netlist information and stays local with the other excluded evidence.
