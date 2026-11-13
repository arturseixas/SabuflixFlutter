'use strict';
/* Interface, cenas e fluxo do jogo. */
const $ = (s, r) => (r || document).querySelector(s);
function el(tag, attrs, kids) {
  const e = document.createElement(tag);
  if (attrs) for (const k in attrs) {
    if (k === 'class') e.className = attrs[k];
    else if (k === 'text') e.textContent = attrs[k];
    else if (k === 'html') e.innerHTML = attrs[k];
    else if (k.startsWith('on')) e.addEventListener(k.slice(2), attrs[k]);
    else if (attrs[k] !== false && attrs[k] != null) e.setAttribute(k, attrs[k]);
  }
  if (kids) for (const c of [].concat(kids)) if (c != null) e.append(c.nodeType ? c : document.createTextNode(c));
  return e;
}
const wait = ms => new Promise(r => setTimeout(r, ms));
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

/* ---------- ícones em pixel ---------- */
const ICONS = {};
function makeIcons() {
  const def = {
    coin: g => { ell(g, 5, 5, 4, 4, '#a35f12'); ell(g, 5, 5, 3.4, 3.4, '#f7c232'); vl(g, 5, 3, 5, '#a35f12'); P(g, 3, 3, '#fff4b8'); },
    flor: g => flower(g, 5, 5, 1),
    semente: g => { ell(g, 5, 5, 2, 3.4, '#3b1d17'); vl(g, 5, 3, 4, '#efe8dc'); P(g, 4, 3, '#8a5231'); },
    heart: g => { R(g, 2, 3, 2, 2, '#e2605c'); R(g, 6, 3, 2, 2, '#e2605c'); R(g, 1, 4, 8, 2, '#e2605c'); R(g, 2, 6, 6, 1, '#e2605c'); R(g, 3, 7, 4, 1, '#e2605c'); R(g, 4, 8, 2, 1, '#e2605c'); P(g, 2, 4, '#f8b0a8'); },
    heart0: g => { R(g, 2, 3, 2, 2, '#766d78'); R(g, 6, 3, 2, 2, '#766d78'); R(g, 1, 4, 8, 2, '#766d78'); R(g, 2, 6, 6, 1, '#766d78'); R(g, 3, 7, 4, 1, '#766d78'); R(g, 4, 8, 2, 1, '#766d78'); },
    star: g => { const c = '#f7c232'; vl(g, 5, 1, 3, c); R(g, 1, 4, 9, 2, c); R(g, 3, 6, 5, 1, c); R(g, 2, 7, 2, 2, c); R(g, 7, 7, 2, 2, c); R(g, 4, 3, 3, 4, c); },
    star0: g => { const c = '#a9a0a3'; vl(g, 5, 1, 3, c); R(g, 1, 4, 9, 2, c); R(g, 3, 6, 5, 1, c); R(g, 2, 7, 2, 2, c); R(g, 7, 7, 2, 2, c); R(g, 4, 3, 3, 4, c); },
    mail: g => { R(g, 1, 2, 9, 7, '#fdf0cf'); ln(g, 1, 2, 5, 6, '#a56540'); ln(g, 9, 2, 5, 6, '#a56540'); R(g, 1, 8, 9, 1, '#c98b52'); },
    book: g => { R(g, 1, 1, 8, 9, '#7a2638'); R(g, 2, 2, 6, 7, '#a2352f'); R(g, 7, 1, 2, 9, '#fdf0cf'); hl(g, 3, 4, 3, '#f7c232'); },
    gear: g => { ell(g, 5, 5, 4, 4, '#766d78'); ell(g, 5, 5, 1.5, 1.5, '#2f3142'); for (let i = 0; i < 8; i++) { const a = i / 8 * Math.PI * 2; P(g, 5 + Math.round(Math.cos(a) * 5), 5 + Math.round(Math.sin(a) * 5), '#766d78'); } },
    shop: g => { R(g, 1, 4, 9, 6, '#c98b52'); for (let i = 0; i < 9; i++) R(g, 1 + i, 2, 1, 3, i % 2 ? '#fdf0cf' : '#a2352f'); R(g, 4, 6, 3, 4, '#59302d'); },
    brush: g => { ln(g, 2, 9, 7, 4, '#a56540'); R(g, 7, 1, 3, 4, '#cd5b3b'); P(g, 6, 4, '#c3cad6'); },
    garden: g => drawSunflowerStage(g, 5, 10, 4, 0),
    sol: g => { ell(g, 5, 5, 3, 3, '#f7c232'); for (let i = 0; i < 8; i++) { const a = i / 8 * Math.PI * 2; P(g, 5 + Math.round(Math.cos(a) * 5), 5 + Math.round(Math.sin(a) * 5), '#f7c232'); } },
    chuva: g => { ell(g, 5, 4, 4, 2.5, '#a9a0a3'); ell(g, 3, 4, 2, 2, '#c9c0bd'); vl(g, 3, 7, 2, '#6ba3d7'); vl(g, 6, 8, 2, '#6ba3d7'); },
    nublado: g => { ell(g, 5, 5, 4, 2.5, '#c9c0bd'); ell(g, 3, 4, 2.5, 2.5, '#efe8dc'); ell(g, 7, 4, 2, 2, '#dad3cc'); },
    cup: g => { R(g, 2, 4, 6, 5, '#fdf0cf'); R(g, 8, 5, 2, 3, '#dad3cc'); ell(g, 5, 4, 3, 1, '#5e3120'); vl(g, 4, 1, 2, '#ffffff'); vl(g, 6, 0, 2, '#ffffff'); },
  };
  for (const k in def) { const g = mk(11, 11); def[k](g); ICONS[k] = g.canvas.toDataURL(); }
}
function ico(k, cls) { return el('img', { src: ICONS[k], class: 'ico ' + (cls || ''), alt: '' }); }
const _portraits = new Map();
function portrait(spec, expr) {
  const key = JSON.stringify(spec) + (expr || '');
  if (_portraits.has(key)) return _portraits.get(key);
  const c = drawChar(spec, { expr: expr || 'feliz' });
  const g = mk(56, 56); g.drawImage(c, -8, -2);
  const url = g.canvas.toDataURL(); _portraits.set(key, url); return url;
}
function canvasURL(fn, w, h) { const g = mk(w, h); fn(g); return g.canvas.toDataURL(); }

/* ---------- layout ---------- */
let CANVAS, SCREEN, BUF, ZOOM, LAYOUT = { u: 2, portrait: false };
function layout() {
  const vw = window.innerWidth, vh = window.innerHeight;
  const portrait = vw / vh < 1.2;
  const stage = $('#stage'), dock = $('#dock'), hud = $('#hud');
  let sw, sh, sx, sy;
  if (portrait) {
    sw = vw; sh = Math.round(vw * 9 / 16);
    if (sh > vh * .5) { sh = Math.round(vh * .5); sw = Math.round(sh * 16 / 9); }
    sx = Math.round((vw - sw) / 2); sy = 0;
  } else {
    const s = Math.min(vw / W, vh / H);
    sw = Math.round(W * s); sh = Math.round(H * s); sx = Math.round((vw - sw) / 2); sy = Math.round((vh - sh) / 2);
  }
  const u = sw / W;
  LAYOUT = { u, portrait, sw, sh, sx, sy };
  Object.assign(stage.style, { left: sx + 'px', top: sy + 'px', width: sw + 'px', height: sh + 'px' });
  document.documentElement.style.setProperty('--u', u + 'px');
  document.body.classList.toggle('portrait', portrait);
  const fs = portrait ? 15 : clamp(Math.round(u * 6.4), 13, 23);
  document.documentElement.style.setProperty('--fs', fs + 'px');
  if (portrait) {
    Object.assign(dock.style, { left: '0px', top: (sy + sh) + 'px', width: vw + 'px', bottom: '0px', height: 'auto' });
    if (hud.parentNode !== dock) dock.prepend(hud);
  } else {
    Object.assign(dock.style, { left: (sx + 8 * u) + 'px', width: (sw - 16 * u) + 'px', top: 'auto', bottom: (vh - sy - sh + 5 * u) + 'px', height: 'auto' });
    if (hud.parentNode !== stage) stage.append(hud);
  }
  const dpr = window.devicePixelRatio || 1;
  CANVAS.width = Math.round(sw * dpr); CANVAS.height = Math.round(sh * dpr);
  CANVAS.style.width = sw + 'px'; CANVAS.style.height = sh + 'px';
  SCREEN = CANVAS.getContext('2d', { alpha: false }); SCREEN.imageSmoothingEnabled = false;
}

/* ---------- vista ---------- */
const VIEW = { scene: 'facade', t: .12, main: null, second: null, drink: null, cups: 0, brew: null, tables: {}, bell: 0, closed: false, weather: 'sol', speaking: null, talk: false, finale: false };
function renderState() {
  const info = dayInfo();
  const giftsShown = {};
  for (const k in S.gifts) if (S.decor.interior.gifts[k] !== false) giftsShown[k] = 1;
  const top = topMenu();
  return {
    cafeName: S.cafeName, coins: S.coins, weather: VIEW.weather, season: info.season, festa: info.festa, decor: S.decor, gifts: giftsShown,
    flags: S.flags, _tables: VIEW.tables, _menuPreview: top, _bell: VIEW.bell, _closed: VIEW.closed, garden: S.garden.map(b => b ? { stage: bedStage(b) } : null), foundedYear: S.foundedYear,
  };
}
let _menuCache = { k: '', v: [] };
function topMenu() {
  const k = S.nivel + '|' + Object.keys(S.kits).length + '|' + dayInfo().key;
  if (_menuCache.k === k) return _menuCache.v;
  const rd = receitaDoDia();
  const ids = [rd].concat(Object.keys(RECEITAS).filter(id => id !== rd && receitaPossivel(id) && !RECEITAS[id].secreta).slice(0, 3));
  _menuCache = { k, v: ids.map(id => [RECEITAS[id].nome.length > 13 ? RECEITAS[id].nome.slice(0, 12) + '.' : RECEITAS[id].nome, String(RECEITAS[id].preco)]) };
  return _menuCache.v;
}
let lastT = 0, TIME = 0;
function frame(now) {
  const dt = Math.min(.05, (now - lastT) / 1000 || 0); lastT = now; TIME += dt;
  if (VIEW.bell > 0) VIEW.bell -= dt;
  const g = BUF, rs = renderState();
  if (VIEW.scene === 'facade') drawFacade(g, rs, VIEW.t, TIME);
  else if (VIEW.scene === 'cafe') drawCafe(g, rs);
  else if (VIEW.scene === 'brew') drawBrew(g, rs, dt);
  fxStep(g);
  // luz da hora do dia
  if (VIEW.scene !== 'brew') {
    const tint = lightTint(VIEW.t);
    if (tint !== '#ffffff') { g.globalCompositeOperation = 'multiply'; g.fillStyle = tint; g.fillRect(0, 0, W, H); g.globalCompositeOperation = 'source-over'; }
    if (VIEW.scene === 'cafe' && VIEW.t > .6) { g.globalCompositeOperation = 'lighter'; g.globalAlpha = .08; ell(g, 160, 60, 90, 50, '#ffcf8a'); g.globalAlpha = 1; g.globalCompositeOperation = 'source-over'; }
  }
  SCREEN.drawImage(BUF.canvas, 0, 0, W, H, 0, 0, CANVAS.width, CANVAS.height);
  requestAnimationFrame(frame);
}
function charSprite(who, slot) {
  const blink = (TIME + slot * 1.7) % 4.2 < .13;
  const talk = VIEW.talk && VIEW.speaking === slot && Math.floor(TIME * 9) % 2 === 0;
  return drawChar(who.spec, { expr: who.expr || 'neutro', blink, talk });
}
function drawCafe(g, rs) {
  drawInterior(g, rs, VIEW.t, TIME);
  const slots = [];
  if (VIEW.main) slots.push(['main', VIEW.main]);
  if (VIEW.second) slots.push(['second', VIEW.second]);
  const dual = slots.length === 2;
  for (const [slot, who] of slots) {
    who.enter = Math.min(1, (who.enter || 0) + .06);
    const x = dual ? (slot === 'main' ? 128 : 196) : 160;
    const y = 136 - CH_H + 6 + Math.round((1 - who.enter) * 6) + (Math.floor(TIME * 1.1 + (slot === 'main' ? 0 : 1)) % 2);
    g.globalAlpha = who.leaving ? Math.max(0, 1 - who.leaving) : who.enter;
    g.drawImage(charSprite(who, slot), x - CH_W / 2, y);
    g.globalAlpha = 1;
    if (who.leaving) who.leaving += .07;
  }
  drawCounter(g, rs, ownedKitForCounter(), TIME);
  if (VIEW.drink) {
    const x = dual ? 140 : 168;
    drawDrink(g, x, 136, VIEW.drink.vis, TIME);
    if (VIEW.drink.food) drawFood(g, x + 18, 137, VIEW.drink.food);
  }
  if (VIEW.cups >= 2) drawDrink(g, 196, 136, { cup: 'xicara', steam: true }, TIME + 1);
}
function ownedKitForCounter() { return S.kits.espresso ? 'espresso' : S.kits.moka ? 'moka' : 'coador'; }

