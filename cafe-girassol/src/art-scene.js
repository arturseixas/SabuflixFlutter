'use strict';
/* Cenários: interior, fachada, kits, xícaras e partículas. */

/* ---------- opções de decoração (cores) ---------- */
const DECOR_COLORS = {
  wall: { amarelo: '#f2c14e', terracota: '#d8734f', verde: '#7fb7a0', azul: '#6f9fcf', rosa: '#e7a3a8', creme: '#f1e2c3', lilas: '#a993c9' },
  accent: { verde: '#2b5b40', vinho: '#7a2638', azul: '#24526b', marrom: '#59302d', mostarda: '#c4891c', branco: '#efe8dc', preto: '#2a242f' },
};

/* ---------- céu e luz por hora ---------- */
function skyAt(t, weather) {
  // t: 0 manhã cedo … 0.5 tarde … 0.8 pôr do sol … 1 noite
  const top = mixN([[0, '#7fb2e0'], [.45, '#5f9bd6'], [.72, '#6b7fc4'], [.86, '#41356b'], [1, '#141634']], t);
  const bot = mixN([[0, '#ffe2b6'], [.45, '#cfe8f4'], [.72, '#f7b07a'], [.86, '#d0607a'], [1, '#2a2552']], t);
  if (weather === 'chuva') return [mix(top, '#5a6478', .55), mix(bot, '#8a93a3', .55)];
  if (weather === 'nublado') return [mix(top, '#8e9bb0', .4), mix(bot, '#c9ccd2', .4)];
  return [top, bot];
}
function lightTint(t) {
  return mixN([[0, '#fff1d8'], [.4, '#ffffff'], [.7, '#ffe6c4'], [.84, '#f0b796'], [1, '#6e6aa0']], t);
}

/* ---------- prédios de fundo (vista da janela e da rua) ---------- */
function drawSkyline(g, x0, y0, w, h, t, seed, weather) {
  const [top, bot] = skyAt(t, weather);
  const cols = [];
  for (let i = 0; i < 6; i++) cols.push(mix(top, bot, i / 5));
  vgrad(g, x0, y0, w, h, cols);
  const night = t > .82;
  if (night) { const r = rng(seed + 9); for (let i = 0; i < w * h / 160; i++) P(g, x0 + r() * w, y0 + r() * h * .5, r() < .3 ? '#fff4b8' : '#c9c3e6'); }
  else if (weather !== 'chuva') { // nuvens
    const r = rng(seed + 3);
    for (let i = 0; i < 3; i++) { const cx = x0 + r() * w, cy = y0 + 6 + r() * h * .3; const cc = mix('#ffffff', bot, .25); ell(g, cx, cy, 10 + r() * 8, 3, cc); ell(g, cx + 5, cy - 2, 6, 3, cc); ell(g, cx - 4, cy + 1, 8, 2, mix(cc, top, .3)); }
  }
  if (t > .3 && t < .86 && weather === 'sol') { const sx = x0 + w * (.85 - t * .6), sy = y0 + h * (.15 + t * .45); ell(g, sx, sy, 5, 5, mix('#fff4b8', bot, .1)); }
  // prédios
  const r = rng(seed);
  const far = mix(top, '#6a6f9a', .5), near = mix(bot, '#7a5a6a', .55);
  let x = x0 - 4;
  while (x < x0 + w) { const bw = 10 + r() * 16, bh = h * (.3 + r() * .35); R(g, x, y0 + h - bh, bw, bh, far); x += bw + 1; }
  x = x0 - 6;
  while (x < x0 + w) {
    const bw = 14 + r() * 18, bh = h * (.18 + r() * .28), by = y0 + h - bh;
    const bc = night ? tone(near, -1) : near;
    R(g, x, by, bw, bh, bc); hl(g, x, by, bw, tone(bc, 1));
    for (let wy = by + 3; wy < y0 + h - 3; wy += 5) for (let wx = x + 2; wx < x + bw - 3; wx += 5) {
      const lit = night ? r() < .55 : false;
      R(g, wx, wy, 2, 3, lit ? '#ffd27a' : tone(bc, -1));
    }
    x += bw + 2;
  }
}

/* ---------- padrões de parede/piso ---------- */
function wallPattern(g, x0, y0, w, h, kind, base) {
  const b = base;
  R(g, x0, y0, w, h, b);
  if (kind === 'azulejo') {
    const c1 = '#f4efe6', c2 = '#3f6fa6', c3 = '#9bb9da';
    for (let y = y0; y < y0 + h; y += 12) for (let x = x0; x < x0 + w; x += 12) {
      R(g, x, y, 12, 12, c1); hl(g, x, y, 12, c3); vl(g, x, y, 12, c3);
      const cx = x + 6, cy = y + 6;
      P(g, cx, cy, c2); P(g, cx - 1, cy, c2); P(g, cx + 1, cy, c2); P(g, cx, cy - 1, c2); P(g, cx, cy + 1, c2);
      P(g, cx - 3, cy - 3, c3); P(g, cx + 3, cy - 3, c3); P(g, cx - 3, cy + 3, c3); P(g, cx + 3, cy + 3, c3);
      P(g, x + 1, y + 1, c2); P(g, x + 11, y + 1, c2); P(g, x + 1, y + 11, c2); P(g, x + 11, y + 11, c2);
      P(g, cx, cy - 4, c2); P(g, cx, cy + 4, c2); P(g, cx - 4, cy, c2); P(g, cx + 4, cy, c2);
    }
  } else if (kind === 'listras') {
    for (let x = x0; x < x0 + w; x += 10) R(g, x, y0, 4, h, tone(b, 1));
    for (let x = x0 + 6; x < x0 + w; x += 10) vl(g, x, y0, h, tone(b, -1));
  } else if (kind === 'tijolo') {
    const m = tone(b, 2);
    for (let y = y0, row = 0; y < y0 + h; y += 5, row++) {
      hl(g, x0, y, w, m);
      for (let x = x0 + (row % 2 ? 0 : 6); x < x0 + w; x += 12) vl(g, x, y, 5, m);
      for (let x = x0 + (row % 2 ? 2 : 8); x < x0 + w; x += 24) R(g, x, y + 1, 4, 1, tone(b, 1));
    }
  } else if (kind === 'floral') {
    const r = rng(77);
    for (let y = y0 + 3; y < y0 + h; y += 9) for (let x = x0 + ((y / 9 | 0) % 2) * 6; x < x0 + w; x += 12) {
      const c = r() < .5 ? '#e7a3a8' : '#f2c14e';
      P(g, x, y, c); P(g, x - 1, y, c); P(g, x + 1, y, c); P(g, x, y - 1, c); P(g, x, y + 1, c); P(g, x, y, '#fff4b8');
      P(g, x + 2, y + 2, '#4a8648'); P(g, x + 3, y + 2, '#4a8648');
    }
  } else if (kind === 'madeira') {
    for (let x = x0; x < x0 + w; x += 7) { vl(g, x, y0, h, tone(b, -1)); const r = rng(x); for (let k = 0; k < 4; k++) vl(g, x + 2 + (r() * 4 | 0), y0 + r() * h, 3, tone(b, 1)); }
  } else { // liso com rodameio
    dith(g, x0, y0, w, h, tone(b, 1), 0);
  }
}
function floorPattern(g, x0, y0, w, h, kind) {
  if (kind === 'ladrilho') {
    const a = '#b84a3a', b = '#f0e2c6', c = '#3f6f6a';
    for (let y = y0; y < y0 + h; y += 8) for (let x = x0 - ((y - y0) % 16 ? 4 : 0); x < x0 + w; x += 8) {
      R(g, x, y, 8, 8, b); R(g, x + 2, y + 2, 4, 4, a); P(g, x, y, c); P(g, x + 7, y, c); P(g, x, y + 7, c); P(g, x + 7, y + 7, c); P(g, x + 3, y + 3, c); P(g, x + 4, y + 4, c);
    }
  } else if (kind === 'xadrez') {
    for (let y = y0, j = 0; y < y0 + h; y += 6, j++) for (let x = x0, i = 0; x < x0 + w; x += 10, i++) R(g, x, y, 10, 6, (i + j) % 2 ? '#2a242f' : '#efe8dc');
  } else if (kind === 'cimento') {
    R(g, x0, y0, w, h, '#a99f9a'); dith(g, x0, y0, w, h, '#b9b0aa', 0); const r = rng(5); for (let i = 0; i < 20; i++) hl(g, x0 + r() * w, y0 + r() * h, 3 + r() * 6, '#968c88');
  } else { // taco
    const c = ['#a56540', '#8a5133', '#b97a4a'];
    for (let y = y0, j = 0; y < y0 + h; y += 4, j++) for (let x = x0 - (j % 3) * 5; x < x0 + w; x += 15) {
      R(g, x, y, 15, 4, c[(j + (x / 15 | 0)) % 3]); hl(g, x, y, 15, tone(c[0], 1)); vl(g, x, y, 4, '#59302d');
    }
  }
  // brilho do piso perto da janela
  dith(g, x0, y0, w, 1, '#000000', 1);
}

