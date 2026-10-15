# EG4S20 multimedia signage

- Target HX4S20C / EG4S20BG256, top `top`, TD 6.2.1 Engineer build 168116.
- This repository is the source of truth for future public development. The sibling
  `hx4s20_extensions` repository at c16d3da is preserved as the local historical baseline.
- Publish only project-authored code/tests/media and explicitly licensed assets.
  Files in docs/local_dependencies.json are local dependencies, excluded from Git.
  Do not add official, derived or encrypted vendor HDL, tool models, source bundles,
  bitstreams or the old repository history without documented redistribution rights.
- Existing SSH host `thinkpad`; TD G:\anlu\bin\td_commands_prompt.exe.
  Builds use clean unique NTFS snapshots under D:\FPGA\hx4s20_extensions_20261013.
  The bare Git relay is transport only, never a second development checkout.
- Preserve board pins, inherited PLL/reset and HDMI/SDRAM IP. Hardware/card operations
  require a separate user task; Git publication does not authorize them.
- Keep unit simulation, full-system simulation, SYN, PNR, STA, BITGEN and hardware
  states separate. Historical build evidence is not a fresh test of later changes.
- Prefer one Root Agent and Python standard-library scripts. No automatic full builds.
