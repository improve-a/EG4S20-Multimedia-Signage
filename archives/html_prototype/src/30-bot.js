/* =====================================================================
   C · BOT SPRITE LAYER — original character ("小安")
   Soft near-black body, two round white eyes. All motion is spring-driven
   and stepped by the single master clock (no timers of its own).
   ===================================================================== */
class Spring {
  constructor(v, k, d) { this.v = v; this.t = v; this.vel = 0; this.k = k; this.d = d; }
  step(dt) { const a = this.k * (this.t - this.v) - this.d * this.vel; this.vel += a * dt; this.v += this.vel * dt; }
  kick(v) { this.vel += v; }
}

class Bot {
  constructor(svg) {
    this.svg = svg;
    this.R = 33; this.cx = 52; this.cy = 56;
    // eyes: slightly under-damped so a saccade overshoots a hair, then settles (inertia)
    this.gx = new Spring(0, 340, 27); this.gy = new Spring(0, 340, 27);
    this.tilt = new Spring(0, 70, 7.5);   // degrees — loose, so it sways after a turn
    this.lean = new Spring(0, 110, 12);   // top-of-body shear toward attention
    this.sq = new Spring(0, 260, 9);      // squash (+) / stretch (−) — jelly
    this.hop = new Spring(0, 150, 15);    // vertical offset
    this.wide = new Spring(1, 220, 17);   // eye scale (surprise)
    this.smile = new Spring(0, 110, 15);  // squint of contentment
    this.wob = 0;                          // morph wobble energy, decays
    this.t = 0; this.blinkAt = 1.4; this.blink = null;
    this.nextLook = 2.2; this.nextCurious = 9 + Math.random() * 5;
    this.busyUntil = 0; this.queue = []; this.pointer = null; this.level = 0;
    this.mode = 'idle'; this.speaking = false;
    this.build();
  }
  build() {
    const s = this.svg;
    s.innerHTML = `
      <defs>
        <radialGradient id="botFill" cx=".36" cy=".3" r=".78"><stop offset="0" stop-color="#2b2a28"/><stop offset=".55" stop-color="#0a0a0a"/><stop offset="1" stop-color="#000"/></radialGradient>
        <linearGradient id="botRim" x1="0" y1="0" x2=".9" y2="1"><stop offset="0" stop-color="#EDE9E2" stop-opacity=".5"/><stop offset=".45" stop-color="#EDE9E2" stop-opacity=".06"/><stop offset="1" stop-color="#EDE9E2" stop-opacity="0"/></linearGradient>
        <radialGradient id="botShadow"><stop offset="0" stop-color="#000" stop-opacity=".7"/><stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient>
      </defs>
      <ellipse class="shadow" cx="52" cy="95" rx="27" ry="4.5" fill="url(#botShadow)"/>
      <g class="rig"><path class="body" fill="url(#botFill)" stroke="url(#botRim)" stroke-width="1.1"/>
        <ellipse class="eye l" fill="#F4F1EA"/><ellipse class="eye r" fill="#F4F1EA"/></g>`;
    this.$rig = s.querySelector('.rig'); this.$body = s.querySelector('.body');
    this.$l = s.querySelector('.eye.l'); this.$r = s.querySelector('.eye.r'); this.$sh = s.querySelector('.shadow');
  }
  // --- choreography helpers -------------------------------------------------
  at(sec, fn) { this.queue.push([this.t + sec, fn]); }
  look(x, y, snap = true) {
    const big = Math.hypot(x - this.gx.t, y - this.gy.t) > .9;
    this.gx.t = x; this.gy.t = y;
    if (snap && big && Math.random() < .4) this.doBlink(); // big saccades often carry a blink
  }
  doBlink(double = false) { if (!this.blink) this.blink = { t0: this.t, dbl: double }; }

  pageChange(dir) {           // dir: +1 next, −1 previous
    this.queue = []; this.mode = 'react'; this.busyUntil = this.t + 1.9;
    this.speaking = false; this.smile.t = 0;
    // 0 ms — eyes jump to where the new page enters (before the body moves)
    this.look(dir * 1, -.18, false);
    this.wide.t = 1.12; this.sq.kick(-1.4); if (Math.random() < .35) this.doBlink();
    // 90 ms — body follows the eyes: tilt + lean, a tiny lift
    this.at(.09, () => { this.tilt.t = dir * 8; this.lean.t = dir * 1; this.hop.kick(-30); this.wob = 1; });
    // 420 ms — eyes track the wipe edge as it crosses toward the product
    this.at(.42, () => { this.look(-dir * .55, -.42, false); this.tilt.t = -dir * 3; this.lean.t = -dir * .5; this.wide.t = 1; });
    // 1100 ms — transition done: settle, glance at the product, then turn to the visitor
    this.at(1.1, () => { this.tilt.t = 0; this.lean.t = 0; this.sq.kick(1.2); this.look(-.75, -.55, false); });
    this.at(1.55, () => { this.look(0, .05); this.smile.t = .55; this.mode = 'speak'; });
  }
  speak(on) { // OSD typing state (driven by caption)
    if (on && this.mode !== 'react') { this.mode = 'speak'; this.smile.t = .45; }
    this.speaking = on;
    if (!on && this.mode === 'speak') this.at(.65, () => { this.smile.t = 0; this.mode = 'idle'; this.nextLook = this.t + 1.1; });
  }
  syllable() { this.sq.kick(.55); this.gy.kick(.9); }
  poke() {
    this.queue = []; this.mode = 'react'; this.busyUntil = this.t + 1.4;
    this.wide.t = 1.3; this.hop.kick(-70); this.sq.kick(-3); this.wob = 1.4; this.look(0, -.3, false);
    this.at(.35, () => { this.wide.t = 1; this.doBlink(); });
    this.at(.7, () => { this.smile.t = .8; this.tilt.t = (Math.random() < .5 ? -1 : 1) * 6; });
    this.at(1.4, () => { this.smile.t = 0; this.tilt.t = 0; this.mode = 'idle'; });
  }
