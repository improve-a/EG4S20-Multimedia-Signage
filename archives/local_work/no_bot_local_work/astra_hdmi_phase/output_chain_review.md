# Bounded historical/new mapped output-chain review

Read-only comparison of historical ext_full_005 mapped export (SHA256 87bb1cba7edc820e853f6458adc89e192f75c8a58d8cb3598ad7f0bb7bd9ca34) with production no_bot_legacy_004 mapped export (SHA256 36edbd1af5b40b4c0ade94c00ccb18408a9f9a5abff75afb9bfae30360a4d10d). No RTL edits, hardware operations, new TD build, or new dynamic simulation were performed in this follow-up.

Scope: mapped registers named in HDMI data_distribution, three TMDS encoders and PHY; four TMDS output PADs; video PLL; actual clocks/reset driver identities. This is a static configuration/connectivity audit, not whole-netlist formal equivalence or physical serial output verification.

- Both mapped files retain exactly the same 505 named register bits in the selected output chain. Clock/CE/FF/reset mode and polarity/REGSET match for each bit after verified aliases are normalized. 459 use pixel clock; 46 use serial clock.
- Pixel clock is named video_clk in old and extensions/osd/clk in new. Both are the output of EG_PHY_GCLK video_pll_m0/bufg_feedback, input video_pll_m0/clk0_buf. No clock-source change.
- Different core-reset duplicate numbers are verified equivalent two-stage reset branches: second-stage D comes from the same named S_sync_reset_1d, pixel clock, asynchronous SET from rs_video/pipe[1]; first-stage D is zero with the same clock/reset/SET. The 34 direct rs_video-reset registers and 343 registers with no SR port remain corresponding.
- All 306 register bits selecting MI directly have identical named D nets. No direct constantization or missing named register was observed.
- Five register bits select old LSLICE F versus new MSLICE FX. Reusing the existing LUT decoder, canonical sorted input names and exhaustive truth tables show zero mismatches: four cases × 32 assignments and one disparity-counter case × 8192 assignments, total 8320. Results retain input ordering and per-table SHA256. The 8192 case expands only the differing small combinational fanin to common named cutpoints. No time-stepped test or new simulation framework was added.
- Four TMDS PAD instances match exactly, including DDRX1 output mode, data bit order, serial clock and rs_video reset. Video PLL parameters and all connected ports match; differences in unused open_n output labels are ignored.

No actionable new output-chain configuration/connection difference was found in this scope. The five observed packing differences implement equivalent local Boolean functions. This does not prove every unchanged-selection LUT cone equivalent, routed timing, initialization behavior, analog PLL behavior or actual HDMI serial waveform. It supplies no basis for an RTL repair or new adapter/FSM. Existing bounded receiver test conclusion remains limited to normal clock/reset and the tested startup interval; no hardware fix is claimed.

Parser provenance: instance parsing was extended to include ordinary unescaped PAD names, as well as escaped mapped names. The previously simulated receiver-control Verilog was regenerated and remains byte-identical (SHA256 299d61afcca6715714432766051634d302c787024ced89f0616dc77bc2825368); previous bounded control results are unaffected.

Status: OFFLINE_BUILD not run in this review; TIMING not evaluated; RTL_REGRESSION no production change; VIDEO_PATH_SIMULATION no new dynamic run (static scoped comparison PASS); AUDIO_PATH_SIMULATION not extended; HARDWARE_NOT_TESTED.
