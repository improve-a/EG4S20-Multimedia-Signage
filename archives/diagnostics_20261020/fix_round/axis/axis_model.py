#!/usr/bin/env python3
"""Minimal cycle model for the NoBot RGB->AXIS source + inferred HDMI RX contract.

WHAT THIS IS
  * The RGB->AXIS source is a line-by-line Python transcription of
    rca_ab_sources/A/work/design/user_source/hdl_source/video_rgb_to_axis_640x480.v.
  * The receiver side is NOT the encrypted vendor core. It is a deliberately
    small model whose *control equations* were read from the TD mapped netlist
    (rca_no_locked_003 / hdmi_probe_001):
        S_video_in_ready_next = !last && (fifo_empty || S_video_in_ready)
        O_axis_s_ready        = S_video_in_ready && !S_fifo_pro_full
        FIFO wea              = I_axis_s_valid            (not valid&&ready)
        FIFO rd_en            = video_period && !fifo_empty
  * Therefore it can answer only: "given these equations, can valid&&!ready
    lose a pixel / a line?"  It cannot prove what the encrypted core does in
    modes these equations do not cover.

WHAT THIS IS NOT
  * Not a vendor simulation, not a post-route simulation, not a proof of the
    HDMI core, TMDS, audio, SD or the media loader.
  * The `wea=valid` line is only the BRAM write-port enable. It does NOT model
    write-address CE, full/blocked writes, or reset; it cannot prove a pixel
    was enqueued. See astra_reuse/ for the netlist-derived FIFO control model.
"""
from dataclasses import dataclass, field

# 640x480p60 timing used by both color_bar (VIDEO_640_480) and the HDMI core
HACTIVE, HFP, HSYNC, HBP = 640, 16, 96, 48
VACTIVE, VFP, VSYNC, VBP = 480, 10, 2, 33
HTOTAL = HACTIVE + HFP + HSYNC + HBP   # 800
VTOTAL = VACTIVE + VFP + VSYNC + VBP   # 525
HSTART = HSYNC + HBP                   # 144
VSTART = VSYNC + VBP                   # 35


@dataclass
class RgbToAxis:
    """Exact register semantics of video_rgb_to_axis_640x480.v."""
    vs_1d: int = 0
    de_1d: int = 0
    frame_arm: int = 1
    x_cnt: int = 0
    user: int = 0
    valid: int = 0
    last: int = 0
    data: int = 0

    def reset(self):
        self.__init__()

    def step(self, vs, de, rgb):
        # outputs are the current register values; compute the next values
        n_vs_1d = vs
        n_de_1d = de
        n_user = 0
        n_valid = de
        n_last = 0
        n_data = rgb
        n_frame_arm = self.frame_arm
        n_x = 0
        if self.vs_1d != vs:
            n_frame_arm = 1
        if de:
            if not self.de_1d:
                n_x = 0
                if self.frame_arm:
                    n_user = 1
                    n_frame_arm = 0
            else:
                n_x = (self.x_cnt + 1) & 0x7FF
            if self.de_1d and self.x_cnt == 638:
                n_last = 1
        else:
            n_x = 0
        out = (self.user, self.valid, self.last, self.data)
        self.vs_1d, self.de_1d = n_vs_1d, n_de_1d
        self.frame_arm = n_frame_arm
        self.x_cnt = n_x
        self.user, self.valid, self.last, self.data = n_user, n_valid, n_last, n_data
        return out


