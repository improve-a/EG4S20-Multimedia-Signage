/* ---------- audio visualiser: simulated by default, real FFT if a WAV is loaded ---------- */
const vz = $('#viz').getContext('2d'), BARS = 9, bars = new Float32Array(BARS);
let analyser = null, fft = null, audioEl = null;
function vizStep(dt) {
  const w = 92, h = 60; vz.clearRect(0, 0, w, h);
  for (let i = 0; i < BARS; i++) {
    let v;
    if (analyser) { const lo = Math.floor(Math.pow(i / BARS, 1.7) * fft.length * .7), hi = Math.max(lo + 1, Math.floor(Math.pow((i + 1) / BARS, 1.7) * fft.length * .7)); let s = 0; for (let k = lo; k < hi; k++) s += fft[k]; v = s / (hi - lo) / 255; }
    else { const t = clock.t, sp = bot.speaking ? 1.25 : .55; v = sp * (.25 + .22 * Math.sin(t * (2.1 + i * .37) + i * 1.7) + .18 * Math.sin(t * (5.3 - i * .29) + i) + .1 * Math.random()) * (1 - i / BARS * .45); }
    v = Math.max(.06, Math.min(1, v));
    bars[i] += (v - bars[i]) * Math.min(1, dt * (v > bars[i] ? 22 : 7));     // fast attack, slow release
  }
  if (analyser) { analyser.getByteFrequencyData(fft); bot.level = bars[1]; }
  vz.fillStyle = '#1a1916';
  const bw = 6, gap = (w - BARS * bw) / (BARS - 1);
  for (let i = 0; i < BARS; i++) { const bh = Math.max(4, bars[i] * (h - 4)); const x = i * (bw + gap); vz.beginPath(); vz.roundRect(x, (h - bh) / 2, bw, bh, 3); vz.fill(); }
}
$('#wav').addEventListener('change', e => {
  const f = e.target.files[0]; if (!f) return;
  if (audioEl) { audioEl.pause(); URL.revokeObjectURL(audioEl.src); }
  audioEl = new Audio(URL.createObjectURL(f)); audioEl.loop = true;
  const ac = new (window.AudioContext || window.webkitAudioContext)();
  const src = ac.createMediaElementSource(audioEl); analyser = ac.createAnalyser(); analyser.fftSize = 256; analyser.smoothingTimeConstant = .6;
  fft = new Uint8Array(analyser.frequencyBinCount); src.connect(analyser); analyser.connect(ac.destination);
  audioEl.play(); $('#vizTag').textContent = '实时'; $('#vizHint').textContent = `正在分析：${f.name}（浏览器 Web Audio FFT）`; log('wav loaded');
});

/* ---------- controls ---------- */
function setPlay(on) { S.playing = on; S.acc = 0; const b = $('#play'); b.setAttribute('aria-pressed', on); b.textContent = on ? '暂停' : '播放'; log(on ? 'autoplay on' : 'autoplay paused'); }
function setOSD(on) { S.osd = on; $('#osd').classList.toggle('off', !on); $('#osdBtn').setAttribute('aria-pressed', on); log(`osd ${on ? 'on' : 'off'}`); }
$('#prev').onclick = () => go(S.page - 1, 'prev');
$('#next').onclick = () => go(S.page + 1, 'next');
pageBtns.forEach(b => b.onclick = () => go(+b.dataset.i, 'nav'));
$('#play').onclick = () => setPlay(!S.playing);
$('#interval').oninput = e => { S.interval = +e.target.value; $('#intervalOut').textContent = S.interval.toFixed(1) + ' s'; };
$('#osdBtn').onclick = () => setOSD(!S.osd);
$('#cmpBtn').onclick = () => setCompare(!S.cmp);
$('#zoomBtn').onclick = () => setZoom(!S.zoom);
$('#zoom').oninput = e => { S.z = +e.target.value; applyZoom(false); };
$('#vizBtn').onclick = () => { S.viz = !S.viz; $('#vizBtn').setAttribute('aria-pressed', S.viz); $('#card').classList.toggle('noviz', !S.viz); };
$('#xray').onchange = e => $('#stage').classList.toggle('xray', e.target.checked);
$('#bot').onclick = e => { e.stopPropagation(); bot.poke(); log('bot poked'); };
document.addEventListener('keydown', e => {
  if (e.target.tagName === 'INPUT' && e.target.type !== 'checkbox') return;
  const k = e.key.toLowerCase();
  if (k === 'arrowright') go(S.page + 1, 'next'); else if (k === 'arrowleft') go(S.page - 1, 'prev');
  else if (k === ' ') { e.preventDefault(); setPlay(!S.playing); }
  else if (k === 'o') setOSD(!S.osd); else if (k === 'c') setCompare(!S.cmp); else if (k === 'z') setZoom(!S.zoom);
  else if (k === 'f') document.fullscreenElement ? document.exitFullscreen() : $('#frame').requestFullscreen?.();
});

