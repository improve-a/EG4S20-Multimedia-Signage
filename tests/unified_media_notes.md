# Unified offline media directed tests

Run `python3 scripts/package_unified_offline.py --validate-only`, then `python3 scripts/make_unified_test_vectors.py` from repository root. The validator checks canonical-source identity, distinct image hashes, all 640×480 BI_RGB24 headers/size and the original 80-second PCM16 mono48k WAV. Physical ordering remains NOT_TESTED.

`unified_storage_tb` discovers six headers with target eight at the scan boundary, then eight headers with target eight. It checks found order, total count (including the former three-bit overflow), no pixel/writer activity during discovery, no errors and bounded request progress. Run both default legacy and `--parameter unified_storage_tb.ENABLE_SCALE=1`.

`unified_ui06_tb` runs the real enabled-scale bmp_read/bmp_scale pipeline on the canonical sixth BMP. A separate stdlib byte-level oracle converts each of 307200 original file-order BGR triplets to RGB; inherited WRITE_V_FLIP performs display orientation. The test compares every output pixel and checks SDRAM acknowledgement before sector requests, stable/sequential sector addresses, mode latching despite a mid-load mode change, output-rate bound, completion and absence of pending transactions. Sector response has variable byte gaps. Long wall runtime reflects simulation throughput, not a hardware timing claim.

Isolated Windows recipes:

```
python3 scripts/run_test.py UNIQUE_SCAN_ID unified_storage_tb rtl/SD/bmp_read.v rtl/ext/bmp_scale.v tests/unified_storage_tb.v --timeout 120
python3 scripts/run_test.py UNIQUE_SCAN_SCALE_ID unified_storage_tb rtl/SD/bmp_read.v rtl/ext/bmp_scale.v tests/unified_storage_tb.v --parameter unified_storage_tb.ENABLE_SCALE=1 --timeout 120
python3 scripts/run_test.py UNIQUE_UI06_ID unified_ui06_tb rtl/SD/bmp_read.v rtl/ext/bmp_scale.v tests/unified_ui06_tb.v --data tests/unified_ui06_card.hex --data tests/unified_ui06_rgb.hex --data tests/unified_ui06_vectors.json --timeout 600
```

Root/RTL agent's `content_modes_tb` separately tests restricted daily/emergency manual/autoplay groups, mode changes during active load and pending commit, framebuffer ownership and long/short KEY2 exclusivity. These are scoped unit simulations; full-system and hardware verification are not implied.

Fresh evidence 2026-10-14: final-source legacy scan `evidence/sim/unified_storage_final_20261014_01` PASS (6/8,14 requests); final-source scaled scan `evidence/sim/unified_storage_scaled_final_20261014_01` PASS (6/8,14 requests). Full real UI06 `evidence/sim/unified_ui06_20261014_02` PASS: all307200 pixels,1802 sector requests,9343790 cycles,335.485 seconds wall time,compile/simulation exit0. Prior `unified_ui06_20261014_01` TIMEOUT at120 seconds remains preserved; this was a wall-time limit, with no demonstrated RTL defect. Each isolated run preserves sourceSHA256, inputs, logs,PID,commands,exit and wall time. No TF or hardware operation occurred.


Final controls and affected-regression recipes (use unique IDs on rerun):

```sh
python3 scripts/run_test.py UNIQUE_CONTROLS_ID control_media_tb tb/control_media_tb.v rtl/media_controls.v --timeout 120
python3 scripts/run_test.py UNIQUE_GROUPS_ID content_modes_tb tests/content_modes_tb.v rtl/SD/sd_card_bmp.v rtl/media_controls.v --timeout 120
python3 scripts/run_test.py UNIQUE_RELOAD_ID scale_reload_tb tests/scale_reload_tb.v rtl/SD/sd_card_bmp.v rtl/media_controls.v --timeout 120
python3 scripts/run_regression.py --run-id UNIQUE_AFFECTED_ID --evidence-root output/venue_unified_offline/evidence --select controls_modes_004 controls_storage_002 config_002 transition_commit_sdp_001 scale_scan_01 scale_sta_reject_01 scale_scan_load_01 video_audio_integration_004
python3 scripts/run_regression.py --run-id UNIQUE_AUDIO_ID --evidence-root output/venue_unified_offline/evidence --select wav_001 audio_media_pipeline_boundary_001 video_audio_integration_004
```

After TD attempt 1 exposed a WAV chunk bounds setup violation, its arithmetic was
precomputed one accepted header byte earlier. The last recipe reran all three
affected audio benches successfully on the repaired source. The final counted set
is 16 passing configurations, replacing the earlier video/audio result with this
rerun. WAV checks include continuous/gapped byte acceptance, exact RIFF fit,
one-byte overflow, outside-start, odd padding, and restart/reset of cached bounds.
The final inventory and SHA256 correspondence are in
`output/venue_unified_offline/validation/simulation_summary.json`.