/* ---------- objetos de decoração e presentes ---------- */
function drawPlant(g, x, y, kind, sway) {
  // vaso com base em (x,y)
  R(g, x - 5, y - 8, 10, 8, '#b85a3a'); R(g, x - 6, y - 9, 12, 2, '#d8734f'); vl(g, x + 4, y - 8, 8, '#8a3a2a');
  const s = sway || 0;
  if (kind === 'samambaia') {
    for (let i = 0; i < 7; i++) { const an = -Math.PI + i * Math.PI / 6; ln(g, x, y - 9, x + Math.cos(an) * 11 + s, y - 9 + Math.sin(an) * 9 + 6, i % 2 ? '#4a8648' : '#2b5b40'); }
    ell(g, x, y - 13, 7, 4, '#4a8648'); P(g, x - 3, y - 15, '#84b752'); P(g, x + 2, y - 14, '#84b752');
  } else if (kind === 'costela') { // costela-de-adão
    for (let i = 0; i < 4; i++) { const lx = x + (i - 1.5) * 6 + s, ly = y - 18 - (i % 2) * 5; ln(g, x, y - 9, lx, ly, '#2b5b40'); ell(g, lx, ly, 4, 3, i % 2 ? '#4a8648' : '#2b5b40'); P(g, lx - 1, ly - 1, '#84b752'); P(g, lx + 1, ly, '#1d3a34'); }
  } else if (kind === 'cacto') {
    R(g, x - 2, y - 22, 5, 14, '#4a8648'); vl(g, x + 2, y - 22, 14, '#2b5b40'); R(g, x - 6, y - 17, 3, 5, '#4a8648'); R(g, x - 6, y - 14, 4, 2, '#4a8648'); R(g, x + 4, y - 19, 3, 6, '#2b5b40'); P(g, x, y - 23, '#e7a3a8'); P(g, x - 1, y - 18, '#c3da78');
  } else if (kind === 'girassol') {
    for (let i = 0; i < 3; i++) { const fx = x + (i - 1) * 5 + s, fy = y - 18 - (i === 1 ? 6 : 0); ln(g, x + (i - 1), y - 9, fx, fy, '#2b5b40'); flower(g, fx, fy, 1); }
    P(g, x - 3, y - 12, '#4a8648'); P(g, x + 3, y - 13, '#4a8648');
  } else if (kind === 'orquidea') {
    ln(g, x, y - 9, x + 3 + s, y - 24, '#2b5b40'); for (let i = 0; i < 3; i++) { const fx = x + 3 + s + i * 2, fy = y - 24 + i * 4; R(g, fx - 1, fy, 3, 2, '#c58ad0'); P(g, fx, fy - 1, '#e7c3ef'); P(g, fx, fy + 1, '#8b4b7b'); }
    ell(g, x - 2, y - 10, 5, 1.5, '#2b5b40');
  } else { // lavanda
    for (let i = -2; i <= 2; i++) { vl(g, x + i * 2, y - 18 + Math.abs(i), 9 - Math.abs(i), '#4a8648'); R(g, x + i * 2, y - 21 + Math.abs(i), 1, 4, '#8b6fc0'); }
  }
}
function flower(g, x, y, big) {
  const p = PAL.sun[2], p2 = PAL.sun[1];
  if (big) {
    for (let a = 0; a < 8; a++) { const an = a * Math.PI / 4; P(g, x + Math.round(Math.cos(an) * 3), y + Math.round(Math.sin(an) * 3), a % 2 ? p2 : p); P(g, x + Math.round(Math.cos(an) * 2), y + Math.round(Math.sin(an) * 2), p); }
    R(g, x - 1, y - 1, 3, 3, '#5e3120'); P(g, x - 1, y - 1, '#8a5231');
  } else { P(g, x, y, '#5e3120'); P(g, x - 1, y, p); P(g, x + 1, y, p); P(g, x, y - 1, p); P(g, x, y + 1, p2); }
}
function drawSunflowerStage(g, x, y, stage, sway) {
  // planta de girassol no canteiro: estágios 0 semente … 4 florido
  const s = sway || 0;
  if (stage <= 0) { P(g, x, y - 1, '#5e3120'); P(g, x + 1, y - 1, '#3b1d17'); return; }
  if (stage === 1) { vl(g, x, y - 4, 4, '#4a8648'); P(g, x - 1, y - 4, '#84b752'); P(g, x + 1, y - 5, '#84b752'); return; }
  const hgt = stage === 2 ? 10 : stage === 3 ? 18 : 24;
  ln(g, x, y, x + s, y - hgt, '#2b5b40'); vl(g, x + 1, y - hgt + 4, hgt - 5, '#4a8648');
  ell(g, x - 3, y - hgt * .5, 3, 1.5, '#4a8648'); ell(g, x + 4, y - hgt * .65, 3, 1.5, '#2b5b40');
  if (stage === 3) { ell(g, x + s, y - hgt - 1, 2.5, 2.5, '#84b752'); P(g, x + s, y - hgt - 3, PAL.sun[2]); }
  if (stage >= 4) {
    const fx = x + s, fy = y - hgt - 3;
    for (let a = 0; a < 12; a++) { const an = a * Math.PI / 6; ell(g, fx + Math.cos(an) * 4.2, fy + Math.sin(an) * 4.2, 1.6, 1.6, a % 2 ? PAL.sun[2] : PAL.sun[3]); }
    ell(g, fx, fy, 3, 3, '#5e3120'); P(g, fx - 1, fy - 1, '#8a5231'); dith(g, fx - 2, fy - 2, 5, 5, '#3b1d17', 0);
  }
}