@dataclass
class Receiver:
    depth: int = 1024
    prog_full: int = 512
    write_gate: str = "valid"          # "valid" (mapped) or "valid_and_ready"
    read_policy: str = "every_clock"   # every_clock | active_only | stall
    stall_start: int = -1
    stall_len: int = 0
    # registers
    ready: int = 0
    wr: int = 0
    rd: int = 0
    mem: dict = field(default_factory=dict)
    rd_en: int = 0
    pro_full: int = 0
    # stats
    writes: int = 0
    reads: int = 0
    overflow: int = 0
    dropped_by_gate: int = 0
    out_seq: list = field(default_factory=list)
    max_occ: int = 0
    c: int = 0
    d: int = 0
    c_events: int = 0
    d_events: int = 0
    prev_av: int = 0
    first_c_cycle: int = -1
    first_d_cycle: int = -1
    last_c_cycle: int = -1
    last_d_cycle: int = -1
    full_cycles: int = 0
    per_line: list = field(default_factory=list)
    cur_valid: int = 0
    cur_line_valid: int = 0
    cur_line_user: int = 0
    cur_line_last: int = 0

    def reset(self):
        # mapped S_video_in_ready_reg has REGSET("SET"): async reset presets Q=1
        self.ready = 1
        self.wr = self.rd = 0
        self.mem.clear()
        self.rd_en = self.pro_full = 0
        self.writes = self.reads = self.overflow = self.dropped_by_gate = 0
        self.out_seq = []
        self.max_occ = 0
        self.c = self.d = self.prev_av = 0
        self.c_events = self.d_events = self.full_cycles = 0
        self.first_c_cycle = self.first_d_cycle = -1
        self.last_c_cycle = self.last_d_cycle = -1
        self.per_line = []
        self.cur_valid = self.cur_line_valid = 0
        self.cur_line_user = self.cur_line_last = 0

    def occ(self):
        return (self.wr - self.rd) % self.depth

    def step(self, cycle, valid, user, last, data, period):
        empty = 1 if self.wr == self.rd else 0
        occ = self.occ()
        # read enable is a function of the *current* empty, as mapped
        rd_en = 1 if (period and not empty) else 0
        if self.read_policy == "active_only":
            rd_en = 1 if (period and not empty) else 0
        if self.read_policy == "stall" and self.stall_start <= cycle < self.stall_start + self.stall_len:
            rd_en = 0
        # write enable: mapped wea is I_axis_s_valid, NOT valid&&ready
        if self.write_gate == "valid":
            wr_en = valid
        else:
            wr_en = 1 if (valid and self.ready and not self.pro_full) else 0
            if valid and not wr_en:
                self.dropped_by_gate += 1
        # synchronous read of old head
        if rd_en:
            if not empty:
                self.out_seq.append(self.mem.get(self.rd, None))
            self.rd = (self.rd + 1) % self.depth
            self.reads += 1
        # write (real BRAM writes even when full -> wraps/overwrites)
        if wr_en:
            # one slot is reserved so a full FIFO has occ == depth-1
            if occ >= self.depth - 1:
                self.overflow += 1
                self.full_cycles += 1
            self.mem[self.wr] = data
            self.wr = (self.wr + 1) % self.depth
            self.writes += 1
        # next-state ready (mapped LUT3: ~last & (empty | ready))
        n_ready = 1 if ((not last) and (empty or self.ready)) else 0
        # pro_full is a registered/combinational status of occupancy
        n_pro_full = 1 if self.occ() >= self.prog_full else 0
        # probe samples the top-level ready = S_video_in_ready && !pro_full
        ready_seen = 1 if (self.ready and not self.pro_full) else 0
        if valid and not ready_seen:
            self.c = 1
            self.c_events += 1
            self.last_c_cycle = cycle
            if self.first_c_cycle < 0:
                self.first_c_cycle = cycle
        if valid and not self.prev_av and not ready_seen:
            self.d = 1
            self.d_events += 1
            self.last_d_cycle = cycle
            if self.first_d_cycle < 0:
                self.first_d_cycle = cycle
        self.prev_av = valid
        # line accounting on av
        if valid:
            self.cur_line_valid += 1
            if user:
                self.cur_line_user += 1
            if last:
                self.cur_line_last += 1
        if not valid and self.cur_valid:
            self.per_line.append((self.cur_line_valid, self.cur_line_user, self.cur_line_last))
            self.cur_line_valid = self.cur_line_user = self.cur_line_last = 0
        self.cur_valid = valid
        self.ready = n_ready
        self.pro_full = n_pro_full
        self.rd_en = rd_en
        self.max_occ = max(self.max_occ, self.occ())
        return ready_seen