/* drag to pan while zoomed; pointer also feeds the bot's gaze */
const stage = $('#stage');
let drag = null;
const local = e => { const r = stage.getBoundingClientRect(); return [(e.clientX - r.left) / r.width, (e.clientY - r.top) / r.height]; };
stage.addEventListener('pointerdown', e => { if (!S.zoom) return; drag = { p: local(e), zx: S.zx, zy: S.zy }; stage.setPointerCapture(e.pointerId); stage.style.cursor = 'grabbing'; });
stage.addEventListener('pointermove', e => {
  const [u, v] = local(e);
  bot.pointer = { x: Math.max(-1.2, Math.min(1.2, (u - .89) * 3)), y: Math.max(-1, Math.min(1, (v - .87) * 3)), t: bot.t };
  if (!drag) return;
  S.zx = Math.max(0, Math.min(1, drag.zx - (u - drag.p[0]) / S.z)); S.zy = Math.max(0, Math.min(1, drag.zy - (v - drag.p[1]) / S.z)); applyZoom(false);
});
stage.addEventListener('pointerup', () => { drag = null; if (S.zoom) stage.style.cursor = 'grab'; });
stage.addEventListener('wheel', e => { if (!S.zoom) return; e.preventDefault(); S.z = Math.max(1, Math.min(3, S.z - Math.sign(e.deltaY) * .1)); $('#zoom').value = S.z; applyZoom(false); }, { passive: false });

/* fit the fixed 640×480 stage into the preview (integer-ish scale, composition never reflows) */
function fit() {
  const vp = $('#viewport'), fr = $('#frame');
  const fs = document.fullscreenElement === fr;
  const W = fs ? innerWidth : vp.clientWidth - 56, H = fs ? innerHeight : vp.clientHeight - 72;
  const k = Math.max(.4, Math.min(W / 640, H / 480));
  if (!fs) { fr.style.width = 640 * k + 'px'; fr.style.height = 480 * k + 'px'; }
  stage.style.transform = fs ? `translate(${(innerWidth - 640 * k) / 2}px,${(innerHeight - 480 * k) / 2}px) scale(${k})` : `scale(${k})`;
  $('#meta').textContent = `640 × 480 · 4:3 · 预览缩放 ${k.toFixed(2)}×`;
}
addEventListener('resize', fit); document.addEventListener('fullscreenchange', fit); fit();

/* ---------- master clock ---------- */
let last = performance.now();
function frame(now) {
  const dt = Math.min(.05, (now - last) / 1000); last = now;
  clock.t += dt;
  clock.q = clock.q.filter(([w, fn]) => (clock.t >= w ? (fn(), false) : true));
  // period is measured from the previous page-change event (incl. its transition), so 5.4 s means 5.4 s
  if (S.playing && !drag) {
    S.acc += dt;
    if (S.acc >= S.interval && !S.busy) go(S.page + 1, 'auto');   // the same event as a manual "next"
  }
  ticks[S.page].style.setProperty('--p', S.playing ? Math.min(1, S.acc / S.interval).toFixed(3) : 1);
  stepTyping();
  bot.update(dt);
  if (S.viz) vizStep(dt);
  requestAnimationFrame(frame);
}
updateOSD(true);
bot.at(.3, () => { bot.hop.kick(-50); bot.sq.kick(-2); bot.look(.2, -.2); });
log('ready');
requestAnimationFrame(frame);
window.__exhibit = { S, bot, go, setOSD, setCompare, setZoom, setPlay, clock };
