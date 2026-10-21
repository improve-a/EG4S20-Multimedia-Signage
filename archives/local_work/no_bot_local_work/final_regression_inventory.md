# Final regression inventory

Frozen production `6ee7c70bbf36c33f90a687f010c876de48f03ba6`. All19 listed scoped results/historical entries finalized; no pending simulation. Full-system and hardware remain unverified.

| Evidence | Recorded state | Final input association |
|---|---|---|
| loader_historical_14frames_17boundaries | PASS | HISTORICAL_DIFFERENT_SOURCE |
| loader_final_6frames_20boundaries | PASS | EXACT_HASH_MATCH |
| catalog_actual10headers | UNIT_SIM_PASS | EXACT_HASH_MATCH |
| audio_final13 | PASS | EXACT_HASH_MATCH |
| entire_wav_parser_3840000samples | UNIT_SIM_PASS | EXACT_HASH_MATCH |
| wav_excerpt_twice | UNIT_SIM_PASS | EXACT_HASH_MATCH |
| actual4096pcm_continuous_bmp | UNIT_SIM_PASS | EXACT_HASH_MATCH |
| legacy_controller12 | UNIT_SIM_PASS | EXACT_HASH_MATCH |
| keys_controls8 | PASS | EXACT_HASH_MATCH |
| cover_fault_qualification | PASS | EXACT_HASH_MATCH |
| transition_compatibility | PASS | EXACT_HASH_MATCH |
| top_unencrypted_elaboration6ee | UNENCRYPTED_ELAB_PASS | EXACT_HASH_MATCH |
| default_home2x_segmented | ACTUAL_DEFAULT_HOME2X_SEGMENTS_PASS | EXACT_HASH_MATCH |
| static11_final_outRGB | ACTUAL_RTL_STATIC_PASS | EXACT_HASH_MATCH |
| refresh600_601_pressure | LEGACY_PRESSURE600_601_PASS | EXACT_HASH_MATCH |
| loader_final_static11_payload_closure | PASS | EXACT_HASH_MATCH |
| actual_player64_peak_to_final_OSD | ACTUAL_PLAYER64_PEAK_TO_FINAL_OSD_SEGMENT_PASS | EXACT_HASH_MATCH |
| navigation_actual_forward_reverse_wrap_21crops | OVERLAY_SEGMENT_PASS | EXACT_HASH_MATCH |
| continuous_final_outRGB | LEGACY_DISPLAY_SEGMENT_PASS | EXACT_HASH_MATCH_FINAL6EE_TD004_AND_SCOPED_SIM_PASS |

Visual artifacts:
- final12_source_RGB_and_browser_OSD_metrics: `D:\FPGA\EG4S20-NoBot\output\html_fidelity\no_bot\verify\final_visual_metrics\visual_metrics.json`
- six_pages_actual_fullsize_contact: `D:\FPGA\EG4S20-NoBot\output\html_fidelity\no_bot\verify\six_page_actual_contact.png`
- final12_actual_contact: `D:\FPGA\EG4S20-NoBot\output\html_fidelity\no_bot\verify\final_visual_contact\contact_sheet.png`
- continuous87_actual_lossless_APNG: `D:\FPGA\EG4S20-NoBot\output\html_fidelity\no_bot\verify\legacy_display_20261018T171156698167Z\actual_rtl_samples.apng`
- continuous_actual_timing_and_decode_audit: `D:\FPGA\EG4S20-NoBot\output\html_fidelity\no_bot\verify\legacy_display_20261018T171156698167Z\preview_audit.json`

Scope limits:
- FULL_SYSTEM_SIM_NOT_RUN: complete encrypted SDRAM/HDMI/PLL pin-level system not simulated
- HARDWARE_NOT_TESTED: no physical card, board programming, JTAG, listening or physical button test
- No entire 80-second track through SD+arbiter+FIFO+player+HDMI in real time; complete WAV proof is parser only
- No physical TF response/token/busy upper bound or full image WAV discovery-time qualification
- Original14loadercases:12namedpayloads final-source equivalent; zoom2_focus5/zoom3_focus3 historicalonly
- Continuouspreview usesoffline16.8msWAVpeaks; production64samplepeak→finalOSD verified separately inshortcrop
- Finite excerpt second playback uses explicit TB restart4clocks afterEOF; top automatic EOF CDC/restart loop not simulated
- Continuouspreview sourcecontroller/SDRAMresponses modeled,750mswait accelerated; no realTFtiming
- All87frames actuallyexecuted andcaptured; clip endsbefore newcaption33frame delay; actualnaturaltyping illustrated in separate forward/reverse/wrap crops

Exact SHA256, absolute evidence paths, source/TD004 basis and per-case loader joins are in `final_regression_inventory.json`.