def run(frames=3, release_cycle=0, **rx_kw):
    src = RgbToAxis()
    rx = Receiver(**rx_kw)
    src.reset()
    rx.reset()
    pixel = 0
    cycle = 0
    reset = True
    # one full frame of run after release is enough for startup; frames=3 gives
    # three complete frames after a frame-boundary release.
    total_cycles = max(release_cycle, 0) + (frames + 1) * VTOTAL * HTOTAL
    for _ in range(total_cycles):
        if cycle == release_cycle:
            reset = False
        line = (cycle // HTOTAL) % VTOTAL
        x = cycle % HTOTAL
        vs = 0 if line < VSYNC else 1
        de = 1 if (VSTART <= line < VSTART + VACTIVE and HSTART <= x < HSTART + HACTIVE) else 0
        # video_period: model "every clock" or "active DE"
        period = 1 if rx.read_policy in ("every_clock", "stall") else de
        if reset:
            src.reset()
            rx.reset()
            rx.step(cycle, 0, 0, 0, 0, 0)
        else:
            user, valid, last, data = src.step(vs, de, pixel if de else 0)
            if de:
                pixel += 1
            rx.step(cycle, valid, user, last, data, period)
        cycle += 1
    # flush blank to close the last line accounting
    for _ in range(HTOTAL):
        user, valid, last, data = src.step(1, 0, 0)
        rx.step(cycle, valid, user, last, data, 0)
        cycle += 1
    got = [v for v in rx.out_seq if v is not None]
    # first output gap: output must be the exact 0,1,2,... sequence of the
    # post-release DE beats. A dropped/overwritten beat shows up as a skip.
    first_bad = next((i for i, v in enumerate(got) if v != i), None)
    n_valid = sum(l[0] for l in rx.per_line)
    bad_lines = [l for l in rx.per_line if l[0] != HACTIVE]
    # user must appear exactly once per frame, on the first line of the frame.
    # In this run a "frame" boundary is every VTOTAL lines; lines are recorded
    # only when a valid burst ends, so count users instead of per-line flags.
    user_total = sum(l[1] for l in rx.per_line)
    last_total = sum(l[2] for l in rx.per_line)
    bad_last = [l for l in rx.per_line if l[2] != 1]
    return {
        "cycles": cycle,
        "valid_beats": n_valid,
        "writes": rx.writes,
        "reads": rx.reads,
        "out_len": len(got),
        "pixel_de": pixel,
        "pixel": pixel,
        "first_bad_output_index": first_bad,
        "overflow": rx.overflow,
        "dropped_by_gate": rx.dropped_by_gate,
        "max_occ": rx.max_occ,
        "c": rx.c,
        "d": rx.d,
        "c_events": rx.c_events,
        "d_events": rx.d_events,
        "first_c_cycle": rx.first_c_cycle,
        "first_d_cycle": rx.first_d_cycle,
        "last_c_cycle": rx.last_c_cycle,
        "last_d_cycle": rx.last_d_cycle,
        "lines": len(rx.per_line),
        "bad_line_len": len(bad_lines),
        "user_total": user_total,
        "last_total": last_total,
        "bad_last": len(bad_last),
        "sample_line": rx.per_line[:3],
    }


if __name__ == "__main__":
    import json
    for name, kw in [
        ("mapped/every_clock/blank_release", dict(release_cycle=HTOTAL * 2, read_policy="every_clock")),
        ("mapped/every_clock/mid_active_release", dict(release_cycle=HTOTAL * (VSTART + 1) + HSTART + 10, read_policy="every_clock")),
        ("mapped/active_only/mid_active_release", dict(release_cycle=HTOTAL * (VSTART + 1) + HSTART + 10, read_policy="active_only")),
        ("naive_gate/valid_and_ready/every_clock", dict(release_cycle=HTOTAL * (VSTART + 1) + HSTART + 10, write_gate="valid_and_ready", read_policy="every_clock")),
        ("naive_gate/valid_and_ready/active_only", dict(release_cycle=HTOTAL * (VSTART + 1) + HSTART + 10, write_gate="valid_and_ready", read_policy="active_only")),
        ("mapped/prog_full_1/every_clock", dict(release_cycle=HTOTAL * (VSTART + 1) + HSTART + 10, read_policy="every_clock", prog_full=1)),
        ("read_stall_1200", dict(release_cycle=HTOTAL * 2, read_policy="stall", stall_start=HTOTAL * (VSTART + 1) + HSTART + 100, stall_len=1200)),
    ]:
        print(name, json.dumps(run(**kw), indent=1))