const GIFT_DRAW = {
  relogio(g, x, y, t) { // relógio de parede do Seu Bené
    R(g, x - 7, y - 2, 14, 24, '#59302d'); R(g, x - 6, y - 1, 12, 22, '#7c4635'); ell(g, x, y + 5, 5, 5, '#fdf0cf'); P(g, x, y + 5, PAL.ink);
    const a = (t || 0) * Math.PI * 2; ln(g, x, y + 5, x + Math.round(Math.cos(a) * 3), y + 5 + Math.round(Math.sin(a) * 3), PAL.ink); vl(g, x, y + 2, 3, PAL.ink);
    R(g, x - 3, y + 12, 6, 8, '#3a1f26'); const sw = Math.round(Math.sin((t || 0) * 60) * 2); vl(g, x + sw, y + 12, 5, PAL.gold); ell(g, x + sw, y + 18, 1.5, 1.5, PAL.gold);
    poly(g, [[x - 8, y - 2], [x, y - 7], [x + 8, y - 2]], '#59302d');
  },
  poema(g, x, y) { R(g, x - 9, y, 18, 22, '#c98b52'); R(g, x - 7, y + 2, 14, 18, PAL.paper); for (let i = 0; i < 6; i++) hl(g, x - 5, y + 5 + i * 2.4, 6 + (i * 5) % 5, '#766d78'); P(g, x + 4, y + 17, '#a2352f'); },
  desenho(g, x, y) { R(g, x - 10, y, 20, 16, PAL.ink2); R(g, x - 9, y + 1, 18, 14, PAL.paper); R(g, x - 8, y + 2, 8, 6, '#a7d2ee'); R(g, x + 1, y + 2, 7, 6, '#f7c232'); R(g, x - 8, y + 9, 16, 5, '#ea8b58'); ell(g, x - 4, y + 5, 2, 2, PAL.ink); P(g, x + 4, y + 4, PAL.ink); P(g, x + 5, y + 4, PAL.ink); hl(g, x - 6, y + 11, 6, PAL.ink); },
  cartao(g, x, y) { R(g, x - 8, y, 16, 11, '#6ba3d7'); R(g, x - 8, y + 6, 16, 5, '#f3dcab'); ell(g, x + 4, y + 3, 2, 2, '#ffe274'); hl(g, x - 7, y + 6, 14, '#e2f2fa'); R(g, x - 1, y - 1, 2, 2, '#cd5b3b'); },
  fotovo(g, x, y) { R(g, x - 8, y, 16, 20, PAL.gold); R(g, x - 7, y + 1, 14, 18, '#a56540'); R(g, x - 6, y + 2, 12, 16, '#e3c59a'); ell(g, x, y + 8, 3, 3.5, '#8a5231'); ell(g, x, y + 6, 4, 3, '#dad3cc'); R(g, x - 4, y + 12, 8, 6, '#7a2638'); P(g, x - 1, y + 8, PAL.ink); P(g, x + 1, y + 8, PAL.ink); flower(g, x + 4, y + 14, 0); },
  fotos(g, x, y) { // varal de polaroids da Dani
    for (let i = 0; i < 46; i++) P(g, x - 23 + i, y + Math.round(Math.sin(i / 46 * Math.PI) * 3), '#7c4635');
    const c = ['#6ba3d7', '#e7a3a8', '#84b752', '#f7c232', '#cd5b3b'];
    for (let i = 0; i < 5; i++) { const px = x - 20 + i * 10, py = y + Math.round(Math.sin((i * 10 + 3) / 46 * Math.PI) * 3) + 1; R(g, px - 3, py, 7, 8, PAL.paper); R(g, px - 2, py + 1, 5, 4, c[i]); P(g, px, py - 1, '#a2352f'); }
  },
  radio(g, x, y) { R(g, x - 9, y - 12, 18, 12, '#7c4635'); poly(g, [[x - 9, y - 9], [x, y - 15], [x + 9, y - 9]], '#7c4635'); R(g, x - 7, y - 9, 8, 7, '#c98b52'); for (let i = 0; i < 3; i++) hl(g, x - 7, y - 8 + i * 2, 8, '#59302d'); ell(g, x + 5, y - 6, 2, 2, '#e3b271'); P(g, x + 5, y - 6, PAL.ink); hl(g, x - 9, y - 1, 18, '#3a1f26'); },
  violao(g, x, y) { ell(g, x, y + 16, 6, 6, '#c98b52'); ell(g, x, y + 8, 4.5, 4.5, '#c98b52'); ell(g, x, y + 13, 2, 2, '#3a1f26'); R(g, x - 1, y - 8, 3, 14, '#59302d'); R(g, x - 2, y - 11, 5, 4, '#3a1f26'); vl(g, x + 4, y + 10, 10, '#a56540'); hl(g, x - 2, y + 18, 5, '#3a1f26'); },
  vaso(g, x, y, t) { R(g, x - 3, y - 9, 7, 9, '#6cc0b1'); vl(g, x + 3, y - 9, 9, '#398290'); hl(g, x - 3, y - 9, 7, '#c2ead6'); for (let i = 0; i < 3; i++) { const fx = x + (i - 1) * 5, fy = y - 17 - (i === 1 ? 4 : 0); ln(g, x, y - 9, fx, fy, '#2b5b40'); flower(g, fx, fy, 1); } },
  orquidea(g, x, y) { drawPlant(g, x, y, 'orquidea', 0); },
  cortina(g, x, y, w, h) { for (let side = 0; side < 2; side++) { const x0 = side ? x + w - 12 : x; for (let i = 0; i < 12; i++) { const c = i % 3 === 0 ? '#e9dcc0' : '#fdf0cf'; vl(g, x0 + i, y, h - (side ? (11 - i) : i) * .5, c); } for (let k = 0; k < 3; k++) flower(g, x0 + 4 + (k % 2) * 4, y + 8 + k * 12, 0); } R(g, x - 2, y - 2, w + 4, 2, '#7c4635'); },
};

