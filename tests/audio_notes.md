# TF WAV audio extension contract and evidence

`rtl/ext/audio_media.v` receives actual SD sector bytes through the Root-owned sector arbiter. Its `sector_req` stays asserted until the one-cycle `sector_grant`; the address is a physical 512-byte block LBA. Only the selected transaction's `sector_valid`, `sector_data`, `sector_end`, and `sector_error` may reach the client. It counts exactly 512 bytes per sector; short sectors fail closed. Root must hold the physical SD request until completion and drain the inherited controller between transactions.

The audio client scans LBA 0..131071 by default (first 64 MiB), accepts RIFF/WAVE PCM format 1, 16 bits, 48000 Hz, one or two channels, checked byte rate/block alignment and data bounds. Unknown chunks and odd-byte padding are supported across sectors; the data header must be within the first 4096 file bytes. The file starts at a sector boundary and uses consecutive physical sectors. This is not a FAT filesystem reader and does not follow fragmented cluster chains. Only the first supported WAV is selected. Playback rereads it from its start, consumes exactly the declared data payload, then maintains silent 48 kHz output. `restart` or an enable cycle rescans; there is no automatic EOF loop.

SD interfaces, inputs and `fifo_level` use `sys_clk` (100 MHz). Output PCM, `status`, `wave_peak` and flags use `audio_clk` (25 MHz). New resets are synchronous. Restart clears both Gray-pointer FIFO sides through a synchronized clear window before another sector is accepted. Default FIFO is 2048 stereo frames (65536 payload RAM bits), with 512-frame prefill; a shorter complete file starts only after its final sector completes with EOF known. Each new sector reserves 256 frames, the maximum PCM16 mono payload. Mute consumes frames, pause holds them, gain is signed volume/8 (0..8; larger values clamp to unity). The player left-justifies PCM16 into HDMI PCM24 and emits one valid pulse every 520 or 521 audio clocks using a 48000/25000000 phase accumulator. Underflow emits silence and sets a sticky flag; source EOF plus empty FIFO sets `eof` without underflow. Wave peak is the maximum absolute post-volume/post-mute sample over 64 output samples.

`status` values: 0 disabled, 1 scan, 2 prefill, 3 play, 4 pause, 5 drained EOF, B no supported WAV, C overflow, D underflow, E other file/sector/timeout fault. Underflow and overflow remain sticky until restart. `error` reports scanner/transport/parser fault, independently of underflow/overflow.

Fresh Windows Icarus evidence is preserved in `evidence/sim/` (inputs ZIP/SHA256, compile and simulator commands/exits, UTC/PID, wall time, stdout and JSON result):

| Run | Checked behavior | Result |
|---|---|---|
| wav_002 | PCM16 stereo/mono signed order; 513-byte odd JUNK spanning sector; unsupported 44.1k header; data chunk outside RIFF | PASS |
| audio_fifo_002 | Independent 100/38.46MHz clock domains; full/empty; blocked overflow write; Gray pointer synchronization; FIFO order and wrap | PASS |
| audio_player_002 | 25MHz -> 48k cadence intervals; signed volume 0/1/4/8 and clamp; mute consumption; pause; underflow silence; EOF distinction; wave peak | PASS |
| audio_media_004 | Real 512-byte sector transport model, misses LBA0/1, RIFF at LBA2, multi-sector header, contiguous reread, 300 stereo frames, FIFO prefill, clean EOF | PASS |
| audio_media_mono_003 | Real sector model; 100 mono frames copied to both outputs; short file below prefill threshold starts and drains correctly | PASS |
| audio_media_one_frame_001 | One-frame mono WAV below prefill threshold; waits for completed sector before starting; clean EOF without false underflow | PASS |
| audio_media_request_hold_002 | Grant delayed 200 sys clocks; pause during pending request; req/address remain stable; ordered playback and clean EOF | PASS |
| audio_media_no_wav_003 | Scan range exhausted, finite no-WAV error and no emitted PCM | PASS |
| audio_media_short_sector_003 | 511-byte sector rejected, finite fault and no emitted PCM | PASS |
| audio_media_sd_error_003 | Sector error rejected, finite fault and no emitted PCM | PASS |

Earlier `wav_001` and `audio_fifo_001` compile/sim exits were zero and their assertions completed, but their completion messages lacked the required `TEST_PASS` token. Harness therefore correctly recorded FAIL. Those attempts are retained; the later runs above provide passing evidence. The testbench scope is new modules and a sector-byte model, not the encrypted HDMI/SD IP, full board system, timing closure or physical TF card/HDMI hardware. No TD flow, programming, driver, software or system change was performed by this audio task.

Vectors are generated deterministically with standard-library `python3 tests/audio_vectors.py`. `scripts/run_test.py` dispatches isolated snapshots to the existing Windows Icarus installation, preserving originals and evidence. For example:

```
python3 scripts/run_test.py audio_media_new audio_media_tb tests/audio_media_tb.v rtl/ext/audio_media.v rtl/ext/audio_pcm_player.v rtl/ext/audio_async_fifo.v rtl/ext/wav_stream_parser.v --data tests/audio_card.hex
```
