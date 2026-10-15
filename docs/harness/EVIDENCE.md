# HTML fidelity evidence

StartedUTC 2026-10-15T16:14:36.592861+00:00. Windows inventory found frozen build mirror and bare relay only. Imported full public-source Gitbundle into new worktree, verifiedorigin, created codex/html-fidelity.59dependencies match hashes. No hardware/card accessed.

Video25MHz and800x525 gives16.8ms/frame=59.5238095Hz.5400ms requires fractional-frame accumulation; old loader addedload/transitionlatency.

Evidence output/html_fidelity. EachTD run retains source_manifest/status/stages/logs/resource/timing/bitstreamhashes.

## Completed targeted checks

- Assets: 13 checks PASS; formal media: 6 checks PASS. Four independent HFXC panel payloads preserve standard BMP pixel data. SDRAM use 2,093,056 of 2,097,152 words, leaving 4,096 words.
- Panel loader: verification/20261015T162949479611Z/result.json; PID 45564, exit 0, 54.953 s. All 249,856 payload words checked, 1,956 panel/header sectors with real audio arbitration, delayed storage and write ACKs, malformed headers and timeout cases.
- Read tags: same run, PID 47476, exit 0, 0.125 s; 1,388 ordered requests/responses, packed halves, queue wrap/full/underflow/overflow. This tests tags only, not SDRAM address legality.
- Bot/OSD: bot_osd/verify_20261016_002121/verification.json, exit 0, 402.78 s; six 640x480 DUT frames and 2,318,100 pipeline checks. Updated dark audio bars/contrast numeric rendering verified separately. Actual full-display-chain test remains pending.
- Controller/viewport: page_control/previous_v1 and earlier scoped runs; six cached pages, late-ready/ACK, previous-key chord, 5.4 s schedule, 8-slot legacy boundary, 7,680,000 geometry address checks and explicit reverse aperture. Previous ideal memory bridge PASS is not hardware validity; see correction below.

## Primary reference check and memory correction

2026 contest title and five bonus directions checked in [Anlogic contest document](https://drive.google.com/file/d/1lV1hRE_DFhZdloVfqjA9CYWO-Yy8NBdE/view). No additional processor or PC runtime renderer is introduced.

[APUG011 v1.2 SDRAM guide](https://drive.google.com/file/d/1FdMvGjBKgTTtH4E3rBS7LOF5ucA1xVm5/view), sections 2.3.4, 2.4 and 7, specifies aligned groups of four 32-bit words; addresses within each group advance internally. The initial pixel-address bridge violated this for packed/zoom samples. It is being replaced before the first full build, and the simulation memory model now must enforce the official burst contract. No encrypted IP or inherited clocks are changed.