/* ---------- toasts, HUD ---------- */
const UI = {
  toast(msg, icon) {
    const t = el('div', { class: 'toast' }, [icon ? ico(icon) : null, el('span', { text: tpl(msg) })]);
    $('#toasts').append(t); setTimeout(() => t.classList.add('out'), 3400); setTimeout(() => t.remove(), 4000);
  },
};
function hud(show) {
  const h = $('#hud');
  h.hidden = !show;
  if (!show) return;
  const hh = Math.floor(7 + VIEW.t * 11), mm = Math.floor(((7 + VIEW.t * 11) % 1) * 60 / 10) * 10;
  const pct = Math.round(S.xp / xpNeed(S.nivel) * 100);
  const unread = S.cartas.filter(c => !c.lida).length;
  h.replaceChildren(
    el('div', { class: 'hud-l' }, [
      el('span', { class: 'pill' }, [ico('coin'), el('b', { text: S.coins })]),
      el('span', { class: 'pill' }, [ico('flor'), el('b', { text: S.flores })]),
      el('span', { class: 'pill lvl', title: 'Nível do café' }, [el('b', { text: 'Nv ' + S.nivel }), el('i', { class: 'bar' }, el('i', { style: 'width:' + pct + '%' }))]),
      el('span', { class: 'pill dim' }, [el('b', { text: 'Dia ' + S.dia + (VIEW.scene === 'cafe' ? ' · ' + hh + 'h' + String(mm).padStart(2, '0') : '') })]),
    ]),
    el('div', { class: 'hud-r' }, [
      el('button', { class: 'ibtn', title: 'Caderninho', 'aria-label': 'Caderninho', onclick: () => openCaderno() }, ico('book')),
      el('button', { class: 'ibtn' + (unread ? ' badge' : ''), title: 'Cartas', 'aria-label': 'Cartas', onclick: () => openCartas() }, ico('mail')),
      el('button', { class: 'ibtn', title: 'Opções', 'aria-label': 'Opções', onclick: () => openOpcoes() }, ico('gear')),
    ]));
}