/* ---------- interior ---------- */
function drawInterior(g, S, t, time) {
  const D = S.decor.interior, F = S.decor.facade;
  const wallKinds = { azulejo: '#f4efe6', listras: '#e7c58f', tijolo: '#b85a3a', floral: '#f1e2c3', madeira: '#a56540', verde: '#7fb7a0', rosa: '#e7a3a8' };
  const wk = D.wall || 'listras';
  wallPattern(g, 0, 0, W, 116, wk === 'verde' || wk === 'rosa' ? 'liso' : wk, wallKinds[wk] || '#e7c58f');
  // rodameio
  R(g, 0, 84, W, 32, D.wall === 'madeira' ? '#7c4635' : tone(wallKinds[wk] || '#e7c58f', -1));
  hl(g, 0, 84, W, tone(wallKinds[wk] || '#e7c58f', -2)); hl(g, 0, 85, W, tone(wallKinds[wk] || '#e7c58f', 1));
  for (let x = 4; x < W; x += 16) R(g, x, 88, 12, 24, tone(wallKinds[wk] || '#e7c58f', D.wall === 'madeira' ? -2 : -1)), R(g, x, 88, 12, 1, tone(wallKinds[wk] || '#e7c58f', -2));
  // teto e moldura
  R(g, 0, 0, W, 6, '#59302d'); hl(g, 0, 6, W, '#3a1f26'); hl(g, 0, 5, W, '#7c4635');
  // janela grande (rua)
  const wx = 10, wy = 18, ww = 104, wh = 72;
  drawSkyline(g, wx, wy, ww, wh - 18, t, 11, S.weather);
  // calçada/rua vistas pela janela
  R(g, wx, wy + wh - 18, ww, 18, '#8d94a8'); for (let x = wx; x < wx + ww; x += 4) P(g, x + ((x / 4) % 2), wy + wh - 14, '#c3cad6');
  hl(g, wx, wy + wh - 18, ww, '#c3cad6');
  // praça: violonista (Rafa) na praça quando aparece
  if (S.flags && S.flags.rafaPlaza && t < .9) { const bx = wx + 70, by = wy + wh - 13; drawMini(g, bx, by, 902, false, Math.floor(time * 2) % 2); R(g, bx + 3, by - 12, 5, 4, '#c98b52'); }
  // passantes
  const pass = Math.floor(time / 9);
  const px = wx + ((time * 9) % (ww + 30)) - 15;
  if (t < .92) drawMini(g, px, wy + wh - 6, 300 + pass, false, Math.floor(time * 4) % 2);
  // chuva
  if (S.weather === 'chuva') { const r = rng(Math.floor(time * 12)); for (let i = 0; i < 40; i++) { const rx = wx + r() * ww, ry = wy + r() * wh; vl(g, rx, ry, 3, '#c9d6ea'); } }
  // reflexo no vidro
  ln(g, wx + 8, wy + 44, wx + 34, wy + 4, 'rgba(255,255,255,0.25)'); ln(g, wx + 14, wy + 46, wx + 40, wy + 6, 'rgba(255,255,255,0.18)');
  // caixilho
  const fc = DECOR_COLORS.accent[F.trim] || '#2b5b40';
  R(g, wx - 4, wy - 4, ww + 8, 4, fc); R(g, wx - 4, wy + wh, ww + 8, 5, tone(fc, -1)); R(g, wx - 4, wy, 4, wh, fc); R(g, wx + ww, wy, 4, wh, tone(fc, -1));
  R(g, wx + ww / 2 - 1, wy, 3, wh, fc); R(g, wx, wy + 26, ww, 2, fc);
  hl(g, wx - 4, wy - 4, ww + 8, tone(fc, 1)); hl(g, wx - 6, wy + wh + 4, ww + 12, tone(fc, -2));
  // nome do café ao contrário no vidro (visto de dentro)
  const nm = (S.cafeName || 'Café Girassol').toUpperCase();
  const tc = txt(nm, 6, '#f7c232', true);
  g.save(); g.translate(wx + ww / 2 + Math.min(ww - 10, tc.width) / 2, wy + 28); g.scale(-1, 1); g.globalAlpha = .65; g.drawImage(tc, 0, 0, Math.min(ww - 10, tc.width), tc.height); g.restore();
  if (S.gifts.cortina && D.gifts.cortina !== false) GIFT_DRAW.cortina(g, wx - 2, wy - 2, ww + 4, wh + 2);
  // parapeito com plantas e presentes
  R(g, wx - 6, wy + wh + 4, ww + 12, 3, '#c98b52'); hl(g, wx - 6, wy + wh + 4, ww + 12, '#e3b271');
  const sway = Math.round(Math.sin(time * 1.3));
  if (D.plants !== 'nenhuma') drawPlant(g, wx + 8, wy + wh + 4, D.plants || 'samambaia', sway);
  if (S.gifts.vaso && D.gifts.vaso !== false) GIFT_DRAW.vaso(g, wx + ww - 10, wy + wh + 4, t);
  if (S.gifts.orquidea && D.gifts.orquidea !== false) GIFT_DRAW.orquidea(g, wx + ww / 2 + 14, wy + wh + 4);
  if (S.gifts.radio && D.gifts.radio !== false) GIFT_DRAW.radio(g, wx + ww / 2 - 16, wy + wh + 4);
  // quadro/cardápio no centro
  const bx = 122, by = 12;
  R(g, bx, by, 78, 50, '#7c4635'); R(g, bx + 2, by + 2, 74, 46, '#2f3b37'); dith(g, bx + 2, by + 2, 74, 46, '#36443f', 0);
  drawTxt(g, 'Cardápio', bx + 39, by + 1, 6, '#fdf0cf', 'c', true);
  const menu = S._menuPreview || [];
  for (let i = 0; i < Math.min(4, menu.length); i++) {
    const m = menu[i], col = i === 0 ? '#f7c232' : '#d9e3d6';
    drawTxt(g, m[0], bx + 5, by + 11 + i * 9, 6, col);
    drawTxt(g, m[1], bx + 73, by + 11 + i * 9, 6, col, 'r');
  }
  flower(g, bx + 71, by + 5, 1);
  // presentes na parede
  const showG = k => S.gifts[k] && D.gifts[k] !== false;
  if (showG('fotos')) GIFT_DRAW.fotos(g, wx + ww / 2, wy + 3);
  if (!showG('relogio') && !showG('poema') && D.art !== 'nenhum') { // quadro
    R(g, 204, 22, 20, 26, PAL.gold); R(g, 205, 23, 18, 24, '#24526b'); ell(g, 214, 33, 6, 6, '#f7c232'); ell(g, 214, 33, 2, 2, '#5e3120'); vl(g, 214, 39, 7, '#4a8648');
  }
  if (S.gifts.fotovo) GIFT_DRAW.fotovo(g, 124, 66);
  if (showG('relogio')) GIFT_DRAW.relogio(g, 212, 20, time / 60);
  if (showG('poema')) GIFT_DRAW.poema(g, 230, 18);
  if (showG('cartao')) GIFT_DRAW.cartao(g, 212, 50);
  if (showG('desenho')) GIFT_DRAW.desenho(g, 230, 50);
  // porta
  const dx = 244, dy = 26, dw = 40, dh = 90;
  R(g, dx - 3, dy - 3, dw + 6, dh + 3, tone(fc, -1)); R(g, dx, dy, dw, dh, DECOR_COLORS.accent[F.door] || '#7a2638');
  const doorC = DECOR_COLORS.accent[F.door] || '#7a2638';
  R(g, dx + 5, dy + 6, dw - 10, 40, '#000'); drawSkyline(g, dx + 5, dy + 6, dw - 10, 40, t, 23, S.weather);
  R(g, dx + 5, dy + 40, dw - 10, 6, '#8d94a8');
  hl(g, dx + 5, dy + 6, dw - 10, tone(doorC, -2)); R(g, dx + 6, dy + 54, dw - 12, 30, tone(doorC, -1)); R(g, dx + 7, dy + 55, dw - 14, 28, doorC); hl(g, dx + 7, dy + 55, dw - 14, tone(doorC, 1));
  R(g, dx + dw - 8, dy + 48, 3, 4, PAL.gold);
  // sininho
  const ring = S._bell > 0 ? Math.round(Math.sin(time * 40) * 2) : 0;
  vl(g, dx + dw / 2, dy - 6, 4, PAL.ink2); poly(g, [[dx + dw / 2 - 3 + ring, dy + 2], [dx + dw / 2 + ring, dy - 3], [dx + dw / 2 + 3 + ring, dy + 2]], PAL.gold); P(g, dx + dw / 2 + ring, dy + 2, '#a35f12');
  const openSign = 'ABERTO';
  R(g, dx + 7, dy + 14, 26, 9, PAL.paper); drawTxt(g, openSign, dx + 20, dy + 13, 6, '#a2352f', 'c');
  // planta à direita da porta
  drawPlant(g, 300, 112, D.plants2 || 'costela', sway);
  if (S.gifts.violao && D.gifts.violao !== false) GIFT_DRAW.violao(g, 302, 44);
  // luminárias pendentes
  drawLamps(g, D.lamps, time, t);
  // piso
  floorPattern(g, 0, 116, W, 22, D.floor || 'taco');
  hl(g, 0, 116, W, '#3a1f26');
  // mesas de fundo com clientes
  drawTable(g, 36, 124, D.tables, S, 1, time);
  drawTable(g, 222, 126, D.tables, S, 2, time);
  // gato
  if (S.flags && S.flags.gato) S._gatoInterior = true;
}
function drawLamps(g, kind, time, t) {
  const xs = [34, 96, 230];
  const on = t > .6;
  if (kind === 'pisca') {
    for (let i = 0; i < W; i++) { const y = 10 + Math.round(Math.sin(i / W * Math.PI * 4) * 3 + 3); P(g, i, y, '#3a2130'); if (i % 8 === 0) { const c = ['#f7c232', '#cd5b3b', '#6cc0b1', '#e7a3a8'][(i / 8 + Math.floor(time * 2)) % 4]; R(g, i, y + 1, 2, 2, c); } }
    return;
  }
  for (const x of xs) {
    vl(g, x, 6, kind === 'lustre' ? 6 : 12, PAL.ink2);
    if (kind === 'lustre') {
      R(g, x - 8, 12, 16, 2, PAL.gold); for (let k = -2; k <= 2; k++) { vl(g, x + k * 4, 14, 3, PAL.gold); ell(g, x + k * 4, 18, 1.5, 2, on ? '#fff4b8' : '#f7e3a0'); }
    } else {
      poly(g, [[x - 6, 24], [x - 2, 17], [x + 2, 17], [x + 6, 24]], '#2b5b40'); hl(g, x - 6, 24, 12, '#1d3a34'); hl(g, x - 2, 17, 4, '#4a8648');
      ell(g, x, 25, 2, 1.2, on ? '#fff4b8' : '#f3dcab');
    }
  }
}
function drawTable(g, x, y, kind, S, slot, time) {
  const iron = kind === 'ferro';
  const top = iron ? '#efe8dc' : '#a56540';
  // cadeiras
  for (const sx of [-15, 15]) { R(g, x + sx - 3, y - 14, 6, 14, iron ? '#2a242f' : '#7c4635'); R(g, x + sx - 4, y - 3, 8, 2, iron ? '#4a4250' : '#59302d'); vl(g, x + sx - 3, y - 1, 4, '#3a1f26'); vl(g, x + sx + 2, y - 1, 4, '#3a1f26'); }
  const occ = S._tables && S._tables[slot];
  if (occ) { drawMini(g, x - 13, y - 2, occ.seed, true, Math.floor(time / 2 + slot) % 2); if (occ.two) drawMini(g, x + 13, y - 2, occ.seed + 7, true, Math.floor(time / 2.3) % 2); }
  ell(g, x, y - 6, 12, 3, top); hl(g, x - 10, y - 4, 20, tone(top, -1)); ell(g, x - 2, y - 7, 6, 1, tone(top, 1));
  vl(g, x, y - 4, 6, iron ? '#2a242f' : '#59302d'); hl(g, x - 4, y + 2, 9, iron ? '#2a242f' : '#59302d');
  if (S.gifts.toalha) { ell(g, x, y - 6, 9, 2, '#fdf0cf'); for (let i = -8; i <= 8; i += 2) P(g, x + i, y - 4, '#fdf0cf'); }
  if (occ) { R(g, x - 4, y - 9, 3, 3, PAL.paper); R(g, x + 2, y - 9, 3, 3, PAL.paper); P(g, x - 3, y - 9, PAL.coffee[2]); }
}
function drawCat(g, x, y, time) {
  const c = '#e39b4a', d = '#b8652f', br = Math.round(Math.sin(time * 1.5) + 1) / 2;
  ell(g, x, y - 4 - br, 9, 4 + br, c); ell(g, x + 7, y - 6, 4, 3.5, c); P(g, x + 5, y - 10, c); P(g, x + 9, y - 10, c); P(g, x + 5, y - 9, d); P(g, x + 9, y - 9, d);
  hl(g, x + 6, y - 6, 2, PAL.ink); hl(g, x + 9, y - 6, 1, PAL.ink); for (let i = -6; i < 4; i += 3) vl(g, x + i, y - 7, 3, d);
  ln(g, x - 9, y - 3, x - 13, y - 2, c); ln(g, x - 13, y - 2, x - 12, y - 5, c);
  if (Math.floor(time / 2) % 3 === 0) drawTxt(g, 'z', x + 12, y - 16 - (time % 2) * 2, 6, '#fdf0cf');
}

