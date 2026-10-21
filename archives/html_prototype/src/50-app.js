/* =====================================================================
   App: ONE master clock drives autoplay, transitions, captions and the bot.
   Every page change — button, nav, keyboard or autoplay — goes through go().
   ===================================================================== */
const N = PAGES.length, TRANSITION = 1.05;
const S = { page: 0, playing: true, interval: 5.4, acc: 0, osd: true, cmp: false, zoom: false, z: 2, zx: .5, zy: .45, viz: true, busy: false };
const clock = { t: 0, q: [], at(d, fn) { this.q.push([this.t + d, fn]); } };
const bot = new Bot($('#bot svg'));
const scenes = PAGES.map(p => { const el = document.createElement('section'); el.className = 'scene ' + p.cls; el.dataset.id = p.id; el.innerHTML = sceneHTML(p); $('#scenes').appendChild(el); return el; });
scenes[0].classList.add('on');
const pad = n => String(n).padStart(2, '0');
const logEl = $('#log'), logLines = [];
function log(msg) { logLines.unshift(`${clock.t.toFixed(2).padStart(6)}s  ${msg}`); logLines.length = Math.min(logLines.length, 6); logEl.textContent = logLines.join('\n'); }

// page tick marks (OSD) and nav buttons (prototype)
$('#ticks').innerHTML = PAGES.map(() => '<i></i>').join('');
$('#pageBtns').innerHTML = PAGES.map((p, i) => `<button class="btn" data-i="${i}"><em>${pad(i + 1)}</em>${p.tab}</button>`).join('');
const ticks = [...$('#ticks').children], pageBtns = [...$('#pageBtns').children];

/* ---------- the single page-change event ---------- */
function go(target, source) {
  target = (target + N) % N;
  if (target === S.page) return;
  const from = S.page, dir = source === 'prev' ? -1 : source === 'next' || source === 'auto' ? 1 : (target > from ? 1 : -1);
  S.page = target; S.acc = 0;
  bot.pageChange(dir);                                   // 1 · bot reacts immediately
  const a = scenes[from], b = scenes[target];            // 2 · transition starts in the same frame
  scenes.forEach(s => s.classList.remove('enter', 'leave', 'rev'));
  a.classList.add('on', 'leave'); b.classList.add('on', 'enter'); if (dir < 0) b.classList.add('rev');
  S.busy = true;
  clock.at(TRANSITION + .5, () => { a.classList.remove('on', 'leave'); b.classList.remove('enter', 'rev'); S.busy = false; });
  if (S.cmp) renderCompare();
  updateOSD(true);
  log(`go ${pad(from + 1)}→${pad(target + 1)} · ${source}`);
}

/* ---------- B · OSD ---------- */
const sayEl = $('#say');
let typing = null;
function updateOSD(animate) {
  const p = PAGES[S.page];
  $('#osdN').textContent = `${pad(S.page + 1)} / ${pad(N)}`;
  $('#osdT').textContent = p.tab;
  $('#cardWho').textContent = S.cmp ? '双图对比' : (p.model || p.kicker);
  ticks.forEach((t, i) => t.classList.toggle('on', i === S.page));
  pageBtns.forEach((b, i) => b.setAttribute('aria-pressed', i === S.page));
  document.getElementById('stage').style.setProperty('--acc-osd', getComputedStyle(scenes[S.page]).getPropertyValue('--acc'));
  const txt = $('#cardTxt'); txt.classList.remove('swap'); void txt.offsetWidth; txt.classList.add('swap');
  const line = S.cmp ? cmpLine() : p.say;
  sayEl.textContent = '';
  typing = { text: line, i: 0, start: clock.t + (animate ? .55 : .1), last: 0 };
}
function cmpLine() {
  const [a, b] = cmpPair();
  return `左边是${a.cn}，${a.cmp[0][1]}；右边是${b.cn}，${b.cmp[0][1]}。同一块屏，两路图像同时输出。`;
}
function stepTyping() {
  if (!typing || clock.t < typing.start) return;
  const cps = 19, want = Math.min(typing.text.length, Math.floor((clock.t - typing.start) * cps));
  if (want > typing.i) {
    if (typing.i === 0) bot.speak(true);
    const ch = typing.text[want - 1];
    typing.i = want;
    sayEl.innerHTML = esc(typing.text.slice(0, want)) + (want < typing.text.length ? '<span class="caret"></span>' : '');
    if (/[，。；、]/.test(ch)) typing.start += .22;          // breathe at punctuation
    else if (Math.random() < .3) bot.syllable();
    if (want === typing.text.length) { bot.speak(false); typing = null; }
  }
}

/* ---------- dual image (static layer, = FPGA dual-image mode) ---------- */
function cmpPair() {
  const id = PAGES[S.page].id, by = k => PAGES.find(p => p.id === k);
  const pairs = { eagle: 'phoenix', phoenix: 'eagle', elf: 'dragon', dragon: 'elf' };
  return pairs[id] ? [by(id), by(pairs[id])] : [by('eagle'), by('phoenix')];
}
function renderCompare() { const [a, b] = cmpPair(); $('#compare').innerHTML = compareHTML(a, b); }
function setCompare(on) {
  S.cmp = on; $('#cmpBtn').setAttribute('aria-pressed', on);
  if (on) renderCompare();
  $('#compare').classList.toggle('on', on); $('#scenes').style.visibility = on ? 'hidden' : '';
  bot.look(on ? -.9 : 0, -.3, false); bot.at(.5, () => bot.look(on ? .9 : 0, -.3, false)); bot.at(1, () => bot.look(0, 0));
  updateOSD(false); log(`dual image ${on ? 'on' : 'off'}`);
}

/* ---------- zoom: real magnification of the static layer ---------- */
function applyZoom(ease = true) {
  const z = S.zoom ? S.z : 1, bmp = $('#bmp');
  const maxX = 640 * (z - 1), maxY = 480 * (z - 1);
  const tx = -Math.max(0, Math.min(maxX, S.zx * 640 * z - 320)), ty = -Math.max(0, Math.min(maxY, S.zy * 480 * z - 240));
  bmp.classList.toggle('ease', ease);
  bmp.style.transform = z === 1 ? '' : `translate(${tx}px,${ty}px) scale(${z})`;
  $('#zoomBadge').classList.toggle('on', S.zoom);
  $('#zoomTxt').textContent = $('#zoomOut').textContent = S.z.toFixed(1) + '×';
  const mb = $('#miniBox').style; mb.width = (100 / z) + '%'; mb.height = (100 / z) + '%'; mb.left = (-tx / z / 640 * 100) + '%'; mb.top = (-ty / z / 480 * 100) + '%';
  $('#stage').style.cursor = S.zoom ? 'grab' : '';
}
function setZoom(on) {
  S.zoom = on; $('#zoomBtn').setAttribute('aria-pressed', on); $('#zoom').disabled = !on;
  if (on) { const h = PAGES[S.page].id === 'home' ? [.68, .4] : [.7, .36]; S.zx = h[0]; S.zy = h[1]; bot.wide.t = 1.15; bot.look(-.9, -.5, false); bot.at(.8, () => bot.wide.t = 1); }
  applyZoom(); log(`zoom ${on ? S.z.toFixed(1) + '×' : 'off'}`);
}