/* ---------- diálogo ---------- */
const DLG = { resolve: null, typing: false, full: '', shown: 0 };
function parseLine(raw) {
  let s = tpl(raw);
  if (s.startsWith('*')) return { kind: 'narr', text: s.replace(/^\*|\*$/g, '') };
  if (s.startsWith('> ')) return { kind: 'player', text: s.slice(2) };
  let m = s.match(/^@(\w+)(?:\[(\w+)\])?\s*(.*)$/);
  if (m) return { kind: 'other', id: m[1], expr: m[2] || 'neutro', text: m[3] };
  m = s.match(/^P(?:\[(\w+)\])?:\s*(.*)$/);
  if (m) return { kind: 'main', expr: m[1] || 'neutro', text: m[2] };
  m = s.match(/^\[(\w+)\]\s*(.*)$/);
  if (m) return { kind: 'main', expr: m[1], text: m[2] };
  return { kind: 'main', expr: null, text: s };
}
function specFor(id) {
  const C = REGULARES[id], st = regState(id);
  let spec = Object.assign({}, C.spec);
  if (st.final && C.specFinal) spec = Object.assign(spec, C.specFinal);
  return spec;
}
async function say(lines) {
  const box = $('#dlg');
  box.hidden = false; $('#ctrl').hidden = true;
  for (const raw of lines) {
    const L = parseLine(raw);
    let name = '', cls = '';
    VIEW.speaking = null;
    if (L.kind === 'narr') { cls = 'narr'; }
    else if (L.kind === 'player') { name = S.nome || 'Você'; cls = 'me'; }
    else if (L.kind === 'other') {
      if (VIEW.main && VIEW.main.id === L.id) { VIEW.main.expr = L.expr; VIEW.speaking = 'main'; name = VIEW.main.name; }
      else {
        if (!VIEW.second || VIEW.second.id !== L.id) VIEW.second = { id: L.id, spec: specFor(L.id), name: REGULARES[L.id].nome, expr: L.expr, enter: 0 };
        VIEW.second.expr = L.expr; VIEW.speaking = 'second'; name = VIEW.second.name;
      }
    } else if (VIEW.main) { if (L.expr) VIEW.main.expr = L.expr; VIEW.speaking = 'main'; name = VIEW.main.name; }
    box.className = 'dlg ' + cls;
    $('.dlg-name', box).textContent = name; $('.dlg-name', box).hidden = !name;
    await typeLine($('.dlg-text', box), L.text);
  }
  VIEW.speaking = null;
}
function typeLine(node, text) {
  return new Promise(res => {
    DLG.full = text; DLG.shown = 0; DLG.typing = true; DLG.resolve = res; VIEW.talk = true;
    node.textContent = '';
    $('#dlg .dlg-next').hidden = true;
    const speed = S.opts.rapido ? 999 : 48;
    let acc = 0, last = performance.now();
    const tick = (now) => {
      if (!DLG.typing) return;
      acc += (now - last) / 1000 * speed; last = now;
      const n = Math.min(text.length, Math.floor(acc));
      if (n !== DLG.shown) { DLG.shown = n; node.textContent = text.slice(0, n); }
      if (n >= text.length) { DLG.typing = false; VIEW.talk = false; $('#dlg .dlg-next').hidden = false; return; }
      requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
    DLG.node = node;
  });
}
function dlgAdvance() {
  if (DLG.typing) { DLG.typing = false; VIEW.talk = false; DLG.node.textContent = DLG.full; $('#dlg .dlg-next').hidden = false; return; }
  if (DLG.resolve) { const r = DLG.resolve; DLG.resolve = null; AUD.sfx('click'); r(); }
}
function choose(opts, prompt) {
  return new Promise(res => {
    if (prompt) { const box = $('#dlg'); box.hidden = false; box.className = 'dlg narr'; $('.dlg-name', box).hidden = true; $('.dlg-text', box).textContent = tpl(prompt); $('#dlg .dlg-next').hidden = true; }
    else $('#dlg').hidden = true;
    const c = $('#ctrl'); c.hidden = false; c.className = 'ctrl choices';
    c.replaceChildren(...opts.map((o, i) => el('button', { class: 'btn choice', onclick: () => { AUD.sfx('click'); c.hidden = true; res(i); } }, [el('span', { class: 'k', text: (i + 1) + '' }), tpl(o)])));
  });
}
function buttons(list, cls) {
  return new Promise(res => {
    const c = $('#ctrl'); c.hidden = false; c.className = 'ctrl ' + (cls || '');
    $('#dlg').hidden = true;
    c.replaceChildren(...list.map(b => el('button', { class: 'btn ' + (b.cls || ''), disabled: b.disabled ? 'disabled' : false, onclick: () => { AUD.sfx('click'); if (b.keep) { b.keep(); return; } res(b.v); } }, [b.icon ? ico(b.icon) : null, b.label])));
  });
}

/* ---------- modais ---------- */
let MODAL_OPEN = false;
function modal(title, tabs, opts) {
  opts = opts || {};
  return new Promise(res => {
    MODAL_OPEN = true;
    const m = $('#modal');
    const body = el('div', { class: 'm-body' });
    const tabBar = el('div', { class: 'tabs', role: 'tablist' });
    let cur = 0;
    const close = () => { m.hidden = true; MODAL_OPEN = false; m.replaceChildren(); hud(!$('#hud').hidden); res(); if (opts.onclose) opts.onclose(); };
    const show = (i) => {
      cur = i; tabBar.querySelectorAll('button').forEach((b, j) => b.setAttribute('aria-selected', j === i));
      body.replaceChildren(); tabs[i].render(body, () => show(cur), close); body.scrollTop = 0;
    };
    tabs.forEach((t, i) => tabBar.append(el('button', { role: 'tab', class: 'tab', onclick: () => { AUD.sfx('page'); show(i); } }, t.label)));
    const panel = el('div', { class: 'panel ' + (opts.cls || '') }, [
      el('div', { class: 'm-head' }, [el('h2', { text: title }), opts.noclose ? null : el('button', { class: 'ibtn close', 'aria-label': 'Fechar', onclick: () => { AUD.sfx('click'); close(); } }, '×')]),
      tabs.length > 1 ? tabBar : null, body]);
    m.replaceChildren(panel); m.hidden = false;
    m.onclick = (e) => { if (e.target === m && !opts.noclose) close(); };
    show(opts.tab || 0);
  });
}

/* ---------- jardim ---------- */
function bedStage(b) { if (!b) return -1; return clamp(Math.floor((Date.now() - b.em + (b.bonus || 0)) / STAGE_MS), 0, 4); }
function bedNext(b) { const st = bedStage(b); if (st >= 4) return 0; return (st + 1) * STAGE_MS - (Date.now() - b.em + (b.bonus || 0)); }
function fmtDur(ms) { const h = Math.floor(ms / HOUR), m = Math.ceil((ms % HOUR) / 60000); return h ? h + 'h ' + m + 'min' : m + 'min'; }
function openJardim() {
  return modal('Canteiros de girassol', [{ label: 'Jardim', render(b, redo) {
    b.append(el('p', { class: 'muted', text: 'Girassol cresce no tempo real: uma fase a cada 6 horas. Cada dia de café aberto também adianta uma fase. Nada murcha se você não vier.' }));
    b.append(el('p', {}, [ico('semente'), ' Sementes: ', el('b', { text: S.sementes }), '   ', ico('flor'), ' Girassóis colhidos: ', el('b', { text: S.flores })]));
    const grid = el('div', { class: 'grid4' });
    S.garden.forEach((bed, i) => {
      const st = bedStage(bed);
      const img = el('img', { class: 'pix big', alt: '', src: canvasURL(g => { R(g, 0, 26, 32, 6, '#7c4635'); R(g, 1, 27, 30, 3, '#3b1d17'); if (bed) drawSunflowerStage(g, 16, 27, st, 0); }, 32, 32) });
      let info, btn;
      if (!bed) { info = 'Vazio'; btn = el('button', { class: 'btn sm', disabled: S.sementes ? false : 'disabled', onclick: () => { S.sementes--; S.garden[i] = { em: Date.now(), bonus: 0 }; AUD.sfx('good'); save(); redo(); } }, 'Plantar'); }
      else if (st >= 4) { info = 'Florido!'; btn = el('button', { class: 'btn sm primary', onclick: () => { const ganho = 3 + (Math.random() < .3 ? 1 : 0); S.flores += ganho; S.sementes += Math.random() < .5 ? 2 : 1; S.garden[i] = null; AUD.sfx('chime'); UI.toast('+' + ganho + ' girassóis', 'flor'); save(); redo(); } }, 'Colher'); }
      else { info = ['Semente', 'Broto', 'Muda', 'Botão'][st] + ' · próxima fase em ' + fmtDur(bedNext(bed)); btn = null; }
      grid.append(el('div', { class: 'card center' }, [img, el('div', { class: 'small', text: info }), btn]));
    });
    b.append(grid);
    b.append(el('p', { class: 'muted small', text: 'Girassóis colhidos compram enfeites especiais na aba Decorar.' }));
  } }]);
}

/* ---------- loja ---------- */
function openLoja(tab) {
  const buy = (preco, fn, redo) => { if (S.coins < preco) { UI.toast('Faltam ' + (preco - S.coins) + ' moedas.'); AUD.sfx('meh'); return; } S.coins -= preco; fn(); AUD.sfx('coin'); save(); redo(); hud(true); };
  const row = (iconURL, nome, desc, right) => el('div', { class: 'row' }, [iconURL ? el('img', { class: 'pix', src: iconURL, alt: '' }) : null, el('div', { class: 'grow' }, [el('b', { text: nome }), el('div', { class: 'small muted', text: desc })]), right]);
  const lockOr = (nivel, owned, preco, onbuy) => owned ? el('span', { class: 'tag ok', text: 'Seu' }) : S.nivel < nivel ? el('span', { class: 'tag', text: 'Nível ' + nivel }) : el('button', { class: 'btn sm', onclick: onbuy }, [ico('coin'), ' ' + preco]);
  return modal('Loja do café', [
    { label: 'Kits', render(b, redo) { for (const k of KIT_ORDER) { const K = KITS[k]; b.append(row(kitIconCanvas(k, 32).toDataURL(), K.nome, K.desc, lockOr(K.nivel, S.kits[k], K.preco, () => buy(K.preco, () => { S.kits[k] = 1; UI.toast('Novo kit: ' + K.nome); }, redo)))); } } },
    { label: 'Ingredientes', render(b, redo) { for (const k of ING_ORDER) { const I = INGREDIENTES[k]; if (I.sazonal) { b.append(row(null, I.nome, 'Só durante ' + FESTA_NOMES[I.sazonal] + '.', el('span', { class: 'tag' + (ingDisponivel(k) ? ' ok' : ''), text: ingDisponivel(k) ? 'Disponível' : 'Sazonal' }))); continue; } const auto = I.preco === 0; const owned = ingDisponivel(k); b.append(row(null, I.nome, I.requer ? 'Vem com: ' + KITS[I.requer].nome : auto ? 'Liberado no nível ' + I.nivel : '', auto ? el('span', { class: 'tag' + (owned ? ' ok' : ''), text: owned ? 'Seu' : I.requer ? 'Precisa do kit' : 'Nível ' + I.nivel }) : lockOr(I.nivel, S.ings[k], I.preco, () => buy(I.preco, () => { S.ings[k] = 1; }, redo)))); } } },
    { label: 'Grãos', render(b, redo) { for (const k in GRAOS) { const G = GRAOS[k]; const owned = S.graos[k]; const right = owned ? (S.graoAtivo === k ? el('span', { class: 'tag ok', text: 'Em uso' }) : el('button', { class: 'btn sm', onclick: () => { S.graoAtivo = k; save(); redo(); } }, 'Usar')) : lockOr(G.nivel, false, G.preco, () => buy(G.preco, () => { S.graos[k] = 1; S.graoAtivo = k; }, redo)); b.append(row(null, G.nome + ' · ' + G.regiao, G.notas + (G.bonus ? ' Bebidas com café rendem +' + Math.round(G.bonus * 100) + '%.' : ''), right)); } } },
    { label: 'Quitandas', render(b, redo) { for (const k in QUITANDAS) { const Q = QUITANDAS[k]; b.append(row(canvasURL(g => drawFood(g, 8, 14, k), 16, 16), Q.nome, 'Vende por ' + Q.preco + ' moedas.', lockOr(Q.nivel, S.quitandas[k], Q.custo, () => buy(Q.custo, () => { S.quitandas[k] = 1; }, redo)))); } } },
  ], { tab: tab || 0 });
}

/* ---------- decorar ---------- */
function openDecorar() {
  const apply = (d) => { const [area, campo, val] = d.campo; if (d.toggle) S.decor[area][campo] = !S.decor[area][campo]; else S.decor[area][campo] = val; save(); };
  const isOn = d => { const [area, campo, val] = d.campo; return d.toggle ? !!S.decor[area][campo] : S.decor[area][campo] === val; };
  const renderCat = (cat) => (b, redo) => {
    const groups = {};
    DECOR.filter(d => d.cat === cat).forEach(d => (groups[d.grupo] = groups[d.grupo] || []).push(d));
    for (const gname in groups) {
      b.append(el('h3', { text: gname }));
      const wrap = el('div', { class: 'chips' });
      for (const d of groups[gname]) {
        const owned = S.owned[d.id] || (!d.preco && !d.flores);
        const on = isOn(d);
        const label = [d.nome];
        if (!owned) { if (d.preco) label.push(el('span', { class: 'cost' }, [ico('coin'), d.preco])); if (d.flores) label.push(el('span', { class: 'cost' }, [ico('flor'), d.flores])); }
        wrap.append(el('button', { class: 'chip' + (on ? ' on' : '') + (owned ? '' : ' locked'), 'aria-pressed': on, onclick: () => {
          if (!owned) {
            if (S.coins < (d.preco || 0) || S.flores < (d.flores || 0)) { UI.toast('Ainda não dá: faltam ' + (d.preco > S.coins ? (d.preco - S.coins) + ' moedas' : (d.flores - S.flores) + ' girassóis') + '.'); AUD.sfx('meh'); return; }
            S.coins -= d.preco || 0; S.flores -= d.flores || 0; S.owned[d.id] = 1; AUD.sfx('coin');
          } else AUD.sfx('click');
          apply(d); hud(!$('#hud').hidden); redo();
        } }, label));
      }
      b.append(wrap);
    }
  };
  return modal('Decorar', [
    { label: 'Nome', render(b, redo) {
      b.append(el('p', { class: 'muted', text: 'O nome aparece no letreiro, no vidro da janela e no cardápio.' }));
      const inp = el('input', { id: 'cafe-nome', class: 'inp', maxlength: 22, value: S.cafeName });
      b.append(el('label', { for: 'cafe-nome', class: 'lbl', text: 'Nome do café' }), inp, el('button', { class: 'btn primary', onclick: () => { const v = inp.value.trim(); if (v) { S.cafeName = v; _txtCache.clear(); save(); UI.toast('Letreiro novo: ' + v); AUD.sfx('chime'); } } }, 'Pintar o letreiro'));
    } },
    { label: 'Fachada', render: renderCat('fachada') },
    { label: 'Interior', render: renderCat('interior') },
    { label: 'Presentes', render(b, redo) {
      b.append(el('p', { class: 'muted', text: 'Coisas que as pessoas deixaram no café. Você escolhe o que fica à mostra.' }));
      const ks = Object.keys(S.gifts);
      if (!ks.length) b.append(el('p', { text: 'Nenhum presente ainda.' }));
      for (const k of ks) {
        const [nome, desc] = GIFT_NOMES[k] || [k, ''];
        const on = S.decor.interior.gifts[k] !== false;
        b.append(el('div', { class: 'row' }, [el('div', { class: 'grow' }, [el('b', { text: nome }), el('div', { class: 'small muted', text: desc })]), k === 'fotovo' ? el('span', { class: 'tag ok', text: 'Sempre' }) : el('button', { class: 'btn sm' + (on ? ' primary' : ''), onclick: () => { S.decor.interior.gifts[k] = !on; save(); redo(); } }, on ? 'À mostra' : 'Guardado')]));
      }
    } },
  ], { onclose: () => { VIEW.scene === 'facade' && hud(true); } });
}

/* ---------- caderninho ---------- */
function memoriaDe(id, i) { return (MEMORIAS[id] && MEMORIAS[id][i]) || ''; }
function openCaderno(tab) {
  return modal('Caderninho', [
    { label: 'Fregueses', render(b) {
      for (const id of REG_ORDER) {
        const C = REGULARES[id], st = S.reg[id];
        if (!st || !st.intro) { b.append(el('div', { class: 'row dim' }, [el('div', { class: 'ph' }), el('div', { class: 'grow' }, [el('b', { text: '???' }), el('div', { class: 'small muted', text: 'Alguém que ainda não apareceu.' })])])); continue; }
        const lv = afinLevel(st.afin);
        const hearts = el('span', { class: 'hearts' }); for (let i = 1; i <= 6; i++) hearts.append(ico(i <= lv ? 'heart' : 'heart0'));
        const mem = el('ul', { class: 'mem' });
        st.visto.slice().sort((a, c) => a - c).forEach(i => { const t = memoriaDe(id, i); if (t) mem.append(el('li', { text: tpl(t) })); });
        const sempre = st.sempreConhecido ? RECEITAS[sempreAtual(id)].nome + (C.comida ? ' + ' + QUITANDAS[C.comida].nome : '') + (st.xicaras > 1 ? ' (duas xícaras)' : '') : '?';
        b.append(el('div', { class: 'row top' }, [el('img', { class: 'pix face', src: portrait(specFor(id)), alt: '' }), el('div', { class: 'grow' }, [
          el('div', {}, [el('b', { text: C.nome }), ' · ', el('span', { class: 'small', text: C.papel + ', ' + C.idade + ' anos' })]), hearts,
          el('div', { class: 'small muted', text: C.resumo }), el('div', { class: 'small' }, [el('b', { text: 'De sempre: ' }), sempre]),
          st.fim ? el('div', { class: 'small ok', text: 'História completa. Ainda aparece de vez em quando.' }) : null, mem])]));
      }
    } },
    { label: 'Receitas', render(b) {
      b.append(el('p', { class: 'muted small', text: 'Receitas aparecem aqui quando você faz pela primeira vez. Combine kit e ingredientes para descobrir as outras.' }));
      for (const k of KIT_ORDER) {
        if (!S.kits[k]) continue;
        b.append(el('h3', {}, [el('img', { class: 'pix', src: kitIconCanvas(k, 24).toDataURL(), alt: '' }), ' ' + KITS[k].nome]));
        const wrap = el('div', { class: 'recs' });
        for (const id in RECEITAS) {
          const r = RECEITAS[id]; if (r.kit !== k) continue;
          const rec = S.receitas[id];
          if (!rec && (r.secreta || r.sazonal)) continue;
          if (!rec) { wrap.append(el('div', { class: 'rec dim' }, [el('b', { text: '???' }), el('div', { class: 'small muted', text: r.adds.length + ' ingrediente' + (r.adds.length === 1 ? '' : 's') })])); continue; }
          const stars = el('span'); for (let i = 1; i <= 3; i++) stars.append(ico(i <= rec.melhor ? 'star' : 'star0'));
          wrap.append(el('div', { class: 'rec' }, [el('b', { text: r.nome }), stars, el('div', { class: 'small muted', text: (r.adds.length ? r.adds.map(a => INGREDIENTES[a].nome).join(' + ') : 'puro') + ' · feito ' + rec.feitas + 'x' })]));
        }
        b.append(wrap);
      }
    } },
    { label: 'Grãos', render(b) {
      for (const k in GRAOS) { const G = GRAOS[k], own = S.graos[k]; b.append(el('div', { class: 'row' + (own ? '' : ' dim') }, [el('div', { class: 'grow' }, [el('b', { text: own ? G.nome : '???' }), el('div', { class: 'small', text: own ? G.regiao + ' · ' + G.notas : 'Disponível na loja a partir do nível ' + G.nivel + '.' }), own ? el('div', { class: 'small muted', text: G.desc }) : null])])); }
    } },
    { label: 'Álbum', render(b) {
      const met = PASSANTES.filter(p => S.album[p.id]);
      b.append(el('p', { class: 'muted small', text: 'Gente de passagem. Todo dia aparece alguém novo. Já passaram ' + met.length + ' de ' + PASSANTES.length + '.' }));
      const grid = el('div', { class: 'album' });
      for (const p of PASSANTES) grid.append(S.album[p.id] ? el('div', { class: 'polaroid' }, [el('img', { class: 'pix', src: portrait(p.spec), alt: '' }), el('div', { class: 'small', text: p.nome }), el('div', { class: 'tiny muted', text: S.album[p.id] })]) : el('div', { class: 'polaroid dim' }, [el('div', { class: 'ph' }), el('div', { class: 'small', text: '???' })]));
      b.append(grid);
    } },
    { label: 'Marcos', render(b) {
      b.append(el('p', {}, ['Dias de casa aberta: ', el('b', { text: S.diasAbertos }), el('span', { class: 'small muted', text: '  (conta cada dia em que você abriu o café, sem precisar ser seguido)' })]));
      for (const m of MARCOS) b.append(el('div', { class: 'row' + (S.marcos[m.dias] ? '' : ' dim') }, [el('b', { text: m.dias + ' dias' }), el('span', { class: 'grow', text: '  ' + m.txt }), S.marcos[m.dias] ? el('span', { class: 'tag ok', text: 'Feito' }) : null]));
      b.append(el('h3', { text: 'Números da casa' }));
      b.append(el('p', { class: 'small', text: 'Fregueses servidos: ' + S.stats.servidos + ' · Cafés de 3 estrelas: ' + S.stats.tres + ' · Moedas ganhas: ' + S.stats.moedas + ' · Receitas descobertas: ' + Object.keys(S.receitas).length + ' de ' + Object.keys(RECEITAS).length }));
    } },
  ], { tab: tab || 0 });
}

/* ---------- cartas ---------- */
function lerCarta(id) {
  const C = CARTAS[id];
  return modal(C.titulo, [{ label: '', render(b) { b.append(el('div', { class: 'letter' }, [el('div', { class: 'small muted', text: 'De: ' + tpl(C.de) }), el('div', { class: 'ltext', text: tpl(C.texto) })])); } }], { cls: 'paper' });
}
function openCartas() {
  return modal('Cartas', [{ label: '', render(b, redo, close) {
    if (!S.cartas.length) { b.append(el('p', { class: 'muted', text: 'Nenhuma carta por enquanto. O carteiro passa todo dia.' })); return; }
    for (const c of S.cartas.slice().reverse()) {
      const C = CARTAS[c.id];
      b.append(el('button', { class: 'row btnrow' + (c.lida ? '' : ' unread'), onclick: async () => { c.lida = true; save(); close(); AUD.sfx('page'); await lerCarta(c.id); openCartas(); } }, [ico('mail'), el('div', { class: 'grow' }, [el('b', { text: C.titulo }), el('div', { class: 'small muted', text: 'De: ' + tpl(C.de) })]), c.lida ? null : el('span', { class: 'tag', text: 'Nova' })]));
    }
  } }]);
}

/* ---------- opções ---------- */
function openOpcoes() {
  return modal('Opções', [{ label: '', render(b, redo, close) {
    const tog = (k, nome, desc) => b.append(el('div', { class: 'row' }, [el('div', { class: 'grow' }, [el('b', { text: nome }), el('div', { class: 'small muted', text: desc })]), el('button', { class: 'btn sm' + (S.opts[k] ? ' primary' : ''), 'aria-pressed': !!S.opts[k], onclick: () => { S.opts[k] = !S.opts[k]; AUD.setOpts(); save(); redo(); } }, S.opts[k] ? 'Ligado' : 'Desligado')]));
    tog('musica', 'Música', 'Bossa tranquila gerada na hora.');
    tog('som', 'Efeitos sonoros', 'Sininho da porta, moedor, vapor, moedas.');
    tog('rapido', 'Texto instantâneo', 'Mostra as falas inteiras de uma vez.');
    tog('dicas', 'Dicas no pedido', 'Lembra o "de sempre" de quem você já conhece.');
    b.append(el('div', { class: 'row' }, [el('div', { class: 'grow' }, [el('b', { text: 'Tela cheia' })]), el('button', { class: 'btn sm', onclick: () => { try { if (!document.fullscreenElement) document.documentElement.requestFullscreen().catch(() => { }); else document.exitFullscreen(); } catch (e) { } } }, 'Alternar')]));
    b.append(el('h3', { text: 'Salvamento' }));
    b.append(el('p', { class: 'small muted', text: 'O jogo salva sozinho neste navegador. Para levar o progresso para outro aparelho, copie o código e cole lá.' }));
    const ta = el('textarea', { id: 'save-code', class: 'inp code', rows: 3, 'aria-label': 'Código do salvamento' });
    b.append(ta, el('div', { class: 'btnline' }, [
      el('button', { class: 'btn sm', onclick: () => { ta.value = exportSave(); ta.select(); try { navigator.clipboard.writeText(ta.value).then(() => UI.toast('Código copiado.'), () => UI.toast('Selecionei o código. Copie manualmente.')); } catch (e) { } } }, 'Gerar código'),
      el('button', { class: 'btn sm', onclick: () => { try { importSave(ta.value); UI.toast('Progresso carregado.'); close(); location.reload(); } catch (e) { UI.toast('Esse código não funcionou. Confira se copiou inteiro.'); } } }, 'Carregar código')]));
    const zone = el('div', { class: 'btnline' });
    zone.append(el('button', { class: 'btn sm danger', onclick: () => { zone.replaceChildren(el('span', { class: 'small', text: 'Apagar todo o progresso? Isso não tem volta.' }), el('button', { class: 'btn sm danger', onclick: () => { try { localStorage.removeItem(SAVE_KEY); } catch (e) { } location.reload(); } }, 'Apagar'), el('button', { class: 'btn sm', onclick: redo }, 'Cancelar')); } }, 'Recomeçar do zero'));
    b.append(el('h3', { text: 'Recomeçar' }), zone);
  } }]);
}

/* ======================================================
   PREPARO
   ====================================================== */
const DEFAULT_CUP = { coador: 'xicara', leiteira: 'caneca', moka: 'xicara', prensa: 'caneca', espresso: 'xicara', v60: 'xicara', coldbrew: 'copoalto', aeropress: 'xicara', chemex: 'caneca', ibrik: 'xicara', sifao: 'taca' };
function drinkVisual(kit, adds, recipe, art, q) {
  const has = a => adds.indexOf(a) >= 0;
  const cup = recipe ? RECEITAS[recipe].copo : DEFAULT_CUP[kit] || 'caneca';
  const strong = ['espresso', 'moka', 'ibrik'].indexOf(kit) >= 0;
  let coffee = kit === 'leiteira' ? (has('chocolate') ? '#6a3a26' : '#f6ecd8') : strong ? PAL.coffee[1] : kit === 'coldbrew' ? '#3b1d17' : PAL.coffee[2];
  if (q != null && q < .45 && kit !== 'leiteira') coffee = mix(coffee, '#a07850', .35);
  const layers = [];
  if (has('condensado')) layers.push({ c: '#f6e5c0', h: .2 });
  if (kit !== 'leiteira') layers.push({ c: coffee, h: has('leite') || has('espuma') ? .3 : .62 });
  if (has('leite') || kit === 'leiteira') layers.push({ c: kit === 'leiteira' ? coffee : mix('#fbf3e3', coffee, .25), h: kit === 'leiteira' ? .66 : .3 });
  if (has('espuma')) layers.push({ c: '#fdf6ea', h: .12 });
  if (has('agua') && !has('leite')) layers[layers.length - 1].c = mix(coffee, '#c08a5a', .25);
  let top = null;
  if (has('chantilly')) top = 'chantilly'; else if (has('canela')) top = 'canela'; else if (has('chocolate') && kit !== 'leiteira') top = 'choco';
  return { cup, layers, foam: has('espuma'), art: art && has('espuma') ? art : null, ice: has('gelo'), top, steam: !has('gelo') && kit !== 'coldbrew', straw: has('gelo') ? '#cd5b3b' : null, syrup: has('chocolate') ? '#5a2e22' : has('mel') ? '#e9b23a' : null };
}

function meterScore(v, zone) {
  const [a, b] = zone, c = (a + b) / 2, hw = (b - a) / 2;
  if (v > 1) return .15;
  const d = Math.abs(v - c);
  if (d <= hw) return 1 - (d / hw) * .2;
  return Math.max(.1, .8 - (d - hw) * 3.2);
}
function scoreWord(s) { return s >= .9 ? 'Perfeito!' : s >= .75 ? 'Muito bom' : s >= .55 ? 'Quase' : 'Passou do ponto'; }

/* desenha a bancada aproximada */
function drawBrew(g, rs, dt) {
  const B = VIEW.brew; if (!B) return;
  const z = ZOOM;
  const D = S.decor.interior;
  const wallBase = { azulejo: '#f4efe6', listras: '#e7c58f', tijolo: '#b85a3a', floral: '#f1e2c3', madeira: '#a56540', verde: '#7fb7a0', rosa: '#e7a3a8' }[D.wall] || '#e7c58f';
  wallPattern(z, 0, 0, 160, 52, D.wall === 'verde' || D.wall === 'rosa' ? 'liso' : D.wall, wallBase);
  // prateleira com potes
  R(z, 96, 22, 64, 3, '#7c4635'); hl(z, 96, 22, 64, '#a56540');
  const jars = ['#b9822d', '#8a5231', '#f6e5c0', '#5a2e22', '#e9b23a'];
  jars.forEach((c, i) => { R(z, 100 + i * 12, 13, 8, 9, 'rgba(220,240,248,0.6)'); R(z, 101 + i * 12, 16, 6, 6, c); R(z, 100 + i * 12, 12, 8, 2, '#c98b52'); });
  const kinds = { madeira: ['#c98b52', '#a56540', '#7c4635'], escura: ['#7c4635', '#59302d', '#3a1f26'], azulejo: ['#efe8dc', '#9bb9da', '#3f6fa6'], marmore: ['#f2ede6', '#dad3cc', '#a9a0a3'] };
  const k = kinds[D.counter] || kinds.madeira;
  R(z, 0, 52, 160, 38, k[0]); hl(z, 0, 52, 160, tone(k[0], 1)); for (let y = 58; y < 90; y += 7) hl(z, 0, y, 160, k[1]);
  dith(z, 0, 53, 160, 37, k[1], 0);
  // moedor manual
  const grinding = B.anim === 'grind';
  const gx = 22, gy = 70;
  R(z, gx - 7, gy - 12, 14, 12, '#7c4635'); hl(z, gx - 7, gy - 12, 14, '#a56540'); R(z, gx - 2, gy - 6, 4, 3, '#3a1f26');
  poly(z, [[gx - 6, gy - 12], [gx + 6, gy - 12], [gx + 4, gy - 18], [gx - 4, gy - 18]], '#c3cad6'); vl(z, gx, gy - 22, 4, '#555a70');
  const ang = grinding ? TIME * 14 : .6; const cx2 = gx + Math.round(Math.cos(ang) * 7), cy2 = gy - 22 + Math.round(Math.sin(ang) * 3);
  ln(z, gx, gy - 22, cx2, cy2, '#555a70'); ell(z, cx2, cy2, 1.5, 1.5, '#59302d');
  if (grinding && Math.random() < .5) fxAdd({ x: (gx - 2 + Math.random() * 4) * 2, y: (gy - 4) * 2, vx: (Math.random() - .5) * .6, vy: .4, life: 1, decay: .05, kind: 'grounds' });
  // chaleira
  const heating = B.anim === 'heat', pouring = B.anim === 'pour';
  let kx = 46, ky = 74;
  if (pouring) { kx = 66; ky = 50; }
  if (!B.kitDef || B.kitDef.temp || pouring) {
    R(z, kx - 9, ky - 1, 18, 2, '#2f3142');
    if (heating) { const fl = Math.floor(TIME * 12) % 2; R(z, kx - 6, ky - 2, 12, 1, fl ? '#ea8b58' : '#f7c232'); }
    const tilt = pouring ? 1 : 0;
    ell(z, kx, ky - 7, 8, 7 - tilt, '#c3cad6'); ell(z, kx - 2, ky - 9, 4, 3, '#eef2f5'); R(z, kx - 4, ky - 15, 8, 2, '#555a70');
    ln(z, kx + 7, ky - 6, kx + 15 + tilt * 4, ky - 14 + tilt * 6, '#8d94a8'); ln(z, kx + 7, ky - 5, kx + 15 + tilt * 4, ky - 13 + tilt * 6, '#c3cad6');
    ln(z, kx - 8, ky - 10, kx - 11, ky - 4, '#2f3142');
    if (heating || (B.temp > .5)) steam(z, kx, ky - 15, TIME, 2);
    if (pouring) { const sx = kx + 15 + tilt * 4, sy = ky - 14 + tilt * 6 + 1; for (let y = sy; y < 62; y++) P(z, sx + Math.round(Math.sin(y * .7 + TIME * 20) * .5), y, 'rgba(200,225,240,0.8)'); }
  }
  // kit
  const kitX = 84, kitY = 78;
  if (B.kit) {
    if (B.kit === 'leiteira') { // leiteira sobre a boca do fogão
      R(z, kitX - 10, kitY - 1, 20, 2, '#2f3142'); if (B.anim === 'hold') { const fl = Math.floor(TIME * 12) % 2; R(z, kitX - 7, kitY - 2, 14, 1, fl ? '#ea8b58' : '#6ba3d7'); }
      R(z, kitX - 8, kitY - 12, 16, 11, '#efe8dc'); hl(z, kitX - 8, kitY - 12, 16, '#ffffff'); vl(z, kitX + 7, kitY - 12, 11, '#c9c0bd'); R(z, kitX + 8, kitY - 10, 9, 2, '#2f3142'); dith(z, kitX - 7, kitY - 11, 14, 10, '#3f6fa6', 0);
      if (B.meter > .5) steam(z, kitX, kitY - 13, TIME, 3);
    } else drawKitIcon(z, kitX, kitY, B.kit, 1, TIME);
    if (B.anim === 'hold' && B.kit === 'espresso') { for (let y = kitY - 10; y < kitY - 5; y++) if (Math.floor(TIME * 20 + y) % 3) P(z, kitX, y, PAL.coffee[2]); }
    if ((B.anim === 'wait') && (B.kit === 'moka' || B.kit === 'ibrik' || B.kit === 'sifao')) { if (Math.random() < .3) AUD.sfx('gurgle'); steam(z, kitX, kitY - 22, TIME, 2 + Math.round(B.meter * 3)); R(z, kitX - 9, kitY, 18, 2, '#2f3142'); R(z, kitX - 6, kitY - 1, 12, 1, Math.floor(TIME * 12) % 2 ? '#ea8b58' : '#6ba3d7'); }
    if (B.anim === 'steamer') { steam(z, 128, 50, TIME * 2, 4); vl(z, 128, 40, 14, '#8d94a8'); }
  }
  // xícara
  if (B.cupVis) drawDrink(z, 128, 79, B.cupVis, B.phase === 'result' ? null : TIME);
  g.drawImage(z.canvas, 0, 0, 160, 90, 0, 0, 320, 180);
  // medidor
  if (B.meterOn) {
    const mx = 70, my = 12, mw = 180;
    R(g, mx - 3, my - 3, mw + 6, 14, PAL.ink); R(g, mx - 2, my - 2, mw + 4, 12, '#3a2130');
    R(g, mx, my, mw, 8, '#59302d');
    for (const zn of B.zones || []) { R(g, mx + zn[0] * mw, my, (zn[1] - zn[0]) * mw, 8, '#4a8648'); hl(g, mx + zn[0] * mw, my, (zn[1] - zn[0]) * mw, '#84b752'); }
    const fillW = clamp(B.meter, 0, 1) * mw;
    R(g, mx, my + 2, fillW, 4, B.meter > 1 ? '#cd5b3b' : '#f7c232'); hl(g, mx, my + 2, fillW, '#ffe274');
    const nx = mx + clamp(B.meter, 0, 1) * mw;
    R(g, nx - 1, my - 3, 2, 14, PAL.cream);
    if (B.unit === '°C') drawTxt(g, Math.round(70 + B.meter * 30) + '°C', mx + mw + 6, my - 3, 6, PAL.cream, null, false, PAL.ink);
    if (B.label) drawTxt(g, B.label, mx, my + 10, 6, PAL.cream, null, true, PAL.ink);
  }
  if (B.phase === 'result' && B.result) {
    g.globalAlpha = .55; R(g, 0, 0, W, H, '#22131c'); g.globalAlpha = 1;
    drawDrink(g, 160, 150, B.result.vis, TIME, true);
    if (B.result.food) { const fg = mk(20, 16); drawFood(fg, 10, 14, B.result.food); g.drawImage(fg.canvas, 196, 120, 40, 32); }
    const nm = B.result.nome;
    drawTxt(g, nm, 160, 18, 10, '#fdf0cf', 'c', false, PAL.ink);
  }
}

/* animação do medidor */
function runMeter(cfg) {
  // cfg: {type:'hold'|'wait', zones:[[a,b]], speed, sound, label, dica, unit, anim, start}
  const B = VIEW.brew;
  return new Promise(res => {
    B.meterOn = true; B.zones = cfg.zones; B.meter = cfg.start || 0; B.label = cfg.label; B.unit = cfg.unit;
    let holding = false, done = false, raf;
    const speed = cfg.speed || .45;
    let last = performance.now();
    const finish = () => {
      if (done) return; done = true; cancelAnimationFrame(raf);
      if (cfg.sound) AUD.loopStop(cfg.sound);
      B.anim = null;
      const zi = cfg.zoneIndex || 0;
      const s = meterScore(B.meter, cfg.zones[zi]);
      AUD.sfx(s >= .75 ? 'good' : 'meh');
      UI.toast(scoreWord(s));
      fxBurst(160, 30, s >= .75 ? 'spark' : 'grounds', s >= .9 ? 14 : 6);
      setTimeout(() => res(s), 380);
    };
    const loop = (now) => {
      const dt = Math.min(.05, (now - last) / 1000); last = now;
      if (cfg.type === 'wait' || holding) {
        B.meter += speed * dt;
        if (cfg.onFill) cfg.onFill(B.meter);
      }
      if (B.meter >= 1.04) { B.meter = 1.05; finish(); return; }
      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);
    if (cfg.type === 'wait') { B.anim = cfg.anim || 'wait'; if (cfg.sound) AUD.loopStart(cfg.sound); }
    const c = $('#ctrl'); c.hidden = false; c.className = 'ctrl brew';
    $('#dlg').hidden = true;
    const btn = el('button', { class: 'btn big hold', id: 'holdbtn' }, cfg.type === 'hold' ? 'Segure' : 'Agora!');
    const down = (e) => { e.preventDefault(); if (done) return; if (cfg.type === 'wait') { finish(); return; } holding = true; btn.classList.add('active'); B.anim = cfg.anim || 'hold'; if (cfg.sound) AUD.loopStart(cfg.sound); };
    const up = (e) => { if (!holding || done) return; e.preventDefault(); holding = false; btn.classList.remove('active'); finish(); };
    btn.addEventListener('pointerdown', down); btn.addEventListener('pointerup', up); btn.addEventListener('pointerleave', up); btn.addEventListener('pointercancel', up);
    KEYHOLD = { down, up };
    c.replaceChildren(el('div', { class: 'brew-info' }, [el('b', { text: cfg.label }), el('span', { class: 'small', text: cfg.dica || '' })]), btn);
  }).then(s => { KEYHOLD = null; B.meterOn = false; return s; });
}
let KEYHOLD = null;

/* segura até encher (moer) – sem nota, só o gesto */
function holdFill(label, dica, sound, anim, secs) {
  const B = VIEW.brew;
  return new Promise(res => {
    B.meterOn = true; B.zones = [[.98, 1]]; B.meter = 0; B.label = label; B.unit = null;
    let holding = false, done = false, last = performance.now();
    const btn = el('button', { class: 'btn big hold' }, 'Segure');
    const loop = (now) => {
      const dt = Math.min(.05, (now - last) / 1000); last = now;
      if (holding) B.meter += dt / secs;
      if (B.meter >= 1 && !done) { done = true; AUD.loopStop(sound); B.anim = null; B.meterOn = false; KEYHOLD = null; AUD.sfx('good'); res(); return; }
      requestAnimationFrame(loop);
    };
    requestAnimationFrame(loop);
    const down = (e) => { e.preventDefault(); holding = true; btn.classList.add('active'); B.anim = anim; AUD.loopStart(sound); };
    const up = () => { holding = false; btn.classList.remove('active'); B.anim = null; AUD.loopStop(sound); };
    btn.addEventListener('pointerdown', down); btn.addEventListener('pointerup', up); btn.addEventListener('pointerleave', up); btn.addEventListener('pointercancel', up);
    KEYHOLD = { down, up };
    const c = $('#ctrl'); c.hidden = false; c.className = 'ctrl brew'; $('#dlg').hidden = true;
    c.replaceChildren(el('div', { class: 'brew-info' }, [el('b', { text: label }), el('span', { class: 'small', text: dica })]), btn);
  });
}

function pedidoTexto(v) {
  const p = v.pedido; const parts = [];
  if (p.receita) parts.push(RECEITAS[p.receita].nome);
  else if (p.sempre) {
    const st = regState(v.id);
    parts.push('O de sempre' + (S.opts.dicas && st.sempreConhecido ? ' (' + RECEITAS[sempreAtual(v.id)].nome + ')' : ''));
  } else if (p.tags) parts.push('Algo ' + p.tags.map(t => TAG_NOMES[t] || t).join(' ou '));
  if (p.comida) parts.push('+ ' + QUITANDAS[p.comida].nome);
  if (p.xicaras > 1) parts.push('(duas xícaras)');
  return parts.join(' ');
}
function showTicket(v) {
  const t = $('#ticket');
  if (!v) { t.hidden = true; return; }
  t.hidden = false;
  const rd = receitaDoDia();
  t.replaceChildren(...[el('div', { class: 'tk-h', text: 'Pedido · ' + v.name }), el('div', { class: 'tk-b', text: pedidoTexto(v) }), v.pedido.receita === rd ? el('div', { class: 'tk-x', text: 'Receita do dia: paga em dobro' }) : null].filter(Boolean));
}

async function brew(v) {
  for (;;) {
    VIEW.scene = 'brew';
    VIEW.brew = { kit: null, kitDef: null, phase: 'kit', meter: 0, anim: null, cupVis: null, temp: 0 };
    hud(false);
    const B = VIEW.brew;
    // escolha do kit
    const kitsOwned = KIT_ORDER.filter(k => S.kits[k]);
    const rapidas = Object.keys(S.receitas).filter(id => S.receitas[id].feitas >= 5 && S.receitas[id].melhor >= 2 && receitaPossivel(id));
    const opts = kitsOwned.map(k => ({ v: { kit: k }, label: KITS[k].nome + (k === 'coldbrew' ? ' (' + S.coldbrew + ')' : ''), cls: 'kitbtn', disabled: k === 'coldbrew' && S.coldbrew <= 0 }));
    if (rapidas.length) opts.push({ v: { rapido: true }, label: 'Preparo rápido', cls: 'ghost' });
    opts.push({ v: { caderno: true }, label: 'Caderninho', cls: 'ghost', icon: 'book' });
    const ch = await buttons(opts, 'kits');
    if (ch.caderno) { await openCaderno(1); continue; }
    let recipe = null, kit, adds = [], q, art = null, food = null, scores = [];
    if (ch.rapido) {
      const id = await buttons(rapidas.map(id => ({ v: id, label: RECEITAS[id].nome })).concat([{ v: null, label: 'Voltar', cls: 'ghost' }]), 'kits');
      if (!id) continue;
      recipe = id; kit = RECEITAS[id].kit; adds = RECEITAS[id].adds.slice(); q = .9; B.kit = kit;
      if (kit === 'coldbrew') S.coldbrew--;
      if (adds.indexOf('espuma') >= 0 && kit === 'espresso') art = S.latteAtivo;
    } else {
      kit = ch.kit; const K = KITS[kit]; B.kit = kit; B.kitDef = K;
      if (kit === 'coldbrew') { S.coldbrew--; scores.push(.95); UI.toast('Cold brew da jarra de ontem. Restam ' + S.coldbrew + '.'); }
      // moagem
      if (K.moagem) {
        const gr = await buttons([{ v: 'fino', label: 'Fina' }, { v: 'medio', label: 'Média' }, { v: 'grosso', label: 'Grossa' }].map(o => Object.assign(o, { cls: 'grind' })).concat([{ v: 'info', label: '?', cls: 'ghost', keep: () => UI.toast(KITS[kit].desc) }]), 'grind');
        await holdFill('Moer o café', 'Moagem ' + ({ fino: 'fina', medio: 'média', grosso: 'grossa' })[gr] + '. Segure para girar a manivela.', 'grind', 'grind', .9);
        if (K.moagem.indexOf(gr) < 0) { scores.push(.45); UI.toast(gr === 'fino' ? 'Moagem fina demais para esse método. Vai amargar.' : gr === 'grosso' ? 'Moagem grossa demais. Vai ficar aguado.' : 'Esse método pede outra moagem.'); }
        else scores.push(1);
      }
      // água
      if (K.temp) {
        const za = (K.temp[0] - 70) / 30, zb = (K.temp[1] - 70) / 30;
        scores.push(await runMeter({ type: 'hold', zones: [[za, zb]], speed: .42, sound: 'heat', label: 'Aquecer a água', dica: 'Solte entre ' + K.temp[0] + ' e ' + K.temp[1] + '°C. Água fervendo queima o café.', unit: '°C', anim: 'heat' }));
        B.temp = 1;
      }
      // extração
      for (const passo of K.passos) {
        if (passo.t === 'pulses') {
          const n = passo.n; const zs = [];
          for (let i = 0; i < n; i++) { const c = n === 2 ? [.3, .82][i] : [.25, .55, .85][i]; zs.push([c - .06, c + .06]); }
          let acc = 0;
          for (let i = 0; i < n; i++) {
            const s = await runMeter({ type: 'hold', zones: zs, zoneIndex: i, start: VIEW.brew.meter && i ? VIEW.brew.meter : 0, speed: .38, sound: 'pour', label: passo.label + ' (' + (i + 1) + '/' + n + ')', dica: i === 0 ? passo.dica : 'Agora até a próxima faixa.', anim: 'pour', onFill: m => { B.cupVis = drinkVisual(kit, [], null, null); B.cupVis.layers[B.cupVis.layers.length - 1].h = .62 * clamp(m, 0, 1); } });
            acc += s; B.meter = B.meter; // mantém
            const keep = B.meter; B._keep = keep;
          }
          scores.push(acc / n);
        } else {
          scores.push(await runMeter({ type: passo.t, zones: [passo.alvo], speed: passo.t === 'wait' ? passo.vel : .42, sound: kit === 'espresso' ? 'espresso' : passo.t === 'hold' ? (kit === 'leiteira' ? 'heat' : 'pour') : 'heat', label: passo.label, dica: passo.dica, anim: passo.t === 'hold' ? 'hold' : 'wait', onFill: m => { if (kit !== 'leiteira') { B.cupVis = drinkVisual(kit, [], null, null); B.cupVis.layers[B.cupVis.layers.length - 1].h = .62 * clamp(m, 0, 1); } } }));
        }
      }
      // ingredientes e acompanhamento
      B.cupVis = drinkVisual(kit, [], null, null);
      const ings = ING_ORDER.filter(i => ingDisponivel(i) && !(kit === 'leiteira' && (i === 'espuma' || i === 'agua' || i === 'leite')) && !(i === 'gelo' && kit !== 'coldbrew'));
      const sel = await pickAdds(ings, kit);
      adds = sel.adds; food = sel.food;
      if (adds.indexOf('espuma') >= 0) {
        B.anim = null;
        scores.push(await runMeter({ type: 'hold', zones: [INGREDIENTES.espuma.passo.alvo], speed: .4, sound: 'steam', label: INGREDIENTES.espuma.passo.label, dica: INGREDIENTES.espuma.passo.dica, anim: 'steamer' }));
        if (kit === 'espresso' && Object.keys(S.latte).length) {
          const opts2 = Object.keys(S.latte).map(a => ({ v: a, label: 'Arte: ' + LATTE_ART[a] })).concat([{ v: null, label: 'Sem arte', cls: 'ghost' }]);
          art = await buttons(opts2, 'grind');
          if (art) S.latteAtivo = art;
        }
      }
      recipe = matchRecipe(kit, adds);
      q = scores.length ? scores.reduce((a, b) => a + b, 0) / scores.length : .8;
    }
    const stars = q >= .85 ? 3 : q >= .6 ? 2 : 1;
    const nome = recipe ? RECEITAS[recipe].nome : 'Criação da casa';
    const vis = drinkVisual(kit, adds, recipe, art, q);
    B.phase = 'result'; B.result = { vis, nome, food };
    B.cupVis = null;
    AUD.sfx('serve');
    const nova = recipe && !S.receitas[recipe];
    const c = $('#ctrl'); c.hidden = false; c.className = 'ctrl result';
    const starsEl = el('span', { class: 'stars' }); for (let i = 1; i <= 3; i++) starsEl.append(ico(i <= stars ? 'star' : 'star0'));
    const r = await new Promise(res => {
      c.replaceChildren(
        el('div', { class: 'brew-info' }, [el('b', {}, [nome, ' ', starsEl]), el('span', { class: 'small', text: nova ? 'Receita nova para o caderninho!' : recipe ? (adds.length ? adds.map(a => INGREDIENTES[a].nome).join(' + ') : 'Puro') : 'Essa combinação não está em nenhuma receita. Pode servir assim mesmo.' })]),
        el('button', { class: 'btn primary big', onclick: () => res('servir') }, 'Servir'),
        el('button', { class: 'btn ghost', onclick: () => res('refazer') }, 'Refazer'));
    });
    if (r === 'refazer') { if (kit === 'coldbrew') S.coldbrew++; continue; }
    if (recipe) {
      const rec = S.receitas[recipe] || (S.receitas[recipe] = { feitas: 0, melhor: 0 });
      rec.feitas++; rec.melhor = Math.max(rec.melhor, stars);
      if (nova) { UI.toast('Receita descoberta: ' + nome, 'book'); AUD.sfx('chime'); }
    }
    VIEW.brew = null;
    return { recipe, kit, adds, food, q, stars, art, vis, nome, nova };
  }
}
function pickAdds(ings, kit) {
  return new Promise(res => {
    const sel = new Set(); let food = null;
    const c = $('#ctrl'); c.hidden = false; c.className = 'ctrl adds'; $('#dlg').hidden = true;
    const render = () => {
      const B = VIEW.brew; B.cupVis = drinkVisual(kit, [...sel], matchRecipe(kit, [...sel]), null);
      const r = matchRecipe(kit, [...sel]);
      c.replaceChildren(
        el('div', { class: 'brew-info' }, [el('b', { text: 'Ingredientes' }), el('span', { class: 'small', text: r ? 'Isso vira: ' + (S.receitas[r] ? RECEITAS[r].nome : 'uma receita que você ainda não conhece') : 'Escolha o que vai na xícara.' })]),
        el('div', { class: 'chips' }, ings.map(i => el('button', { class: 'chip' + (sel.has(i) ? ' on' : ''), 'aria-pressed': sel.has(i), onclick: () => { sel.has(i) ? sel.delete(i) : sel.add(i); AUD.sfx('click'); render(); } }, [el('i', { class: 'dot', style: 'background:' + INGREDIENTES[i].cor }), INGREDIENTES[i].nome]))),
        el('div', { class: 'chips' }, [el('span', { class: 'small muted', text: 'Acompanha: ' })].concat(Object.keys(S.quitandas).map(f => el('button', { class: 'chip food' + (food === f ? ' on' : ''), 'aria-pressed': food === f, onclick: () => { food = food === f ? null : f; AUD.sfx('click'); render(); } }, QUITANDAS[f].nome)))),
        el('button', { class: 'btn primary', onclick: () => { AUD.sfx('click'); res({ adds: [...sel], food }); } }, 'Pronto'));
    };
    render();
  });
}

/* ======================================================
   VISITAS
   ====================================================== */
const NOMES_F = ['Ana', 'Bruna', 'Carla', 'Débora', 'Fernanda', 'Juliana', 'Larissa', 'Patrícia', 'Renata', 'Sandra', 'Tânia', 'Bia', 'Lívia', 'Márcia', 'Rosa', 'Jéssica', 'Aline', 'Simone'];
const NOMES_M = ['André', 'Bruno', 'Carlos', 'Diego', 'Eduardo', 'Fábio', 'Gustavo', 'João', 'Leandro', 'Marcos', 'Paulo', 'Renato', 'Thiago', 'Vítor', 'Wagner', 'Igor', 'Caio', 'Sérgio'];
const R_SAUDA = ['Bom dia!', 'Oi, tudo bem?', 'Opa, licença.', 'Olá!', 'Bom dia, bom dia.', 'Oi! Primeira vez aqui.', 'Que cheiro bom de café.'];
const R_PEDE = ['Me vê um {r}, por favor.', 'Um {r}, por favor.', 'Queria um {r}.', 'Pode ser um {r}?', 'Tem {r}? Então um, por favor.', 'Vou de {r} hoje.'];
const R_HUMOR = ['Quero alguma coisa {t}. Você escolhe.', 'Me surpreende com algo {t}?', 'Hoje eu tô precisando de algo {t}.', 'Faz um {t} pra mim? Confio em você.'];
const R_OK = ['Obrigado!', 'Que delícia.', 'Perfeito, valeu!', 'Hmm, muito bom.', 'Isso aí!', 'Volto amanhã, hein.', 'Nossa, que capricho.'];
const R_ERR = ['Não era bem isso, mas tá bom.', 'Hm, diferente do que eu pedi.', 'Ué. Mas tudo bem, eu tomo.', 'Não foi o que eu pedi, mas não tá ruim não.'];

function randomVisit(i) {
  const r = rng(hashStr('rv' + S.dia + ':' + i + S.nome));
  const spec = randomSpec(r, { cold: dayInfo().season === 'inverno' });
  const fem = !!spec.lashes;
  const name = (fem ? NOMES_F : NOMES_M)[Math.floor(r() * 18)];
  const possiveis = Object.keys(RECEITAS).filter(id => receitaPossivel(id) && !RECEITAS[id].secreta);
  const rd = receitaDoDia();
  let id = r() < .2 ? rd : possiveis[Math.floor(r() * possiveis.length)];
  const pedido = {};
  let fala;
  if (r() < .34) {
    const tags = RECEITAS[id].tags.filter(t => t !== 'quente' && t !== 'classico' && t !== 'rapido');
    const t = tags.length ? tags[Math.floor(r() * tags.length)] : 'quente';
    pedido.tags = [t]; fala = R_HUMOR[Math.floor(r() * R_HUMOR.length)].replace('{t}', TAG_NOMES[t]);
  } else { pedido.receita = id; fala = R_PEDE[Math.floor(r() * R_PEDE.length)].replace('{r}', RECEITAS[id].nome.toLowerCase()); }
  const qs = Object.keys(S.quitandas);
  if (r() < .25) { pedido.comida = qs[Math.floor(r() * qs.length)]; fala += ' E um ' + QUITANDAS[pedido.comida].nome.toLowerCase() + '.'; }
  return { tipo: 'rand', name, spec, pedido, antes: [R_SAUDA[Math.floor(r() * R_SAUDA.length)]], fala };
}
function regVisit(id) {
  const C = REGULARES[id], st = regState(id);
  const intro = !st.intro;
  const beat = intro ? C.beats[0] : beatPronto(id);
  const v = { tipo: 'reg', id, name: C.nome, spec: specFor(id), beat, beatIndex: beat ? C.beats.indexOf(beat) : -1 };
  if (beat && beat.pedido) { v.pedido = Object.assign({}, beat.pedido); v.fala = beat.pedidoFala || SEMPRE_FALAS[0]; }
  else { v.pedido = { sempre: true }; if (C.comida) v.pedido.comida = C.comida; v.fala = SEMPRE_FALAS[(S.dia + id.length) % SEMPRE_FALAS.length]; }
  if (!v.pedido.xicaras && v.pedido.sempre) v.pedido.xicaras = st.xicaras;
  if (!beat) {
    if (st.fim) v.antes = [EPILOGOS[id][(S.dia + st.visitas) % EPILOGOS[id].length]];
    else v.antes = [C.conversa[(S.dia + st.visitas) % C.conversa.length]];
  }
  return v;
}
function buildDay() {
  const visits = [];
  const r = rng(hashStr('day' + S.dia + S.nome));
  const intros = REG_ORDER.filter(introPronto).sort((a, b) => REGULARES[a].intro.dia - REGULARES[b].intro.dia || REGULARES[a].intro.ordem - REGULARES[b].intro.ordem).slice(0, S.dia === 1 ? 3 : 2);
  const regs = [];
  const prontos = [], outros = [], epis = [];
  for (const id of REG_ORDER) {
    const st = regState(id);
    if (!st.intro || intros.indexOf(id) >= 0) continue;
    if (st.fim) { if (r() < .3) epis.push(id); continue; }
    if (beatPronto(id)) prontos.push(id);
    else if (S.dia - st.ultimaVisita >= 2 || r() < .5) outros.push(id);
  }
  const maxReg = Math.min(7, 3 + Math.floor(S.dia / 3));
  for (const id of intros.concat(prontos, outros, epis)) if (regs.length < maxReg || intros.indexOf(id) >= 0) regs.push(id);
  const total = Math.max(regs.length + 2, 5 + Math.min(4, Math.floor(S.nivel / 2)));
  const list = regs.map(regVisit);
  if (S.passanteHoje && !S.passanteHoje.visto) {
    const p = PASSANTES.find(x => x.id === S.passanteHoje.id);
    if (p) list.push({ tipo: 'pass', id: p.id, name: p.nome, spec: p.spec, pedido: Object.assign({}, p.pedido), antes: p.falas, depois: p.depois, fala: null });
  }
  let i = 0; while (list.length < total) list.push(randomVisit(i++));
  // ordem: apresentações primeiro no dia 1; senão embaralha mantendo apresentações cedo
  const introV = list.filter(v => v.tipo === 'reg' && intros.indexOf(v.id) >= 0);
  const rest = list.filter(v => introV.indexOf(v) < 0);
  for (let k = rest.length - 1; k > 0; k--) { const j = Math.floor(r() * (k + 1)); [rest[k], rest[j]] = [rest[j], rest[k]]; }
  if (S.dia === 1) return introV.concat(rest);
  const out = rest.slice();
  introV.forEach((v, n) => out.splice(Math.min(out.length, n * 2 + 1), 0, v));
  return out;
}

function avaliar(v, d) {
  const p = v.pedido; let ok = false;
  const alvo = p.receita || (p.sempre ? sempreAtual(v.id) : null);
  if (alvo) ok = d.recipe === alvo;
  else if (p.tags) ok = !!d.recipe && RECEITAS[d.recipe].tags.some(t => p.tags.indexOf(t) >= 0);
  let comidaOk = !p.comida || d.food === p.comida;
  return { ok: ok && comidaOk, bebidaOk: ok, comidaOk };
}

const DAYSTATS = { moedas: 0, gorjetas: 0, servidos: 0, tres: 0, coracoes: [], novas: [], niveis: [], passante: null };
async function runVisit(v, idx, total) {
  VIEW.t = .04 + .74 * (idx / Math.max(1, total));
  VIEW.weather = weatherFor(S.dia, dayInfo().season);
  VIEW.tables = { 1: r01(idx, 1) < .6 ? { seed: idx * 7 + S.dia, two: r01(idx, 2) < .5 } : null, 2: r01(idx, 3) < .5 ? { seed: idx * 13 + S.dia } : null };
  VIEW.scene = 'cafe'; VIEW.drink = null; VIEW.second = null; VIEW.cups = 0;
  hud(true);
  await wait(250);
  VIEW.bell = .8; AUD.sfx('bell');
  VIEW.main = { id: v.id, spec: v.spec, name: v.name, expr: 'neutro', enter: 0 };
  await wait(550);
  const beat = v.beat;
  const lines = beat ? (beat.antes || []) : (v.antes || []);
  if (lines.length) await say(lines);
  if (beat && beat.escolha && beat.escolha.quando === 'antes') await fazerEscolha(v, beat.escolha);
  if (v.fala) await say([v.fala]);
  if (v.tipo === 'reg') { const st = regState(v.id); if (v.pedido.sempre || (v.pedido.receita && v.pedido.receita === sempreAtual(v.id))) { /* nada */ } }
  // preparo
  showTicket(v);
  const d = await brew(v);
  showTicket(null);
  VIEW.scene = 'cafe'; hud(true);
  VIEW.drink = d; VIEW.cups = v.pedido.xicaras || 1;
  if (v.tipo === 'reg' && v.id === 'bene' && (v.pedido.xicaras || 1) > 1) VIEW.cups = 2;
  const av = avaliar(v, d);
  // pagamento
  const info = dayInfo();
  const base = d.recipe ? RECEITAS[d.recipe].preco : 5;
  const temCafe = d.kit !== 'leiteira';
  let preco = base * (temCafe ? 1 + GRAOS[S.graoAtivo].bonus : 1);
  if (d.recipe && d.recipe === receitaDoDia()) preco *= 2;
  if (d.food) preco += QUITANDAS[d.food].preco;
  let gorjeta = preco * (.06 * d.stars + (av.ok ? .25 : 0));
  if (info.festa === 'diadocafe' && temCafe) gorjeta *= 2;
  if (info.festa === 'criancas' && d.recipe && d.recipe.startsWith('choco')) preco = 0;
  if (v.pedido.xicaras > 1) preco += base;
  preco = Math.round(preco); gorjeta = Math.round(gorjeta);
  S.coins += preco + gorjeta; S.stats.moedas += preco + gorjeta; DAYSTATS.moedas += preco; DAYSTATS.gorjetas += gorjeta;
  S.stats.servidos++; DAYSTATS.servidos++;
  if (d.stars === 3) { S.stats.tres++; DAYSTATS.tres++; missao('tres'); }
  missao('serve');
  if (d.food) missao('comida');
  if (d.recipe) missao('variedade', 1, d.recipe);
  if (av.ok && v.pedido.sempre) missao('sempre');
  if (av.ok && v.pedido.tags) missao('humor');
  if (d.recipe && RECEITAS[d.recipe].tags.indexOf('leitoso') >= 0) missao('leitoso');
  if (d.nova) DAYSTATS.novas.push(d.nome);
  for (let k = 0; k < Math.min(8, 2 + Math.floor((preco + gorjeta) / 3)); k++) fxAdd({ x: 168 + Math.random() * 8, y: 120, vx: (Math.random() - .3) * 1.4, vy: -1.2 - Math.random(), life: 1, decay: .02, kind: 'coin' });
  AUD.sfx('coin');
  UI.toast('+' + preco + (gorjeta ? ' e ' + gorjeta + ' de gorjeta' : ''), 'coin');
  const ups = addXP(8 + 4 * d.stars + (av.ok ? 4 : 0) + (beat ? 6 : 0));
  // reação
  if (v.tipo === 'reg') {
    const C = REGULARES[v.id], st = regState(v.id);
    const antes = afinLevel(st.afin);
    st.afin += (av.ok ? 2 : 1) + (d.stars >= 2 ? 1 : 0);
    st.visitas++; st.ultimaVisita = S.dia;
    if (av.ok && (v.pedido.sempre || (v.pedido.receita && v.pedido.receita === sempreAtual(v.id)))) st.sempreConhecido = true;
    if (!beat || !av.ok) await say([pick(av.ok ? C.acerto : C.erro)]);
    if (beat) {
      if (beat.escolha && beat.escolha.quando !== 'antes' && beat.escolha.quando !== 'fim') await fazerEscolha(v, beat.escolha);
      if (beat.ler) { await say(['*Você abre o envelope e lê em voz alta.*']); await lerCarta(beat.ler); }
      if (beat.depois) await say(beat.depois);
      if (beat.escolha && beat.escolha.quando === 'fim') await fazerEscolha(v, beat.escolha);
      if (beat.escolha2) await fazerEscolha(v, beat.escolha2);
      aplicarBeat(v.id, beat, v.beatIndex);
    }
    if (afinLevel(st.afin) > antes) { DAYSTATS.coracoes.push(C.nome); AUD.sfx('heart'); fxBurst(160, 60, 'heart', 8); UI.toast('Mais perto de ' + C.nome, 'heart'); }
  } else if (v.tipo === 'pass') {
    await say([av.ok ? 'P[feliz]: ' + pick(R_OK) : 'P: ' + pick(R_ERR)].concat(v.depois));
    S.album[v.id] = dayInfo().txt; S.passanteHoje.visto = true; DAYSTATS.passante = v.name;
    UI.toast('Nova foto no álbum: ' + v.name, 'book');
  } else {
    await say([av.ok ? '[feliz]' + pick(R_OK) : pick(R_ERR)]);
  }
  if (ups.length) { for (const n of ups) { DAYSTATS.niveis.push(n); UI.toast('O café chegou ao nível ' + n + '!'); } AUD.sfx('level'); fxBurst(160, 40, 'petal', 24); }
  // despedida
  $('#dlg').hidden = true;
  if (VIEW.main) VIEW.main.leaving = .01; if (VIEW.second) VIEW.second.leaving = .01;
  AUD.sfx('door');
  await wait(600);
  VIEW.main = null; VIEW.second = null; VIEW.drink = null; VIEW.cups = 0;
  hud(true);
  save();
}
function r01(a, b) { return rng(hashStr('t' + S.dia + ':' + a + ':' + b))(); }
function pick(a) { return a[Math.floor(Math.random() * a.length)]; }
async function fazerEscolha(v, e) {
  const i = await choose(e.opcoes.map(o => o.txt), e.pergunta);
  const o = e.opcoes[i];
  await say(['> ' + o.txt].concat(o.linhas || []));
  if (v.tipo === 'reg') regState(v.id).afin += o.afin || 0;
  if (o.flag) S.flags[o.flag] = 1;
}
function aplicarBeat(id, beat, idx) {
  const st = regState(id);
  if (idx === 0) st.intro = true;
  if (st.visto.indexOf(idx) < 0) st.visto.push(idx);
  st.beat = idx + 1; st.ultimoDiaBeat = S.dia;
  if (beat.pedido && beat.pedido.receita && idx === 0) st.sempreConhecido = true;
  if (beat.sempre) { st.sempre = beat.sempre; st.sempreConhecido = true; }
  if (beat.xicarasDepois) st.xicaras = beat.xicarasDepois;
  if (beat.flag) S.flags[beat.flag] = 1;
  if (beat.gift) { S.gifts[beat.gift] = 1; UI.toast('Presente: ' + GIFT_NOMES[beat.gift][0], 'heart'); }
  if (beat.carta) agendarCarta(beat.carta);
  if (beat.specFinal) st.final = true;
  if (beat.tutorialJardim) { S.sementes += 3; UI.toast('Você ganhou 3 sementes de girassol. Plante no fim do dia.', 'semente'); }
  if (beat.fim) { st.fim = true; UI.toast('A história de ' + REGULARES[id].nome + ' chegou a um bom lugar.', 'heart'); }
}

/* ======================================================
   CENAS
   ====================================================== */
function dock(content) { const c = $('#ctrl'); c.hidden = false; c.className = 'ctrl panelmode'; $('#dlg').hidden = true; c.replaceChildren(...[].concat(content)); }

async function titulo() {
  VIEW.scene = 'facade'; VIEW.t = .1; VIEW.closed = false; hud(false);
  const has = load();
  return new Promise(res => {
    dock([el('div', { class: 'title' }, [el('h1', { text: 'Café Girassol' }), el('p', { text: 'Um café de bairro, dez fregueses e o que cada um traz na xícara.' })]),
      el('div', { class: 'btnline' }, [
        has ? el('button', { class: 'btn primary big', onclick: () => { AUD.init(); $('#ctrl').hidden = true; res('continuar'); } }, 'Continuar') : null,
        el('button', { class: 'btn' + (has ? '' : ' primary big'), onclick: () => { AUD.init(); $('#ctrl').hidden = true; res('novo'); } }, has ? 'Novo jogo' : 'Começar'),
      ]),
      el('p', { class: 'tiny muted', text: 'Funciona com toque, mouse ou teclado (espaço e Enter). Salva sozinho neste navegador.' })]);
  });
}
async function setup() {
  return new Promise(res => {
    let neto = 'neta';
    const nome = el('input', { id: 'pl-nome', class: 'inp', maxlength: 16, placeholder: 'Seu nome' });
    const cafe = el('input', { id: 'pl-cafe', class: 'inp', maxlength: 22, value: 'Café Girassol' });
    const seg = el('div', { class: 'chips' });
    const renderSeg = () => seg.replaceChildren(...['neta', 'neto', 'nete'].map(n => el('button', { class: 'chip' + (neto === n ? ' on' : ''), 'aria-pressed': neto === n, onclick: () => { neto = n; renderSeg(); } }, n.charAt(0).toUpperCase() + n.slice(1))));
    renderSeg();
    modal('Antes de abrir', [{ label: '', render(b) {
      b.append(el('label', { class: 'lbl', for: 'pl-nome', text: 'Como os fregueses vão te chamar?' }), nome,
        el('div', { class: 'lbl', text: 'Para a Vó Cida, você era…' }), seg,
        el('label', { class: 'lbl', for: 'pl-cafe', text: 'Nome do café (dá para mudar depois)' }), cafe,
        el('button', { class: 'btn primary big', onclick: () => {
          S = newState(); S.nome = nome.value.trim() || 'Lu'; S.neto = neto; S.cafeName = cafe.value.trim() || 'Café Girassol'; S.iniciado = true;
          $('#modal').hidden = true; MODAL_OPEN = false; save(); res();
        } }, 'Abrir o café'));
      setTimeout(() => nome.focus(), 50);
    } }], { noclose: true });
  });
}
async function prologo() {
  VIEW.scene = 'facade'; VIEW.t = .02; VIEW.closed = true;
  $('#dlg').hidden = false;
  await say(PROLOGO);
  VIEW.closed = false; AUD.sfx('bell'); VIEW.t = .06;
  addCarta('boasvindas');
}

async function manha() {
  VIEW.scene = 'facade'; VIEW.closed = false; VIEW.t = .05; VIEW.weather = weatherFor(S.dia, dayInfo().season);
  AUD.rain(false);
  const novo = rollRealDay(); save();
  hud(true);
  if (novo && !novo.primeiro) UI.toast('Bom dia! ' + novo.ganhos.join(' · '), 'sol');
  if (novo && novo.libera) UI.toast('O carteiro passou. Tem carta nova.', 'mail');
  for (;;) {
    const info = dayInfo();
    const rd = receitaDoDia();
    const ms = S.missoes.lista;
    const wIcon = VIEW.weather;
    const prontos = S.garden.filter(b => b && bedStage(b) >= 4).length;
    const r = await new Promise(res => dock([
      el('div', { class: 'daycard' }, [
        el('div', { class: 'dc-h' }, [ico(wIcon), el('b', { text: 'Dia ' + S.dia }), el('span', { class: 'small', text: ' · ' + info.txt + ' · ' + info.season })]),
        info.festa ? el('div', { class: 'small festa', text: FESTA_NOMES[info.festa] + ': ' + FESTA_TXT[info.festa] }) : null,
        el('div', { class: 'small' }, [el('b', { text: 'Receita do dia: ' }), RECEITAS[rd].nome + ' (paga em dobro)']),
        S.passanteHoje && !S.passanteHoje.visto ? el('div', { class: 'small' }, [el('b', { text: 'Hoje: ' }), 'alguém de passagem vai entrar no café.']) : null,
        el('div', { class: 'small' }, [el('b', { text: 'Pedidos da rua: ' })].concat(ms.map((m, i) => el('span', { class: 'mis' + (m.feito ? ' done' : '') }, (i ? ' · ' : '') + m.txt + ' (' + Math.min(m.prog, m.alvo) + '/' + m.alvo + ')')))),
      ]),
      el('div', { class: 'btnline' }, [
        el('button', { class: 'btn primary big', onclick: () => res('abrir') }, [ico('cup'), 'Abrir o café']),
        el('button', { class: 'btn' + (prontos ? ' badge' : ''), onclick: () => res('jardim') }, [ico('garden'), 'Jardim']),
        el('button', { class: 'btn', onclick: () => res('loja') }, [ico('shop'), 'Loja']),
        el('button', { class: 'btn', onclick: () => res('decorar') }, [ico('brush'), 'Decorar']),
      ])]));
    AUD.sfx('click'); $('#ctrl').hidden = true;
    if (r === 'abrir') break;
    if (r === 'jardim') await openJardim();
    if (r === 'loja') await openLoja();
    if (r === 'decorar') await openDecorar();
    hud(true);
  }
}
async function servico() {
  Object.assign(DAYSTATS, { moedas: 0, gorjetas: 0, servidos: 0, tres: 0, coracoes: [], novas: [], niveis: [], passante: null });
  S.diaEncerrado = false;
  const visits = buildDay();
  VIEW.weather = weatherFor(S.dia, dayInfo().season);
  AUD.rain(VIEW.weather === 'chuva');
  for (let i = 0; i < visits.length; i++) await runVisit(visits[i], i, visits.length);
  AUD.rain(false);
}
async function fimDoDia() {
  VIEW.t = .86; VIEW.scene = 'cafe';
  S.stats.dias++;
  for (const b of S.garden) if (b) b.bonus = (b.bonus || 0) + STAGE_MS;
  if (todosFinais() && !S.finalVisto) await finale();
  S.diaEncerrado = true; save();
  await modal('Fim do dia ' + S.dia, [{ label: '', render(b) {
    b.append(el('p', {}, [ico('cup'), ' Fregueses: ', el('b', { text: DAYSTATS.servidos }), '   ', ico('star'), ' 3 estrelas: ', el('b', { text: DAYSTATS.tres })]));
    b.append(el('p', {}, [ico('coin'), ' Vendas: ', el('b', { text: DAYSTATS.moedas }), ' · Gorjetas: ', el('b', { text: DAYSTATS.gorjetas })]));
    if (DAYSTATS.coracoes.length) b.append(el('p', {}, [ico('heart'), ' Mais perto de: ' + DAYSTATS.coracoes.join(', ')]));
    if (DAYSTATS.novas.length) b.append(el('p', {}, [ico('book'), ' Receitas novas: ' + DAYSTATS.novas.join(', ')]));
    if (DAYSTATS.passante) b.append(el('p', {}, [ico('book'), ' Foto nova no álbum: ' + DAYSTATS.passante]));
    for (const n of DAYSTATS.niveis) { const u = unlocksAt(n); b.append(el('p', { class: 'ok' }, [el('b', { text: 'Nível ' + n + '! ' }), u.length ? 'Liberou na loja: ' + u.join(', ') : 'O café está ficando conhecido.'])); }
    b.append(el('p', { class: 'small muted', text: 'Tudo salvo.' }));
  } }]);
  VIEW.scene = 'facade'; VIEW.t = .93; VIEW.closed = true;
  hud(true);
  for (;;) {
    const prontos = S.garden.filter(b => b && bedStage(b) >= 4).length;
    const r = await new Promise(res => dock([
      el('div', { class: 'daycard' }, [el('div', { class: 'dc-h' }, [el('b', { text: 'Noite do dia ' + S.dia }), el('span', { class: 'small', text: ' · o café está fechado' })]),
        S.kits.coldbrew ? el('div', { class: 'small', text: 'Cold brew na geladeira: ' + S.coldbrew + ' doses.' }) : null]),
      el('div', { class: 'btnline' }, [
        el('button', { class: 'btn primary big', onclick: () => res('dormir') }, 'Próximo dia'),
        S.kits.coldbrew ? el('button', { class: 'btn', onclick: () => res('cold') }, 'Preparar cold brew') : null,
        el('button', { class: 'btn' + (prontos ? ' badge' : ''), onclick: () => res('jardim') }, [ico('garden'), 'Jardim']),
        el('button', { class: 'btn', onclick: () => res('loja') }, [ico('shop'), 'Loja']),
        el('button', { class: 'btn', onclick: () => res('decorar') }, [ico('brush'), 'Decorar']),
      ])]));
    AUD.sfx('click'); $('#ctrl').hidden = true;
    if (r === 'dormir') break;
    if (r === 'cold') { if (S.coldbrew >= 6) UI.toast('A jarra já está cheia.'); else { S.coldbrew = 6; AUD.sfx('good'); UI.toast('Jarra de cold brew na geladeira: 6 doses para amanhã.'); save(); } }
    if (r === 'jardim') await openJardim();
    if (r === 'loja') await openLoja();
    if (r === 'decorar') await openDecorar();
    hud(true);
  }
  S.dia++; S.diaEncerrado = false; save();
}
async function finale() {
  VIEW.scene = 'cafe'; VIEW.t = .95; VIEW.finale = true;
  VIEW.tables = { 1: { seed: 3, two: true }, 2: { seed: 8, two: false } };
  VIEW.main = { id: 'cris', spec: specFor('cris'), name: 'Cris', expr: 'feliz', enter: 0 };
  hud(false);
  for (const raw of FINAL) {
    const L = parseLine(raw);
    if (L.kind === 'other' && (!VIEW.main || VIEW.main.id !== L.id)) { VIEW.main = { id: L.id, spec: specFor(L.id), name: REGULARES[L.id].nome, expr: L.expr, enter: .4 }; VIEW.second = null; }
    await say([raw]);
  }
  await lerCarta('vo');
  addCarta('vo');
  S.receitas.vocida = S.receitas.vocida || { feitas: 0, melhor: 0 };
  S.finalVisto = true; save();
  VIEW.main = null;
  await say(['*Receita da Vó Cida anotada no caderninho: café coado com rapadura e canela.*', '*O café continua aberto amanhã. E no dia seguinte. A rua tem sempre alguém chegando.*']);
  await modal('Café Girassol', [{ label: '', render(b) {
    b.append(el('div', { class: 'credits' }, [
      el('p', { text: 'Você conheceu as dez histórias. Elas continuam, cada uma no seu ritmo: os fregueses voltam, mandam cartas e às vezes pedem diferente.' }),
      el('p', { text: 'Daqui em diante, todo dia tem visitante novo, pedidos da rua, girassol para colher, grãos para descobrir e um café para deixar com a sua cara.' }),
      el('p', { class: 'small muted', text: 'Arte, música e texto gerados em código para este jogo. Feito com carinho para quem gosta de café de coador.' })]));
  } }]);
  VIEW.finale = false;
}

/* ---------- entrada ---------- */
function bindInput() {
  $('#dlg').addEventListener('click', dlgAdvance);
  $('#stage').addEventListener('click', (e) => { if (!$('#dlg').hidden && !MODAL_OPEN && e.target.closest('#hud') == null) dlgAdvance(); });
  window.addEventListener('keydown', (e) => {
    if (e.target && (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA')) return;
    if (e.key === 'Escape' && MODAL_OPEN) { const c = $('#modal .close'); if (c) c.click(); return; }
    if (MODAL_OPEN) return;
    if ((e.key === ' ' || e.key === 'Enter') && KEYHOLD) { if (!e.repeat) KEYHOLD.down(e); e.preventDefault(); return; }
    if ((e.key === ' ' || e.key === 'Enter') && !$('#dlg').hidden && DLG.resolve) { e.preventDefault(); dlgAdvance(); return; }
    if (/^[1-9]$/.test(e.key)) { const b = document.querySelectorAll('#ctrl.choices .choice')[+e.key - 1]; if (b) b.click(); }
  });
  window.addEventListener('keyup', (e) => { if ((e.key === ' ' || e.key === 'Enter') && KEYHOLD) { KEYHOLD.up(e); e.preventDefault(); } });
  window.addEventListener('resize', layout);
  document.addEventListener('pointerdown', () => AUD.init(), { once: true });
}

async function main() {
  CANVAS = $('#screen'); BUF = mk(W, H); ZOOM = mk(160, 90);
  makeIcons(); layout(); bindInput();
  requestAnimationFrame(frame);
  const modo = await titulo();
  if (modo === 'novo') { await setup(); await prologo(); }
  hud(true);
  for (;;) {
    if (S.diaEncerrado) { S.dia++; S.diaEncerrado = false; }
    await manha();
    await servico();
    await fimDoDia();
  }
}
window.addEventListener('load', () => { main().catch(e => { console.error(e); const t = document.getElementById('toasts'); if (t) t.textContent = 'Algo deu errado: ' + e.message; }); });