/* ---------- balcão (primeiro plano) ---------- */
function drawCounter(g, S, kitId, time) {
  const D = S.decor.interior;
  const kinds = { madeira: ['#c98b52', '#a56540', '#7c4635'], escura: ['#7c4635', '#59302d', '#3a1f26'], azulejo: ['#efe8dc', '#3f6fa6', '#24526b'], marmore: ['#f2ede6', '#dad3cc', '#a9a0a3'] };
  const k = kinds[D.counter] || kinds.madeira;
  R(g, 0, 138, W, 42, k[2]);
  R(g, 0, 132, W, 8, k[0]); hl(g, 0, 132, W, tone(k[0], 1)); hl(g, 0, 139, W, tone(k[2], -1));
  if (D.counter === 'marmore') { const r = rng(3); for (let i = 0; i < 18; i++) ln(g, r() * W, 133, r() * W, 138, '#c9c0bd'); }
  if (D.counter === 'azulejo') { for (let x = 0; x < W; x += 10) for (let y = 141; y < 180; y += 10) { R(g, x, y, 10, 10, '#efe8dc'); R(g, x + 3, y + 3, 4, 4, '#3f6fa6'); hl(g, x, y, 10, '#9bb9da'); vl(g, x, y, 10, '#9bb9da'); } }
  else { for (let x = 0; x < W; x += 24) { vl(g, x, 141, 39, tone(k[2], -1)); vl(g, x + 1, 141, 39, tone(k[2], 1)); } }
  // máquina/kit à esquerda, caixa e vitrine à direita
  drawKitIcon(g, 26, 132, kitId, 1, time);
  // vitrine de quitandas
  const vx = 244, vy = 108;
  R(g, vx, vy, 60, 24, 'rgba(210,235,240,0.35)'); R(g, vx, vy, 60, 1, '#eef2f5'); vl(g, vx, vy, 24, '#c3cad6'); vl(g, vx + 59, vy, 24, '#8d94a8');
  hl(g, vx + 2, vy + 14, 56, '#c3cad6');
  drawFood(g, vx + 10, vy + 13, 'paodequeijo'); drawFood(g, vx + 26, vy + 13, 'bolo'); drawFood(g, vx + 44, vy + 13, 'broa');
  drawFood(g, vx + 12, vy + 23, 'biscoito'); drawFood(g, vx + 30, vy + 23, 'paodequeijo'); drawFood(g, vx + 46, vy + 23, 'bolo');
  ln(g, vx + 4, vy + 3, vx + 12, vy + 11, 'rgba(255,255,255,0.4)');
  if (S.flags && S.flags.gato) drawCat(g, vx + 40, vy, time);
  // cofrinho/caixa
  R(g, 206, 118, 26, 14, '#555a70'); R(g, 208, 114, 22, 6, '#8d94a8'); R(g, 210, 115, 18, 3, '#2f3142'); drawTxt(g, String(S.coins % 1000).padStart(3, '0'), 219, 111, 6, '#6cc0b1', 'c');
  hl(g, 206, 118, 26, '#c3cad6'); R(g, 210, 122, 4, 2, '#cd5b3b'); R(g, 216, 122, 4, 2, '#f7c232'); R(g, 222, 122, 4, 2, '#6cc0b1');
  // pote de açúcar e xícaras empilhadas
  R(g, 80, 124, 10, 8, '#efe8dc'); ell(g, 85, 124, 5, 1.5, '#dad3cc'); P(g, 85, 122, '#a9a0a3');
  for (let i = 0; i < 3; i++) { R(g, 96, 128 - i * 4, 9, 4, '#fdf0cf'); hl(g, 96, 128 - i * 4, 9, '#ffffff'); vl(g, 104, 128 - i * 4, 4, '#dad3cc'); }
}
function drawFood(g, x, y, kind) {
  if (kind === 'paodequeijo') { for (const [dx, dy] of [[-3, 0], [3, 0], [0, -3]]) { ell(g, x + dx, y + dy - 2, 3, 2.5, '#e9b96a'); P(g, x + dx - 1, y + dy - 3, '#fbe3a6'); P(g, x + dx + 1, y + dy - 1, '#c08038'); } }
  else if (kind === 'bolo') { R(g, x - 6, y - 6, 12, 6, '#f2c14e'); hl(g, x - 6, y - 6, 12, '#ffe274'); vl(g, x + 5, y - 6, 6, '#dc941b'); dith(g, x - 5, y - 5, 10, 4, '#e3a43a', 2); }
  else if (kind === 'broa') { ell(g, x, y - 3, 5, 3, '#d9a64a'); dith(g, x - 4, y - 5, 8, 4, '#b9822d', 1); P(g, x - 2, y - 5, '#f4d79a'); }
  else if (kind === 'biscoito') { for (let i = -1; i <= 1; i++) { R(g, x + i * 5 - 2, y - 3, 4, 3, '#f6ead2'); P(g, x + i * 5 - 2, y - 3, '#ffffff'); } }
}

