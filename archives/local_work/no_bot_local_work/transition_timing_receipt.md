# Final actual RTL preview receipt

87 consecutive actual final-outRGB frames, 640x480, 16.8ms each; lossless APNG 1461.6ms. All87 independent PNG and APNG decoded RGB exactly equal original PPM. No new simulation or production edit.

APNG: `actual_rtl_samples.apng`, 7,374,943 bytes.
SHA256: `f770a5daf583de300694330babcfa0a04478608645010685586ed4f5d240b4eb`.

Frame numbers below are zero-based. Absolute times are simulator milliseconds; APNG origin is firstactivepixel of frame0 at35.016021ms.

| Event | Actual frame | Absolute simulator time, ms | Meaning |
|---|---:|---:|---|
| Initial qualification fullycovered | 0..1 | first35.016021 onward | Actual newfront data checks continue under mask |
| Eight visible oldfront qualification frames | 2..9 | first68.616021..186.216021 | Native full raster, not synthetic frame-state samples |
| Cover request | before10 | (201.569581,203.016021] | NOT_EXACTLY_TIMESTAMPED; complete-frame observation bound |
| First covered base pixel (0,0) | 10 | 203.016021 | First actual mask pixel |
| CoverACK observed / source model load starts | before21 active | 386.689140 | Latched source-driver timestamp in blanking, not TF start measurement |
| First allcovered active frame | 21 | first387.816021; last403.169581 | Baseimage covered; OSD remains above mask |
| All307200backwrites first observed | 23 | (419.969581,436.769581] | Accepted-write counter bound, not write_finish timestamp |
| Actual write_finish | unlatched | (419.969581,1136.689140] | NOT_EXACTLY_TIMESTAMPED; source waits it before candidate |
| End explicit750ms modelwait | before65 end | 1136.689140 | Exactly750ms after driver loadstart; accelerated model |
| CommitACK0/newfront1 first observed | 66 | (1142.369581,1159.169581] | NOT_EXACTLY_TIMESTAMPED; interval between complete-frame state samples |
| Newfront1 remains fullycovered | 66..67 | first1143.816021/1160.616021 | Two actual whole newfront scanouts before reveal; internal arm event not logged |
| First reveal frame begins | 68 | 1177.416021 | Pixel(0,0) still mask; offset604 |
| First newly visible source pixel(604,0) | 68 | 1177.440181 | 24.16us after framefirst, verified actual RGB |
| Fullyrevealed frame | 85 | first1463.016021; last1478.369581 | Offset0, actual source shown |
| Second fullyopen tail frame | 86 | first1479.816021; last1495.169581 | Full87-frame captured segment ends after this active raster |

All12 close positions are frames10..21:54,108,...594,640. Nominal12x16.8=201.6ms; first changed framefirst to allcovered framefirst is184.8ms (11 intervals).
All18 reveal positions are frames68..85:604,568,...28,0. Nominal18x16.8=302.4ms; first reveal framefirst to fullyopen framefirst is285.6ms (17 intervals). Actual first visible pixel to fullyopen firstpixel is285.575840ms; to that frame's lastactivepixel is300.929400ms.

The750ms modelwait is shorter than idealSPI2161-sector transport lowerbound791.21ms, before loader work, arbitration and realTF delays. It is not physical-card timing. Preview refresh cadence3100+memclocks is a representative model; separate600/601 cadence eightframe pressure tests each PASS.

Actual finalRGB/preOSDsource checks:26,726,400 pixels; sync checks37,379,230; FIFO fault0, readmin97/max384, writemax298; backwrites307200. Independent conservative mask/source check22,077,120 pixels. Audio bars are nonzero in actualframes39..86, driven by offline16.8msWAVpeakfixture; production64sampleplayer-to-finalOSD is separately tested. The two newpage tailframes end before33frame typingdelay; fullcaption/forward/reverse/wrap appearance comes from separately scoped actual captures.

Trusted12case contact: `../final_visual_contact/contact_sheet.png`; all12 thumbnailtiles independently checked against actual sourcePNG nearest2:1 copies, labelsoutside.

Input receipt:31actualcaptureRTL/ROM hashes match final6ee canonical;129source/config/ROM+7harness deliveryaudit matches TD004 sourceZIP, and sourceZIP/selectedbit hashes were independently rehashed. Postprocessing helper also matches frozen6ee and captured helper afterencoding. Full-system simulation NOT_RUN; hardware NOT_TESTED.
