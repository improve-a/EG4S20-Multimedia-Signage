  // --- autonomous idle behaviour (only when nothing is choreographed) --------
  autonomous() {
    const t = this.t;
    if (t >= this.nextLook) {
      const r = Math.random();
      if (this.pointer && t - this.pointer.t < 2) this.look(this.pointer.x, this.pointer.y);
      else if (r < .34) this.look(-.6 - Math.random() * .3, -.35 - Math.random() * .25); // the product
      else if (r < .62) this.look((Math.random() - .5) * .5, (Math.random() - .3) * .25); // the visitor
      else this.look((Math.random() - .5) * 1.7, (Math.random() - .5) * .8);             // wander
      // hold times vary: short darts and long fixations
      this.nextLook = t + (Math.random() < .3 ? .5 + Math.random() * .5 : 1.6 + Math.random() * 2.8);
    }
    if (t >= this.nextCurious) {
      this.nextCurious = t + 11 + Math.random() * 9;
      const pick = Math.random();
      this.busyUntil = t + 2;
      if (pick < .5) { // peek at the product: lean in, eyes narrow a touch
        this.look(-1, -.45, false); this.lean.t = -1; this.tilt.t = -5; this.wide.t = .92;
        this.at(1.15, () => { this.lean.t = 0; this.tilt.t = 0; this.wide.t = 1; this.look(0, 0); });
      } else { // small happy bounce + double blink
        this.hop.kick(-40); this.sq.kick(-1.6); this.at(.25, () => this.doBlink(true)); this.smile.t = .5;
        this.at(1.2, () => this.smile.t = 0);
      }
    }
  }
  blinkAmount() {
    if (this.t >= this.blinkAt && !this.blink) {
      this.doBlink(Math.random() < .14);
    }
    if (!this.blink) return 0;
    const e = this.t - this.blink.t0, close = .065, hold = .03, open = .12, one = close + hold + open;
    const total = this.blink.dbl ? one * 2 + .07 : one;
    if (e >= total) { this.blink = null; this.blinkAt = this.t + 1.8 + Math.random() * 4.2 * (this.speaking ? .7 : 1); return 0; }
    let k = e % (one + .07);
    if (k < close) return k / close;                       // fast lid down
    if (k < close + hold) return 1;
    if (k < one) { const u = (k - close - hold) / open; return 1 - u * u * (3 - 2 * u); } // slower, eased lid up
    return 0;
  }
  // --- integrate & draw -----------------------------------------------------
  update(dt) {
    dt = Math.min(dt, 1 / 20);
    this.t += dt; const t = this.t;
    this.queue = this.queue.filter(([when, fn]) => (t >= when ? (fn(), false) : true));
    if (this.mode === 'react' && t > this.busyUntil && !this.queue.length) this.mode = this.speaking ? 'speak' : 'idle';
    if (this.mode !== 'react' && t > this.busyUntil) this.autonomous();
    const n = dt > 1 / 90 ? 2 : 1;
    for (const s of [this.gx, this.gy, this.tilt, this.lean, this.sq, this.hop, this.wide, this.smile]) for (let i = 0; i < n; i++) s.step(dt / n);
    this.wob *= Math.exp(-dt * 2.6);
    this.render(this.blinkAmount());
  }
  render(bl) {
    const { R, cx, t } = this;
    // breathing: asymmetric (quicker in, slower out) — not a plain sine
    const ph = (t % 4.6) / 4.6, br = ph < .38 ? Math.sin(ph / .38 * Math.PI / 2) : Math.cos((ph - .38) / .62 * Math.PI / 2);
    const breathe = br * br * (3 - 2 * br);
    // float: two incommensurate periods so it never loops visibly
    const fy = Math.sin(t * 1.13) * 1.6 + Math.sin(t * .47 + 1.3) * 1.1;
    const cy = this.cy + fy + this.hop.v * .06;
    const sq = this.sq.v * .055 + breathe * .022, sx = 1 + sq, sy = 1 - sq + breathe * .012;
    const lean = this.lean.v * 5.2, N = 28, P = [];
    for (let i = 0; i < N; i++) {
      const a = i / N * Math.PI * 2;
      let r = R * (1 + .014 * Math.sin(2 * a + t * .71) + .009 * Math.sin(5 * a - t * 1.31) + .006 * Math.sin(3 * a + t * 2.03)
        + this.wob * (.035 * Math.sin(3 * a + t * 9.4) + .02 * Math.sin(4 * a - t * 12.1)));
      let x = Math.cos(a) * r * sx, y = Math.sin(a) * r * sy;
      if (y > 0) y *= 1 - .05 * (y / R);                         // slightly fuller bottom, softer top
      x += lean * Math.max(0, -y / R);                             // top shears toward attention
      P.push([cx + x, cy + y]);
    }
    // closed Catmull-Rom → cubic Bézier
    let d = `M${P[0][0].toFixed(2)} ${P[0][1].toFixed(2)}`;
    for (let i = 0; i < N; i++) {
      const p0 = P[(i - 1 + N) % N], p1 = P[i], p2 = P[(i + 1) % N], p3 = P[(i + 2) % N];
      d += `C${(p1[0] + (p2[0] - p0[0]) / 6).toFixed(2)} ${(p1[1] + (p2[1] - p0[1]) / 6).toFixed(2)} ${(p2[0] - (p3[0] - p1[0]) / 6).toFixed(2)} ${(p2[1] - (p3[1] - p1[1]) / 6).toFixed(2)} ${p2[0].toFixed(2)} ${p2[1].toFixed(2)}`;
    }
    this.$body.setAttribute('d', d + 'Z');
    // eyes: gaze moves them across the face; the far eye compresses (reads as head turn)
    const gx = Math.max(-1.2, Math.min(1.2, this.gx.v)), gy = Math.max(-1, Math.min(1, this.gy.v));
    const ex = cx + gx * 9.5 + lean * .55, ey = cy - 5 + gy * 6.5 - sq * 6;
    const gap = 10.6 - Math.abs(gx) * 1.4, w = this.wide.v, sm = Math.max(0, this.smile.v);
    const base = 6.5 * w, open = Math.max(.07, 1 - bl);
    const eyeR = (el, side) => {
      const turn = 1 - Math.max(0, side * gx) * .16;               // eye on the far side narrows
      const rx = base * turn * (1 + sq * .4), ry = base * open * (1 - sm * .3) * (1 - sq * .5);
      el.setAttribute('cx', (ex + side * gap).toFixed(2));
      el.setAttribute('cy', (ey + (base - ry) * .55 - sm * 1.2 + (bl > .5 ? 1.2 : 0)).toFixed(2));
      el.setAttribute('rx', rx.toFixed(2)); el.setAttribute('ry', ry.toFixed(2));
    };
    eyeR(this.$l, -1); eyeR(this.$r, 1);
    this.$rig.setAttribute('transform', `rotate(${this.tilt.v.toFixed(2)} ${cx} ${(cy + R).toFixed(1)})`);
    const lift = (this.cy - cy) / 10;
    this.$sh.setAttribute('transform', `translate(${(this.lean.v * 2).toFixed(2)} 0) scale(${(1 - lift * .12).toFixed(3)} 1)`);
    this.$sh.setAttribute('opacity', (.85 - lift * .15).toFixed(2));
    // expose a compact state vector — the same fields an RTL sprite engine would need
    this.state = { x: +(ex - cx).toFixed(1), y: +(ey - this.cy).toFixed(1), blink: +bl.toFixed(2), tilt: +this.tilt.v.toFixed(1), mode: this.mode };
  }
}
