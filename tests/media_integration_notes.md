# Shared BMP/audio system-boundary simulation

Real RTL: sd_card_bmp (ENABLE_SCALING=1, ENABLE_AUDIO=1), media_controls,
media_sector_arbiter, bmp_read/bmp_scale, audio_media, WAV stream parser,
audio_async_fifo, audio_pcm_player, frame_fifo_write and display_commit.
Frozen shared RTL is not changed by this test. The current bench parameter
WRITE_BURST defaults to the production value256. The media_integration_03
snapshot predates parameterization and uses128; report its capacity separately.
media_integration_frame_pressure_tb repeats the complete 307200-pixel writer
contract with production BURST_SIZE256 and the same 512-word FIFO and clocks.

Behavioral models replace SDcard_top transport/initialization, the 512-word
image write FIFO and SDRAM storage/port arbitration, and the downstream frame
reader acknowledgement. Encrypted SDRAM/HDMI IP, physical SPI and pin timing
are outside this scope. The actual display_commit state machine handles the
candidate, frame-boundary request, read acknowledgement and commit toggle.
No hardware programming is performed.

All principal clocks retain production frequency: system 100MHz, audio/video
25MHz, memory 40MHz. Canvas output retains one pixel per 16 system clocks.
Video read requests occur at approximately 60Hz; memory busy modelling uses
25MHz-video-equivalent duty and refresh stalls. SD bytes are deliberately
accelerated and gapped; actual 64-system-clock SPI byte rate is separately
covered by scale_case1_spi64_01. A single forced key_next_press pulse bypasses
only physical key debounce, already covered by control unit tests.

The deterministic card contains a 320x180 BMP at LBA0 (pixel offset511), a
320x240 BMP at LBA339 and a stereo 16-bit 48kHz WAV at LBA800. Each BMP maps to
an independently generated full 640x480 canvas. Audio enable follows the first
real display commit. After at least ten verified PCM frames, the next-image
request is injected; WAV sector traffic and consumption must persist throughout
that second image load.

Assertions cover 614400 source pixels, every stored pixel and WRITE_V_FLIP
address, both final SDRAM frame contents, front-buffer write exclusion,
512-word image FIFO capacity, actual DMA finish before commit, two acknowledged
commits, WAV PCM prefix and 520/521 audio-clock 48k cadence, concurrent BMP/WAV
sector traffic, and absence of BMP/audio faults, underflow and overflow.

The final test stops after the second real commit acknowledgement and continued
correct PCM consumption. The card holds 6000 WAV frames; only the consumed PCM
prefix is a system-level assertion. Parser/file-length/EOF behaviour is covered
by independent shorter audio vectors. Do not claim this run verifies all 6000
PCM frames or encrypted full-system simulation.

Each evidence/sim/media_integration_* snapshot preserves exact source hashes,
input archive, compile command, PID, exit codes, wall time and logs. The first
snapshot predates the audio FIFO BRAM inference repair and originally waits for
6000-frame EOF; its result must not be labelled as current-FIFO evidence.
Subsequent final snapshots use the PCM-prefix completion condition above.

Model repair provenance: media_integration_01 compiled but timed out after600s
with no completed functional milestones. Run02 was stopped with simulation_exit1
after a diagnostic showed BMP state2 and zero pixels at1M/2M cycles. The SD
transport model delayed checking request withdrawal until after the arbiter
drain window. Run03 fixes only this model by observing request-low immediately
after end. Failed/terminated evidence is retained and is not a production RTL
failure or PASS.

Run03 reached one complete307200-pixel DMA frame, real commit and correct
PCM prefix, but never launched a second image. Root identified a real scaled
loader interface regression: load_start cleared scan_done, disabling later
parent selections. The controlled-state key probe passed, so the pulse
mechanism was not the cause. Scaler c1a02f9f fixes scan_done persistence and
registers header validation for the measured STA path; scale_scan_load_01
verifies discovery survives two complete loads. Run03 was stopped only by its
confirmed VVP PID and retained as incomplete FAIL. Run04 uses that repaired
scaler, final audio pipeline87682b3b and production WRITE_BURST256. Root
ext_full005 uses the same RTL hashes and has fresh positive setup/hold slack.

Authoritative result: media_integration_04 PASS, compile0/simulation0,
1037.781s. Both640x480 canvases (614400 pixels) and final SDRAM buffer contents
match independent goldens; two real commit acknowledgements complete. PCM
prefix3187 frames is correct, with2886 consumed through the second image load,
22 WAV sectors and451 BMP sectors observed during that load. Production
BURST256 combined FIFO peak is413/512 with no UF/OF or active-front writes.
The6000-frame material has not reached EOF when the test completes. All
snapshotted input hashes match current files; see media_integration_evidence.json.
