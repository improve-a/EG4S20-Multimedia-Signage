# HTML fidelity plan

Primary D:\FPGA\EG4S20-Multimedia-Signage; HX4S20C / EG4S20BG256, top top; TD6.2.1 Engineer168116. Preserve fb97d76 public history and c16d3da baseline. Offline only.

| Contest bonus direction | Implementation / verification |
| --- | --- |
| Layers and dynamic captions | html_osd_overlay + html_bot_overlay, proportional antialias resources, actual DUT640x480 export |
| Slideshow and continuous transitions | exhibit cache/control and eased transition; late-ready/ACK/fast-key tests |
| Adaptive scaling | existing bmp_scale_read retained; differing-resolution regression, viewport zoom tested separately |
| Board keys and OSD parameters | media_controls exhibit option, same physical key pins, live fields |
| Real audio visualization | WAV/PCM/mute/FIFO/arbiter retained; sample-derived visual level, no FFT claim |

Dual comparison is a project interaction, not a separate mandatory contest item. No PC runtime renderer or additional processor.

Memory: EG_PHY_SDRAM_2M_32 is2^21 32-bit words (8MiB). Six640x480 pages consume1843200words=7372800bytes, remaining253952words=1015808bytes. BMP24bpp loads to32-bit SDRAM words. Six cached pages avoid navigation reload; legacy8slot scanner retained. AudioFIFO remainsBRAM. Historical35/64BRAM9K+0/16BRAM32K only planning reference. New104x100ARGB4444 body166400bits; captions measured from generated resources. Delay DE/HS/VS withRGB.

Sequence: prototype/assets → controller/Bot/OSD/reader integration → targeted regression+firstTD → compare/transition fidelity+contention → final pixel/build/material package/Gitpush. Serial fresh snapshots only.

Next finite-layer budget: exact RGB palette backgrounds use3x10bit indices/32bit word,214words/row; independent RRGGBBAA cropped parts replace the old six full frames. Six scene payloads total1803776words=7215104bytes. Four comparison panels keep baseword1843200 and62464words each. Total data8214528bytes;174080bytes unused; no additional runtime allocation is assumed. Scene locator lives in BMP metadata bytes80..111 and payload follows native BMP pixels as an aligned trailer; normal BMP limits are preserved unless the explicit HFXL extension validates. Layer readiness follows physical write completion.

Measured overlay optimization frees4073LUT/6DSP at cost16BRAM9K; actual full02 synthesis is13500LUT/47BRAM9K/11BRAM32K/16DSP before layered renderer. New16slot cache is1445LUT/2BRAM9K; palette and finite descriptors consume additional ROM. Full renderer must prove worst-row throughput with real40/25MHz cadence/refresh/backpressure, not average bandwidth. The final fresh full build is required after this phase.
