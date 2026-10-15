# 场序 / VENUE FLOW design sources

Six original public-venue signage screens, authored at the actual 640×480 image size.
All geometric artwork, the portal/route brand mark, icons and fictional floor plan
were created for this project. No stock images, institutional branding or real
building safety plans are used.

`scenes.json` is the editable native-coordinate scene representation. The matching
`../UI-01.svg` through `../UI-06.svg` contain editable text and vector geometry.
The SVGs refer to `../fonts/NotoSansSC.ttf` relative to their own assets directory
as `fonts/NotoSansSC.ttf`. This official Google Fonts typeface is supplied with
its SIL Open Font License in `../fonts/OFL.txt`. CoreText's reported base face is
`NotoSansSC-Thin`; the renderer explicitly instantiates its variable weight axis
at 400 (regular), 600 (semibold) and 700 (bold). It does not render every label
using the base thin weight.

From the repository root, reproduce with the existing Python and macOS Swift:

```sh
python3 output/venue_emergency_ui/scripts/generate_ui.py
swift output/venue_emergency_ui/scripts/render_ui.swift
```

The renderer produces `UI01.ppm` through `UI06.ppm` here as binary P6 top-down
640×480 RGB sources for the media packager. It also produces native PNGs,
separately rendered 1280×960 previews and a 3×2 native montage in `../../previews`.
The large previews are original rerenders, not enlarged native thumbnails.

`text_audit.json` records all 84 text spans, actual selected font weights,
measured line and glyph ink bounds, missing glyph diagnostics and 24px display
safety-frame checks. Final audit: zero missing glyphs, zero canvas overflow and
zero safety-frame violations for text at or above 16px. Auxiliary English brand
text and footer provenance use smaller type; the main content is 16–26px and
major headings are 30–40px.

Visual review actually inspected the generated montage and native alert,
direction and map screens. The final route avoids the interaction room and
enters the current room through a drawn doorway. The recovery page says daily
display is pending, consistent with separate media packs requiring manual return.

These are prerendered media pages, not evidence of live alarms, live venue data,
dynamic FPGA typography or hardware operation. Emergency pages show
“模拟演示 / DEMO”; UI-05 additionally labels its fictitious map and instructs
viewers to follow actual site signage. Full product layouts require existing
OSD overlays disabled; technical feature demonstrations use the separate
existing-feature package. Real HDMI margin and color acceptance remain pending
physical testing.
