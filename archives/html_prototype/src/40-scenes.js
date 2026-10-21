/* A · static layer markup. Each scene = one pre-rendered BMP on the FPGA. */
const $ = s => document.querySelector(s);
const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const IMG = k => ASSETS[k];
const CHROME = `<div class="chrome"><span class="wordmark">ANLOGIC</span><span class="wordmark-cn">安路科技</span></div>`;

function heroFig(p) {
  return `<figure class="hero"><i class="glow"></i><i class="floor"></i><img src="${IMG(p.img)}" alt="${esc(p.en)} 官方产品图"></figure>`;
}
function specList(list) {
  return `<dl class="specs">${list.map((s, i) => `<div class="spec" data-in style="--i:${i + 4}"><dt class="num">${esc(s[0])}<small>${esc(s[1])}</small></dt><dd><p>${esc(s[2])}</p></dd></div>`).join('')}</dl>`;
}
function deviceLine(list) {
  return `<div class="device" data-in style="--i:7">${list.map(d => `<span${d[2] ? ' class="lead"' : ''}><b>${esc(d[1])}</b>${esc(d[0])}</span>`).join('')}</div>`;
}

function sceneHTML(p) {
  if (p.id === 'home') {
    const fam = FAMILY.map(f => `<img class="pc" src="${IMG(f[0])}" alt="${f[4]}系列产品图" style="--x:${f[1]}px;--y:${f[2]}px;--w:${f[3]}px">`).join('');
    const tags = FAMILY.map(f => { const [x, y] = TAG_POS[f[0]]; return `<span class="tag" style="--x:${x}px;--y:${y}px"><i style="background:${f[5]}"></i><b>${f[4]}</b>${f[6]}</span>`; }).join('');
    return `<div class="bg"></div>${CHROME}
      <figure class="family">${fam}${tags}</figure>
      <div class="copy"><p class="kicker" data-in style="--i:0">${esc(p.kicker)}</p><h2 class="cn" data-in style="--i:1">${esc(p.cn)}</h2>
        <p class="lede" data-in style="--i:2">${esc(p.lede)}</p></div>
      ${specList([['4', '', 'FPGA 产品系列'], ['4', '', '解决方案领域'], ['640×480', '', '本展台 HDMI 输出']])}
      ${deviceLine([['', '可编程器件', 1], ['', '开发软件'], ['', '评估板与下载器'], ['', '产品图来自安路科技官网']])}
      <span class="credit">产品图：安路科技官网</span>`;
  }
  if (p.id === 'eco') {
    return `<div class="bg"></div>${CHROME}
      <figure class="hero"><img src="${IMG('board')}" alt="安路开发板官方图片"></figure>
      <div class="copy"><p class="kicker" data-in style="--i:0">${esc(p.kicker)}</p><h2 class="cn" data-in style="--i:1">${esc(p.cn)}</h2></div>
      <ul class="apps">${p.apps.map((a, i) => `<li data-in style="--i:${i + 2}"><img src="${IMG(a[0])}" alt="${esc(a[1])}"><span><b>${esc(a[1])}</b>${esc(a[2])}</span></li>`).join('')}</ul>
      ${deviceLine(p.device)}
      <span class="credit">图片来源：安路科技官网</span>`;
  }
  return `<div class="bg"></div>${CHROME}<div class="giant">${esc(p.en)}</div>${heroFig(p)}
    <div class="copy"><p class="kicker" data-in style="--i:0">${esc(p.kicker)}</p><h2 class="cn" data-in style="--i:1">${esc(p.cn)}</h2>
      <p class="model" data-in style="--i:2">${esc(p.model)}</p><p class="lede" data-in style="--i:3">${esc(p.lede)}</p></div>
    ${specList(p.specs)}${deviceLine(p.device)}
    <span class="credit">产品图：安路科技官网</span>`;
}

function compareHTML(a, b) {
  const half = (p, side) => `<div class="half ${side} ${p.cls}"><div class="bg"></div>${heroFig(p)}
    <div class="meta"><p class="kicker">${esc(p.kicker)}</p><h3>${esc(p.cn)}<span>${esc(p.model)}</span></h3>
    <dl>${p.cmp.map(r => `<dt>${esc(r[0])}</dt><dd>${esc(r[1])}</dd>`).join('')}</dl></div></div>`;
  return half(a, 'l') + half(b, 'r') + `<i class="seam"></i><div class="cmp-title">双图对比</div>`;
}
