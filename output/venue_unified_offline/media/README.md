# Unified offline media

Six original canonical 640×480 uncompressed BMPs are preserved byte for byte. Intended physical discovery indices: daily 0=UI01, 1=UI02; emergency 2=UI03, 3=UI04, 4=UI05, 5=UI06. Filenames and copy order alone do not prove physical LBA order. Physical layout: **NOT_TESTED**.

07_MUSIC.WAV is the original daily 80-second PCM16 mono 48 kHz track. Playback is global/continuous and independent of image mode; emergency visuals do not select, restart or synchronize audio. The 80-second file ends in silence; there is no automatic loop or mode-triggered restart.

Reproduce from repository root: `python3 scripts/package_unified_offline.py`. Validate: `python3 scripts/package_unified_offline.py --validate-only`. Manifest records source provenance, hashes, formats and intended ordering. This script reads and writes repository files only; no card discovery, mounting, writing, JTAG or hardware actions. Offline format/hash validation does not establish physical acceptance.