/* ---------- kits de café ---------- */
const KIT_ICON = {
  coador(g, x, y, s) { // suporte de madeira + coador de pano + bule
    R(g, x - 9, y - 2, 18, 2, '#7c4635'); vl(g, x - 8, y - 24, 22, '#7c4635'); vl(g, x + 7, y - 24, 22, '#59302d'); hl(g, x - 8, y - 24, 16, '#a56540');
    poly(g, [[x - 6, y - 23], [x + 6, y - 23], [x + 1, y - 14], [x - 1, y - 14]], '#fdf0cf'); hl(g, x - 6, y - 23, 12, '#f3dcab'); ell(g, x, y - 23, 6, 1, '#3b1d17');
    R(g, x - 5, y - 10, 10, 8, '#efe8dc'); hl(g, x - 5, y - 10, 10, '#ffffff'); vl(g, x + 4, y - 10, 8, '#dad3cc'); R(g, x + 5, y - 8, 2, 4, '#dad3cc'); poly(g, [[x - 5, y - 9], [x - 8, y - 11], [x - 5, y - 7]], '#efe8dc');
  },
  moka(g, x, y) { poly(g, [[x - 5, y - 1], [x + 5, y - 1], [x + 4, y - 10], [x - 4, y - 10]], '#c3cad6'); R(g, x - 5, y - 12, 10, 2, '#555a70'); poly(g, [[x - 4, y - 12], [x + 4, y - 12], [x + 5, y - 21], [x - 5, y - 21]], '#c3cad6'); vl(g, x + 3, y - 20, 18, '#8d94a8'); poly(g, [[x - 5, y - 21], [x + 5, y - 21], [x, y - 24]], '#8d94a8'); R(g, x + 5, y - 18, 3, 6, PAL.ink2); poly(g, [[x - 5, y - 20], [x - 8, y - 21], [x - 5, y - 18]], '#c3cad6'); vl(g, x - 3, y - 20, 18, '#eef2f5'); },
  prensa(g, x, y) { R(g, x - 5, y - 18, 10, 17, 'rgba(200,225,235,0.55)'); R(g, x - 5, y - 10, 10, 9, '#5e3120'); hl(g, x - 5, y - 10, 10, '#8a5231'); vl(g, x - 5, y - 18, 17, '#c3cad6'); vl(g, x + 4, y - 18, 17, '#8d94a8'); R(g, x - 6, y - 20, 12, 2, '#555a70'); vl(g, x, y - 25, 5, '#8d94a8'); ell(g, x, y - 25, 1.5, 1, '#2f3142'); R(g, x + 5, y - 16, 3, 10, PAL.ink2); hl(g, x - 6, y - 1, 12, '#555a70'); },
  espresso(g, x, y) { R(g, x - 13, y - 26, 26, 25, '#c3cad6'); R(g, x - 13, y - 26, 26, 3, '#eef2f5'); vl(g, x + 12, y - 26, 25, '#8d94a8'); R(g, x - 10, y - 21, 20, 5, '#2f3142'); P(g, x - 7, y - 19, '#ea8b58'); P(g, x - 4, y - 19, '#6cc0b1'); ell(g, x + 5, y - 19, 2, 2, '#eef2f5'); R(g, x - 6, y - 14, 12, 3, '#555a70'); R(g, x - 9, y - 13, 4, 2, PAL.ink2); vl(g, x - 2, y - 11, 3, '#555a70'); vl(g, x + 1, y - 11, 3, '#555a70'); R(g, x - 3, y - 6, 6, 5, '#fdf0cf'); R(g, x - 13, y - 2, 26, 2, '#555a70'); vl(g, x + 10, y - 14, 8, '#8d94a8'); },
  v60(g, x, y) { R(g, x - 5, y - 9, 10, 8, 'rgba(200,225,235,0.6)'); R(g, x - 5, y - 6, 10, 5, '#5e3120'); poly(g, [[x - 7, y - 18], [x + 7, y - 18], [x + 2, y - 10], [x - 2, y - 10]], '#efe8dc'); for (let i = 0; i < 3; i++) ln(g, x - 4 + i * 3, y - 17, x - 1 + i, y - 11, '#c9c0bd'); hl(g, x - 7, y - 18, 14, '#ffffff'); R(g, x - 6, y - 10, 12, 1, '#dad3cc'); },
  coldbrew(g, x, y) { R(g, x - 6, y - 20, 12, 19, 'rgba(200,225,235,0.55)'); R(g, x - 6, y - 15, 12, 14, '#3b1d17'); for (let i = 0; i < 3; i++) R(g, x - 4 + i * 3, y - 13 + (i % 2) * 4, 3, 3, '#c2ead6'); R(g, x - 6, y - 22, 12, 3, '#cd5b3b'); vl(g, x - 6, y - 20, 19, '#eef2f5'); R(g, x + 6, y - 16, 3, 9, 'rgba(200,225,235,0.7)'); },
  aeropress(g, x, y) { R(g, x - 4, y - 8, 8, 7, 'rgba(200,225,235,0.6)'); R(g, x - 4, y - 5, 8, 4, '#8a5231'); R(g, x - 5, y - 10, 10, 2, '#2f3142'); R(g, x - 4, y - 22, 8, 12, '#555a70'); R(g, x - 3, y - 22, 6, 12, 'rgba(160,170,190,0.9)'); R(g, x - 3, y - 15, 6, 5, '#5e3120'); R(g, x - 3, y - 27, 6, 6, '#2f3142'); R(g, x - 5, y - 28, 10, 2, '#2f3142'); },
  chemex(g, x, y) { poly(g, [[x - 8, y - 1], [x + 8, y - 1], [x + 3, y - 11], [x + 8, y - 22], [x - 8, y - 22], [x - 3, y - 11]], 'rgba(200,225,235,0.55)'); poly(g, [[x - 7, y - 1], [x + 7, y - 1], [x + 3, y - 7], [x - 3, y - 7]], '#5e3120'); R(g, x - 4, y - 13, 8, 4, '#a56540'); P(g, x, y - 11, '#3a1f26'); poly(g, [[x - 8, y - 22], [x + 8, y - 22], [x + 3, y - 14], [x - 3, y - 14]], '#fff8e4'); },
  ibrik(g, x, y) { poly(g, [[x - 6, y - 1], [x + 6, y - 1], [x + 4, y - 12], [x - 4, y - 12]], '#c98b52'); hl(g, x - 4, y - 12, 8, '#f4d79a'); vl(g, x + 4, y - 11, 10, '#a35f12'); ln(g, x + 5, y - 9, x + 14, y - 14, '#7c4635'); ln(g, x + 5, y - 8, x + 14, y - 13, '#59302d'); poly(g, [[x - 4, y - 12], [x - 7, y - 14], [x - 4, y - 10]], '#c98b52'); dith(g, x - 5, y - 8, 10, 6, '#a35f12', 2); },
  sifao(g, x, y) { R(g, x - 2, y - 2, 4, 2, '#2f3142'); ell(g, x, y - 8, 6, 6, 'rgba(200,225,235,0.6)'); ell(g, x, y - 7, 5, 4, '#3b1d17'); vl(g, x, y - 18, 6, '#c3cad6'); poly(g, [[x - 4, y - 30], [x + 4, y - 30], [x + 3, y - 17], [x - 3, y - 17]], 'rgba(200,225,235,0.6)'); R(g, x - 3, y - 26, 6, 6, '#8a5231'); vl(g, x - 9, y - 20, 18, '#555a70'); hl(g, x - 9, y - 20, 9, '#555a70'); R(g, x - 2, y + 0, 4, 1, '#ea8b58'); },
};
function drawKitIcon(g, x, y, id, scale, time) { const f = KIT_ICON[id] || KIT_ICON.coador; f(g, x, y, time || 0); }
function kitIconCanvas(id, sz) {
  sz = sz || 32;
  const g = mk(sz, sz); drawKitIcon(g, sz / 2, sz - 2, id); outline(g, .5); return g.canvas;
}

/* ---------- xícaras e bebidas ---------- */
const CUPS = { xicara: 1, caneca: 1, americano: 1, copoalto: 1, taca: 1 };
function drawDrink(g, x, y, d, time, big) {
  // d: {cup, layers:[{c,h}], foam, art, ice, top:'chantilly'|'canela'|'choco'|null, steam}
  const cup = d.cup || 'xicara', glass = cup === 'americano' || cup === 'copoalto' || cup === 'taca';
  let w, h;
  if (cup === 'xicara') { w = 14; h = 9; } else if (cup === 'caneca') { w = 14; h = 15; } else if (cup === 'americano') { w = 12; h = 15; } else if (cup === 'taca') { w = 14; h = 13; } else { w = 12; h = 22; }
  const k = big ? 2 : 1;
  const G = big ? mk(40, 50) : g, ox = big ? 20 : x, oy = big ? 46 : y;
  const L = ox - w / 2, T = oy - h;
  const cupC = d.cupColor || '#fdf0cf';
  if (cup === 'xicara') { ell(G, ox, oy, w / 2 + 4, 2, '#efe8dc'); hl(G, L - 3, oy, w + 6, '#dad3cc'); }
  // corpo
  if (!glass) {
    R(G, L, T, w, h, cupC); vl(G, L + w - 2, T, h, tone(cupC, -1)); vl(G, L + w - 1, T, h, tone(cupC, -2)); vl(G, L + 1, T + 1, h - 2, tone(cupC, 1));
    if (cup === 'xicara') { R(G, L + 1, oy - 1, w - 2, 1, tone(cupC, -1)); }
    if (d.cupColor && d.cupColor !== '#fdf0cf') hl(G, L, T + 3, w, tone(cupC, 1));
    // alça
    R(G, L + w, T + 2, 3, 2, cupC); R(G, L + w + 2, T + 3, 2, Math.max(3, h - 6), tone(cupC, -1)); R(G, L + w, T + h - 4, 3, 2, tone(cupC, -1));
    // topo: superfície da bebida
    ell(G, ox, T, w / 2, 2, tone(cupC, -1));
    const top = d.foam ? '#e8c9a0' : (d.layers && d.layers.length ? d.layers[d.layers.length - 1].c : PAL.coffee[2]);
    ell(G, ox, T + .5, w / 2 - 1, 1.5, top);
    if (d.art) { P(G, ox, T, '#fdf0cf'); P(G, ox - 1, T, '#fdf0cf'); P(G, ox + 1, T + 1, '#fdf0cf'); }
  } else {
    // vidro com camadas
    const glassC = 'rgba(220,240,248,0.45)';
    let yy = oy - 1;
    const layers = d.layers || [{ c: PAL.coffee[2], h: .7 }];
    const fill = Math.round((h - 3) * layers.reduce((a, b) => a + b.h, 0));
    for (const l of layers) {
      const lh = Math.round((h - 3) * l.h);
      R(G, L + 1, yy - lh + 1, w - 2, lh, l.c); yy -= lh;
    }
    if (d.ice) { for (let i = 0; i < 3; i++) { R(G, L + 2 + i * 3, oy - fill + 1 + (i % 2) * 3, 3, 3, 'rgba(235,250,255,0.75)'); P(G, L + 2 + i * 3, oy - fill + 1 + (i % 2) * 3, '#ffffff'); } }
    if (cup === 'americano') for (let i = 0; i < 4; i++) vl(G, L + 2 + i * 3, T + 1, h - 2, 'rgba(255,255,255,0.22)');
    R(G, L, T, 1, h, glassC); R(G, L + w - 1, T, 1, h, 'rgba(180,200,215,0.7)'); R(G, L, oy - 1, w, 1, 'rgba(180,200,215,0.8)'); hl(G, L, T, w, 'rgba(240,250,255,0.8)');
    vl(G, L + 2, T + 2, h - 5, 'rgba(255,255,255,0.45)');
  }
  // coberturas
  if (d.top === 'chantilly') { ell(G, ox, T - 1, w / 2 - 1, 2.5, '#fff8ee'); ell(G, ox - 1, T - 3, w / 2 - 3, 2, '#ffffff'); P(G, ox, T - 5, '#ffffff'); dith(G, ox - 3, T - 2, 6, 2, '#efe2cf', 2); }
  if (d.top === 'canela') { dith(G, ox - w / 2 + 2, T, w - 4, 1, '#8a5231', 1); }
  if (d.top === 'choco') { dith(G, ox - w / 2 + 2, T - 1, w - 4, 2, '#5a2e22', 2); }
  if (d.top === 'chantilly' && d.syrup) { P(G, ox - 2, T - 2, d.syrup); P(G, ox + 1, T - 3, d.syrup); P(G, ox + 2, T - 1, d.syrup); }
  if (d.straw) { R(G, ox + 2, T - 7, 2, h + 4, d.straw); }
  if (big) { outline(G, .5); g.drawImage(G.canvas, x - 40, y - 92, 80, 100); }
  // vapor
  if (d.steam && time != null) steam(g, x, y - (big ? h * 2 + 6 : h + 1), time, big ? 4 : 2);
}
function steam(g, x, y, time, n) {
  for (let i = 0; i < n; i++) {
    const ph = (time * .8 + i * .37) % 1;
    const yy = y - ph * 14, xx = x - 3 + i * 3 + Math.round(Math.sin(ph * 7 + i * 2) * 2);
    g.globalAlpha = (1 - ph) * .7; P(g, xx, yy, '#ffffff'); P(g, xx, yy - 1, '#ffffff'); g.globalAlpha = 1;
  }
}

