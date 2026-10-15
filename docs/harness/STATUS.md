# HTML fidelity status

Updated UTC 2026-10-15T16:43:34.154495+00:00

Primary repository: D:\FPGA\EG4S20-Multimedia-Signage
Branch: codex/html-fidelity. Imported public HEAD: fb97d76. Historical c16d3da and original sources preserved.
Remote: https://github.com/improve-a/EG4S20-Multimedia-Signage.git; fresh ls-remote returned empty, exit 0. Push not attempted this run.
Target: HX4S20C / EG4S20BG256, top top; project/td_project/hx4s20_basic.al.
Tool: G:\anlu\bin\td_commands_prompt.exe, TD 6.2.1 Engineer build 168116.
Build entry: scripts/build.py -> scripts/prepare_snapshot.py -> harness/windows_job.py -> harness/build.tcl.
Regression entry: scripts/run_regression.py plus targeted scripts/html_*_verify.py.

Explicit agent models: visual_assets gpt-6.1-sol medium; bot_osd and page_control gpt-6.1-sol high. No recursive agents.

Completed: verified 59 local dependencies; retained eight-slot scanner; six clean native pages, four independent comparison resources, body texture and glyph atlas; panel loader passes all real payloads and audio arbitration; six-page cache, previous/next, late ACK, 5.4 s schedule, zoom mapping and proportional caption/Bot unit tests. Top connects 5-bit page/direction/comparison metadata and shared commit event.

Active issue: official APUG011 v1.2 SDRAM interface only honors address jumps at aligned four-word groups. Previous arbitrary-address bridge tests establish logical mapping only. Agent page_control is replacing the bridge with aligned burst fetch/cache and testing a contract-accurate memory model. Agent bot_osd is preparing actual full display-chain frames; visual_assets runs legacy/adaptive-input regressions.

Next: isolated overlay synthesis resource probe; corrected bridge integration and full-chain pixels; first full TD build; independent component entrance improvements, visual comparisons, final regression/build/material package and branch push.

Output: output/html_fidelity. Prototype originals unchanged. Live CUA file opening blocked by URL policy; no workaround attempted. Offline deterministic exports are recorded separately, not claimed as live UI verification.

SIM: targeted module PASS, full-chain pending. SYN/PNR/STA/BITGEN: NOT_RUN. VISUAL: reference and isolated RTL frames prepared; full-chain comparison pending. HARDWARE: NOT_TESTED_THIS_RUN.
