# BMP scaler verification scope

Production selects `bmp_read.ENABLE_SCALE=1` and connects `scale_mode[1:0]`.
The parameter defaults to zero and retains the exact legacy loader. Source
headers must be uncompressed, bottom-up 24-bit BMP with positive dimensions
1..640 × 1..480, one plane, DIB size 40/108/124, offset at or beyond DIB end
and at most 1048576, and a bounded file length covering all padded rows.
Top-down, oversized, malformed, truncated and overflowing-LBA files are rejected.

Mode 0 chooses integer 2x if both dimensions are at most 320×240, otherwise
1x. Mode 1 always chooses 1x. Remaining encodings behave as adaptive. The mode
is captured at load start. Pixels use nearest-neighbour replication; 640×480
is emitted in BMP bottom-up order so inherited WRITE_V_FLIP=1 stores upright.
The display top/left margins use floor division; opposite margins contain any
extra odd pixel. Each accepted image emits exactly 307200 pixels including bars.

There is a 640×24-bit synchronous-read line buffer and a 512×8-bit sector
buffer, no extra frame buffer. The source parser pauses during line replication
or black-bar generation, and the next SD request waits for the buffered sector
to be consumed. SD valid bytes need no ready handshake. Output is limited to
one pixel per 16 system clocks. `load_done` follows the final canvas output;
SDRAM write completion remains the inherited writer's separate signal.

`scale_vectors.py` independently creates top-down expected canvases, then
reverses their rows for comparison with the output stream. `scale_tb` verifies
all 307200 pixels, count, final pixel/done ordering, SD address sequence, delayed
SD grant, arbitrary byte gaps, end concurrent with final byte and mode changes
after load start. Cases 0..7 cover the four required geometries, original-size
centering, odd padded rows and minimum 1×1 dimensions. BYTE_GAP=63 reproduces
at least 64 clocks per SPI byte.

`scale_frame_tb` uses the actual inherited frame_fifo_write RTL, a behavioural
512-word FIFO, 100MHz source and 40MHz memory clock, read-busy occupancy at the
25MHz-video duty ratio and refresh stalls. It verifies every pixel and mapped
SDRAM address. This does not simulate encrypted SDRAM IP or physical hardware.
`scale_reject_tb` verifies invalid header bounds, signed height, file length,
compression/DIB/planes/bpp, LBA wrap, short/extra sectors, SD and ACK timeouts,
abort before ACK and during canvas output, and transport error. `scale_scan_tb`
verifies invalid-header skipping and variable-dimension file-sector skipping.

Fresh Windows Icarus evidence is under evidence/sim/scale_* with source hashes,
compiler command, logs, PID, exits and elapsed time. Early runs ending with
SCALE_PASS instead of TEST_PASS have harness SIM=FAIL despite completed pixel
comparison; use subsequent TEST_PASS runs as authoritative completion evidence.
Full-system encrypted-IP simulation and hardware execution remain unverified.

Current repair provenance: ext_full004 measured dib_size -> error_code setup
slack -1.328ns (11 levels). DIB end, field comparisons, validity groups and
final header_ok are now separate synchronous stages; all original accepted
header bounds are retained. scan_done and scan_found_total clear only on a new
scan, preserving the parent selection contract through image loads. Fresh
scale_scan_load_01 verifies scan followed by two complete loads (614400 pixels).
media_write256_01 uses production256 bursts and reports maxFIFO412/512; the
older burst128 peak284 is not the production-capacity result. Root-owned fresh ext_full005 timing now reports SWNS+0.140ns, HWNS+0.003ns
and TNS0 with the current c1a02f9f scaler source. See scale_evidence.json for
current versus historical source hashes and test results.