/* ---------- fachada ---------- */
function drawFacade(g, S, t, time) {
  const F = S.decor.facade;
  drawSkyline(g, 0, 0, W, 152, t, 41, S.weather);
  const night = t > .84;
  const season = S.season;
  // árvore (ipê no inverno/primavera)
  const tx = 18;
  R(g, tx - 2, 80, 5, 72, '#59302d'); vl(g, tx + 2, 80, 72, '#3a1f26');
  const ipe = season === 'inverno' || season === 'primavera';
  const leafC = ipe ? (season === 'inverno' ? '#f7c232' : '#e88cb0') : season === 'outono' ? '#c98b52' : '#4a8648';
  for (let i = 0; i < 9; i++) { const a = i / 9 * Math.PI * 2; ell(g, tx + Math.cos(a) * 14, 66 + Math.sin(a) * 10, 9, 7, i % 3 ? leafC : tone(leafC, -1)); }
  ell(g, tx, 64, 14, 10, tone(leafC, 1));
  if (ipe) { const r = rng(Math.floor(time * 2)); for (let i = 0; i < 4; i++) P(g, tx - 20 + r() * 60, 80 + r() * 70, leafC); }
  // vizinhos: banca (esq.) e floricultura da Cris (dir.)
  R(g, 32, 70, 42, 82, '#cfa77a'); R(g, 32, 70, 42, 3, '#a56540'); R(g, 36, 96, 34, 40, '#3f6f6a'); R(g, 36, 92, 34, 6, '#cd5b3b'); for (let x = 36; x < 70; x += 6) R(g, x, 92, 3, 6, '#efe8dc');
  drawTxt(g, 'BANCA', 53, 78, 6, '#59302d', 'c');
  for (let i = 0; i < 5; i++) R(g, 40 + i * 6, 104, 4, 6, ['#cd5b3b', '#f7c232', '#6ba3d7', '#e7a3a8', '#84b752'][i]);
  R(g, 248, 64, 72, 88, '#e7a3a8'); R(g, 248, 64, 72, 3, '#b8657a'); R(g, 256, 100, 54, 40, '#fdf0cf'); poly(g, [[252, 92], [316, 92], [312, 100], [256, 100]], '#4a8648');
  for (let x = 256; x < 312; x += 8) poly(g, [[x, 100], [x + 8, 100], [x + 4, 104]], '#4a8648');
  drawTxt(g, 'Flores da Cris', 284, 71, 6, '#7a2638', 'c');
  for (let i = 0; i < 6; i++) drawPlant(g, 262 + i * 9, 150, ['girassol', 'lavanda', 'orquidea', 'girassol', 'samambaia', 'lavanda'][i], Math.round(Math.sin(time + i)));
  // prédio do café (sobrado)
  const bx = 80, bw = 164, wallC = DECOR_COLORS.wall[F.wall] || '#f2c14e', trim = DECOR_COLORS.accent[F.trim] || '#2b5b40';
  R(g, bx, 24, bw, 128, wallC); vl(g, bx + bw - 3, 24, 128, tone(wallC, -1)); vl(g, bx, 24, 2, tone(wallC, 1));
  dith(g, bx, 24, bw, 128, tone(wallC, -1), 0);
  // platibanda e ornamentos
  R(g, bx - 4, 18, bw + 8, 8, trim); hl(g, bx - 4, 18, bw + 8, tone(trim, 1)); hl(g, bx - 4, 25, bw + 8, tone(trim, -1));
  poly(g, [[bx + bw / 2 - 18, 18], [bx + bw / 2, 8], [bx + bw / 2 + 18, 18]], trim); ell(g, bx + bw / 2, 15, 4, 4, wallC); flower(g, bx + bw / 2, 15, 1);
  drawTxt(g, String(S.foundedYear || 1974), bx + bw / 2, 16, 6, wallC, 'c');
  // janelas do andar de cima
  for (let i = 0; i < 3; i++) {
    const wx = bx + 16 + i * 50, wy = 32;
    R(g, wx - 2, wy - 2, 32, 30, trim); R(g, wx, wy, 28, 26, night ? '#ffcf7a' : '#7fa9cf'); if (!night) { R(g, wx, wy + 14, 28, 12, '#6b8fb8'); ln(g, wx + 3, wy + 20, wx + 12, wy + 2, '#a7d2ee'); }
    vl(g, wx + 13, wy, 26, trim); hl(g, wx, wy + 12, 28, trim);
    R(g, wx - 4, wy + 26, 36, 3, tone(trim, -1));
    // floreira
    R(g, wx - 1, wy + 22, 30, 4, '#b85a3a'); for (let k = 0; k < 7; k++) flower(g, wx + 2 + k * 4, wy + 21, 0);
  }
  // letreiro
  const sy = 64, nm = S.cafeName || 'Café Girassol';
  const sz = fitTxt(nm, bw - 30, 10), sb = sz === 8, ty = sy + (sz >= 10 ? -1 : 3);
  if (F.sign === 'neon') {
    R(g, bx + 10, sy, bw - 20, 18, '#1b1726'); const glow = night || t > .7;
    const col = '#ff8fb1';
    if (glow) { g.globalAlpha = .35; drawTxt(g, nm, bx + bw / 2 + 1, ty, sz, col, 'c', sb); drawTxt(g, nm, bx + bw / 2 - 1, ty, sz, col, 'c', sb); g.globalAlpha = 1; }
    drawTxt(g, nm, bx + bw / 2, ty, sz, glow ? '#ffe3ec' : '#b06a82', 'c', sb);
  } else if (F.sign === 'pintado') {
    drawTxt(g, nm, bx + bw / 2, ty, sz, tone(trim, -1), 'c', sb, tone(wallC, -2));
    flower(g, bx + 14, sy + 9, 1); flower(g, bx + bw - 14, sy + 9, 1);
  } else {
    R(g, bx + 10, sy, bw - 20, 18, '#7c4635'); hl(g, bx + 10, sy, bw - 20, '#a56540'); hl(g, bx + 10, sy + 17, bw - 20, '#3a1f26');
    for (let x = bx + 14; x < bx + bw - 14; x += 12) hl(g, x, sy + 4 + (x % 3), 6, '#8a5133');
    drawTxt(g, nm, bx + bw / 2, ty, sz, '#f7c232', 'c', sb, '#3a1f26');
    vl(g, bx + 30, 58, 6, PAL.ink2); vl(g, bx + bw - 30, 58, 6, PAL.ink2);
  }
  // toldo
  const aw = F.awning || 'listras', ac = DECOR_COLORS.accent[F.awningColor] || '#7a2638';
  const ay = 84;
  for (let y = 0; y < 10; y++) for (let x = bx + 4 - y; x < bx + bw - 4 + y; x++) {
    let c = ac;
    if (aw === 'listras') c = Math.floor((x - bx) / 8) % 2 ? ac : '#f6ead2';
    else if (aw === 'ondas') c = (y + Math.round(Math.sin(x / 3) * 1.5)) % 4 < 2 ? ac : tone(ac, 1);
    if (y < 2) c = tone(c, 1);
    P(g, x, ay + y, c);
  }
  for (let x = bx - 6; x < bx + bw + 6; x += 8) { const c = aw === 'listras' ? (Math.floor((x - bx + 6) / 8) % 2 ? ac : '#f6ead2') : ac; poly(g, [[x, ay + 10], [x + 8, ay + 10], [x + 4, ay + 14]], tone(c, -1)); }
  // vitrine e porta
  const vx = bx + 10, vy = 100, vw = 92, vh = 46;
  R(g, vx - 3, vy - 3, vw + 6, vh + 3, trim);
  const inside = night ? '#ffd38a' : t > .7 ? '#f3c27e' : '#e9c592';
  R(g, vx, vy, vw, vh, inside);
  // interior visto da rua: balcão, luminárias, silhuetas
  R(g, vx, vy + 30, vw, 16, '#7c4635'); hl(g, vx, vy + 30, vw, '#a56540');
  for (let i = 0; i < 3; i++) { vl(g, vx + 16 + i * 30, vy, 6, PAL.ink2); ell(g, vx + 16 + i * 30, vy + 7, 4, 2, '#2b5b40'); ell(g, vx + 16 + i * 30, vy + 9, 2, 1, '#fff4b8'); }
  if (!S._closed) { drawMini(g, vx + 30, vy + 30, 77, false, Math.floor(time) % 2); drawMini(g, vx + 64, vy + 32, 78, true, 0); }
  ln(g, vx + 6, vy + 40, vx + 30, vy + 4, 'rgba(255,255,255,0.35)'); ln(g, vx + 12, vy + 42, vx + 36, vy + 6, 'rgba(255,255,255,0.2)');
  vl(g, vx + vw / 2, vy, vh, trim);
  drawTxt(g, 'cafés', vx + vw / 4 + 1, vy + 14, 6, tone(trim, -1), 'c');
  // porta
  const dx = bx + 116, dw = 36, dc = DECOR_COLORS.accent[F.door] || '#7a2638';
  R(g, dx - 3, vy - 3, dw + 6, 55, trim); R(g, dx, vy, dw, 52, dc); R(g, dx + 4, vy + 4, dw - 8, 22, inside); vl(g, dx + dw / 2, vy + 4, 22, dc); R(g, dx + 5, vy + 30, dw - 10, 18, tone(dc, -1)); R(g, dx + 6, vy + 31, dw - 12, 16, dc);
  R(g, dx + dw - 7, vy + 27, 3, 4, PAL.gold);
  R(g, dx + 4, vy + 10, 28, 9, PAL.paper); drawTxt(g, S._closed ? 'FECHADO' : 'ABERTO', dx + dw / 2, vy + 9, 6, S._closed ? '#24526b' : '#a2352f', 'c');
  // luzinhas
  if (F.lights) { for (let x = bx; x < bx + bw; x++) { const y = 94 + Math.round(Math.sin((x - bx) / bw * Math.PI * 3) * 2 + 2); if (x % 2) P(g, x, y, '#3a2130'); if (x % 7 === 0) { const on = night || t > .7; const c = ['#fff4b8', '#ffd27a', '#ffb18a'][(x + Math.floor(time * 2)) % 3]; R(g, x, y + 1, 2, 2, on ? c : '#c9b98a'); } } }
  // mural de girassol (lateral)
  if (F.mural) { for (let i = 0; i < 3; i++) { const fx = bx + bw - 14, fy = 104 + i * 14; ln(g, fx, fy + 6, fx, fy + 14, '#2b5b40'); flower(g, fx, fy + 3, 1); } }
  // calçada portuguesa (ondas)
  R(g, 0, 152, W, 18, '#efe8dc');
  for (let x = 0; x < W; x++) { const y0 = 158 + Math.round(Math.sin(x / 9) * 3); R(g, x, y0, 1, 3, '#2a242f'); }
  hl(g, 0, 152, W, '#c9c0bd'); hl(g, 0, 169, W, '#8d94a8');
  R(g, 0, 170, W, 10, '#4a4250'); for (let x = 6; x < W; x += 30) R(g, x, 175, 14, 1, '#dad3cc');
  // canteiros de girassol (jardim)
  const beds = S.garden || [];
  for (let i = 0; i < 4; i++) {
    const gx = bx + 6 + i * 22 + (i > 1 ? 0 : 0), gy = 152;
    R(g, gx - 8, gy - 4, 17, 5, '#7c4635'); hl(g, gx - 8, gy - 4, 17, '#a56540'); R(g, gx - 7, gy - 3, 15, 2, '#3b1d17');
    const b = beds[i];
    if (b) drawSunflowerStage(g, gx, gy - 4, b.stage, Math.round(Math.sin(time * 1.2 + i)));
  }
  if (F.bench) { R(g, 214, 140, 30, 3, '#a56540'); R(g, 214, 133, 30, 2, '#a56540'); vl(g, 216, 143, 8, PAL.ink2); vl(g, 241, 143, 8, PAL.ink2); }
  if (F.bike) { const x = 300, y = 160; ell(g, x - 8, y, 5, 5, PAL.ink2); ell(g, x - 8, y, 4, 4, '#efe8dc'); ell(g, x + 8, y, 5, 5, PAL.ink2); ell(g, x + 8, y, 4, 4, '#efe8dc'); ln(g, x - 8, y, x, y - 7, '#cd5b3b'); ln(g, x, y - 7, x + 8, y, '#cd5b3b'); ln(g, x - 2, y - 8, x + 6, y - 8, '#cd5b3b'); R(g, x + 5, y - 13, 7, 4, '#c98b52'); flower(g, x + 8, y - 13, 0); }
  // poste
  R(g, 74, 60, 2, 92, '#2f3142'); R(g, 70, 56, 10, 4, '#2f3142'); ell(g, 75, 61, 4, 2, night || t > .78 ? '#fff4b8' : '#d9d2b8');
  if (S.flags && S.flags.gato) drawCat(g, dx + dw + 10, 152, time);
  // chuva
  if (S.weather === 'chuva') { const r = rng(Math.floor(time * 14)); for (let i = 0; i < 90; i++) { const rx = r() * W, ry = r() * 170; vl(g, rx, ry, 4, 'rgba(210,225,245,0.7)'); } }
  // decoração sazonal
  if (S.festa === 'junina') { for (let x = 0; x < W; x += 1) { const y = 4 + Math.round(Math.sin(x / W * Math.PI * 2) * 3 + 3); if (x % 2) P(g, x, y, '#3a2130'); if (x % 8 === 0) poly(g, [[x, y + 1], [x + 6, y + 1], [x + 3, y + 7]], ['#cd5b3b', '#f7c232', '#6cc0b1', '#e7a3a8', '#84b752'][(x / 8) % 5]); } }
  if (S.festa === 'natal') { for (let x = bx; x < bx + bw; x += 6) P(g, x, 27, ['#cd5b3b', '#84b752', '#f7c232'][(x / 6 + Math.floor(time * 2)) % 3]); }
}

