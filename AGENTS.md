# EG4S20 multimedia signage

- Target HX4S20C / EG4S20BG256, top `top`, TD 6.2.1 Engineer build 168116.
- This repository is the source of truth for future public development. The sibling
  `hx4s20_extensions` repository at c16d3da is preserved as the local historical baseline.
- Publish only project-authored code/tests/media and explicitly licensed assets.
  Files in docs/local_dependencies.json are local dependencies, excluded from Git.
  Do not add official, derived or encrypted vendor HDL, tool models, source bundles,
  bitstreams or the old repository history without documented redistribution rights.
- Existing SSH host `thinkpad`; TD G:\anlu\bin\td_commands_prompt.exe.
  Builds use clean unique NTFS snapshots under D:\FPGA\EG4S20-Multimedia-Signage\output\html_fidelity\builds.
  The bare Git relay is transport only, never a second development checkout.
- Preserve board pins, inherited PLL/reset and HDMI/SDRAM IP. Hardware/card operations
  require a separate user task; Git publication does not authorize them.
- Keep unit simulation, full-system simulation, SYN, PNR, STA, BITGEN and hardware
  states separate. Historical build evidence is not a fresh test of later changes.
- Prefer one Root Agent and Python standard-library scripts. No automatic full builds.

## Current HTML fidelity authorization — 2026-10-15

- Windows primary: D:\FPGA\EG4S20-Multimedia-Signage; branch codex/html-fidelity. Preserve Mac and historical workspaces.
- User authorizes offline RTL/assets/tests and serial fresh TD builds during approximately8–10h. No hardware/JTAG/card/driver/system operations.
- Root owns Git/shared integration/builds; max3 explicit non-Astra children gpt-6.1-sol medium/high; no recursive delegation.
- Normal branch push authorized; no force push/main merge. Public redistribution exclusions remain.
- Six-page exhibit and eight-slot baseline verified separately. Actual RTL pixels and new timing evidence required.

## Current timing closure authorization — 2026-10-16

- User authorizes local RTL/reset/CDC/constraint repairs, relevant offline regression, serial fresh TD builds and normal branch push on codex/timing-fix. Preserve current functionality/assets/interface rates; no hardware or system/network changes.
- New scope supersedes earlier reset-preservation restrictions only for justified local timing fixes. Root owns Git/top/SDC/builds; up to two necessary explicit gpt-6.1-sol/high children currently assigned, no recursive delegation.
- Separate BUILD, TIMING, REGRESSION and HARDWARE_NOT_TESTED; no blanket timing exceptions or relaxed clock periods. Keep prior deliveries and source/report provenance.

## Current no-Bot authorization — 2026-10-18

- Latest pasted user request governs this isolated worktree. Root plus up to three non-Astra gpt-6.1-sol children, no recursive delegation.
- Offline 8–10h scope: retain all non-Bot features, remove Bot hardware and visual resources, exact reference hash in output/html_fidelity/no_bot/STATUS.json.
- Root owns Git/top/storage bridge/builds; children own disjoint files. Serial fresh builds only. Preserve existing clocks/reset/PLL/pins/encrypted IP and original worktree.
- No JTAG, hardware, physical cards, software installation, authentication or system changes.

## Legacy backbone override — 2026-10-18

- Preserve codex/no-bot-exhibit at bcbc083; integrate selectively on codex/no-bot-legacy-integration. No reset/clean of the original workspace.
- ext_full_005 / ad5f6525 sequential dual-frame data path is the basis. Stop new html_layer_cache/four-word/random-read candidate work; its evidence stays on the preserved branch.
- Six ordinary pages and independent dual panels load through the old back-buffer/write-finish/commit ownership model. Preserve the existing integer zoom/focus mapping.
- Output-only mask: cover, wait for completed load, frame-boundary reveal. No second page scanout. Preserve audio, OSD, manual/auto, true dual and zoom.