/* ---------- partículas ---------- */
const FX = [];
function fxAdd(p) { FX.push(p); if (FX.length > 180) FX.shift(); }
function fxBurst(x, y, kind, n) {
  for (let i = 0; i < (n || 10); i++) {
    const a = Math.random() * Math.PI * 2, sp = .3 + Math.random() * 1.2;
    fxAdd({ x, y, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - .8, life: 1, decay: .012 + Math.random() * .015, kind });
  }
}
function fxStep(g) {
  for (let i = FX.length - 1; i >= 0; i--) {
    const p = FX[i];
    p.x += p.vx; p.y += p.vy; p.vy += p.kind === 'heart' ? -.01 : .03; p.vx *= .97; p.life -= p.decay;
    if (p.life <= 0) { FX.splice(i, 1); continue; }
    if (p.kind === 'heart') { const c = '#e2605c'; P(g, p.x - 1, p.y, c); P(g, p.x + 1, p.y, c); P(g, p.x, p.y + 1, c); P(g, p.x - 1, p.y - 1, '#f8a0a0'); P(g, p.x + 1, p.y - 1, c); }
    else if (p.kind === 'coin') { P(g, p.x, p.y, '#f7c232'); P(g, p.x + 1, p.y, '#a35f12'); }
    else if (p.kind === 'petal') { P(g, p.x, p.y, p.life > .5 ? '#f7c232' : '#ffe274'); }
    else if (p.kind === 'grounds') { P(g, p.x, p.y, '#5e3120'); }
    else { P(g, p.x, p.y, p.life > .5 ? '#fff4b8' : '#ffffff'); }
  }
}
