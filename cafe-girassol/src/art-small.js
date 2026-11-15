'use strict';
/* Peças pequenas desenhadas de frente: plantas, flores, quitandas, presentes, kits, xícaras e partículas. */
function drawPlant(g, x, y, kind, sway) {
  // vaso com base em (x,y)
  R(g, x - 5, y - 8, 10, 8, '#93583a'); R(g, x - 6, y - 9, 12, 2, '#d96a3a'); vl(g, x + 4, y - 8, 8, '#a8402f');
  const s = sway || 0;
  if (kind === 'samambaia') {
    for (let i = 0; i < 7; i++) { const an = -Math.PI + i * Math.PI / 6; ln(g, x, y - 9, x + Math.cos(an) * 11 + s, y - 9 + Math.sin(an) * 9 + 6, i % 2 ? '#5a924b' : '#33613f'); }
    ell(g, x, y - 13, 7, 4, '#5a924b'); P(g, x - 3, y - 15, '#a3c463'); P(g, x + 2, y - 14, '#a3c463');
  } else if (kind === 'costela') { // costela-de-adão
    for (let i = 0; i < 4; i++) { const lx = x + (i - 1.5) * 6 + s, ly = y - 18 - (i % 2) * 5; ln(g, x, y - 9, lx, ly, '#33613f'); ell(g, lx, ly, 4, 3, i % 2 ? '#5a924b' : '#33613f'); P(g, lx - 1, ly - 1, '#a3c463'); P(g, lx + 1, ly, '#1f3a31'); }
  } else if (kind === 'cacto') {
    R(g, x - 2, y - 22, 5, 14, '#5a924b'); vl(g, x + 2, y - 22, 14, '#33613f'); R(g, x - 6, y - 17, 3, 5, '#5a924b'); R(g, x - 6, y - 14, 4, 2, '#5a924b'); R(g, x + 4, y - 19, 3, 6, '#33613f'); P(g, x, y - 23, '#e2ae76'); P(g, x - 1, y - 18, '#a3c463');
  } else if (kind === 'girassol') {
    for (let i = 0; i < 3; i++) { const fx = x + (i - 1) * 5 + s, fy = y - 18 - (i === 1 ? 6 : 0); ln(g, x + (i - 1), y - 9, fx, fy, '#33613f'); flower(g, fx, fy, 1); }
    P(g, x - 3, y - 12, '#5a924b'); P(g, x + 3, y - 13, '#5a924b');
  } else if (kind === 'orquidea') {
    ln(g, x, y - 9, x + 3 + s, y - 24, '#33613f'); for (let i = 0; i < 3; i++) { const fx = x + 3 + s + i * 2, fy = y - 24 + i * 4; R(g, fx - 1, fy, 3, 2, '#d9798c'); P(g, fx, fy - 1, '#ece2d4'); P(g, fx, fy + 1, '#8a6a6a'); }
    ell(g, x - 2, y - 10, 5, 1.5, '#33613f');
  } else { // lavanda
    for (let i = -2; i <= 2; i++) { vl(g, x + i * 2, y - 18 + Math.abs(i), 9 - Math.abs(i), '#5a924b'); R(g, x + i * 2, y - 21 + Math.abs(i), 1, 4, '#8e6aa8'); }
  }
}

function flower(g, x, y, big) {
  const p = PAL.sun[2], p2 = PAL.sun[1];
  if (big) {
    for (let a = 0; a < 8; a++) { const an = a * Math.PI / 4; P(g, x + Math.round(Math.cos(an) * 3), y + Math.round(Math.sin(an) * 3), a % 2 ? p2 : p); P(g, x + Math.round(Math.cos(an) * 2), y + Math.round(Math.sin(an) * 2), p); }
    R(g, x - 1, y - 1, 3, 3, '#5c3329'); P(g, x - 1, y - 1, '#93583a');
  } else { P(g, x, y, '#5c3329'); P(g, x - 1, y, p); P(g, x + 1, y, p); P(g, x, y - 1, p); P(g, x, y + 1, p2); }
}

function drawSunflowerStage(g, x, y, stage, sway) {
  // planta de girassol no canteiro: estágios 0 semente … 4 florido
  const s = sway || 0;
  if (stage <= 0) { P(g, x, y - 1, '#5c3329'); P(g, x + 1, y - 1, '#40231d'); return; }
  if (stage === 1) { vl(g, x, y - 4, 4, '#5a924b'); P(g, x - 1, y - 4, '#a3c463'); P(g, x + 1, y - 5, '#a3c463'); return; }
  const hgt = stage === 2 ? 10 : stage === 3 ? 18 : 24;
  ln(g, x, y, x + s, y - hgt, '#33613f'); vl(g, x + 1, y - hgt + 4, hgt - 5, '#5a924b');
  ell(g, x - 3, y - hgt * .5, 3, 1.5, '#5a924b'); ell(g, x + 4, y - hgt * .65, 3, 1.5, '#33613f');
  if (stage === 3) { ell(g, x + s, y - hgt - 1, 2.5, 2.5, '#a3c463'); P(g, x + s, y - hgt - 3, PAL.sun[2]); }
  if (stage >= 4) {
    const fx = x + s, fy = y - hgt - 3;
    for (let a = 0; a < 12; a++) { const an = a * Math.PI / 6; ell(g, fx + Math.cos(an) * 4.2, fy + Math.sin(an) * 4.2, 1.6, 1.6, a % 2 ? PAL.sun[2] : PAL.sun[3]); }
    ell(g, fx, fy, 3, 3, '#5c3329'); P(g, fx - 1, fy - 1, '#93583a'); dith(g, fx - 2, fy - 2, 5, 5, '#40231d', 0);
  }
}


const GIFT_DRAW = {
  relogio(g, x, y, t) { // relógio de parede do Seu Bené
    R(g, x - 7, y - 2, 14, 24, '#5c3329'); R(g, x - 6, y - 1, 12, 22, '#8f5440'); ell(g, x, y + 5, 5, 5, '#fff5df'); P(g, x, y + 5, PAL.ink);
    const a = (t || 0) * Math.PI * 2; ln(g, x, y + 5, x + Math.round(Math.cos(a) * 3), y + 5 + Math.round(Math.sin(a) * 3), PAL.ink); vl(g, x, y + 2, 3, PAL.ink);
    R(g, x - 3, y + 12, 6, 8, '#40231d'); const sw = Math.round(Math.sin((t || 0) * 60) * 2); vl(g, x + sw, y + 12, 5, PAL.gold); ell(g, x + sw, y + 18, 1.5, 1.5, PAL.gold);
    poly(g, [[x - 8, y - 2], [x, y - 7], [x + 8, y - 2]], '#5c3329');
  },
  poema(g, x, y) { R(g, x - 9, y, 18, 22, '#c07f4f'); R(g, x - 7, y + 2, 14, 18, PAL.paper); for (let i = 0; i < 6; i++) hl(g, x - 5, y + 5 + i * 2.4, 6 + (i * 5) % 5, '#8a6a6a'); P(g, x + 4, y + 17, '#a8402f'); },
  desenho(g, x, y) { R(g, x - 10, y, 20, 16, PAL.ink2); R(g, x - 9, y + 1, 18, 14, PAL.paper); R(g, x - 8, y + 2, 8, 6, '#b3cdea'); R(g, x + 1, y + 2, 7, 6, '#f2bd36'); R(g, x - 8, y + 9, 16, 5, '#f39b5e'); ell(g, x - 4, y + 5, 2, 2, PAL.ink); P(g, x + 4, y + 4, PAL.ink); P(g, x + 5, y + 4, PAL.ink); hl(g, x - 6, y + 11, 6, PAL.ink); },
  cartao(g, x, y) { R(g, x - 8, y, 16, 11, '#6f8fc4'); R(g, x - 8, y + 6, 16, 5, '#f6dfb0'); ell(g, x + 4, y + 3, 2, 2, '#ffe58a'); hl(g, x - 7, y + 6, 14, '#fff5df'); R(g, x - 1, y - 1, 2, 2, '#d96a3a'); },
  fotovo(g, x, y) { R(g, x - 8, y, 16, 20, PAL.gold); R(g, x - 7, y + 1, 14, 18, '#93583a'); R(g, x - 6, y + 2, 12, 16, '#f3caa3'); ell(g, x, y + 8, 3, 3.5, '#93583a'); ell(g, x, y + 6, 4, 3, '#ece2d4'); R(g, x - 4, y + 12, 8, 6, '#6e2630'); P(g, x - 1, y + 8, PAL.ink); P(g, x + 1, y + 8, PAL.ink); flower(g, x + 4, y + 14, 0); },
  fotos(g, x, y) { // varal de polaroids da Dani
    for (let i = 0; i < 46; i++) P(g, x - 23 + i, y + Math.round(Math.sin(i / 46 * Math.PI) * 3), '#8f5440');
    const c = ['#6f8fc4', '#e2ae76', '#a3c463', '#f2bd36', '#d96a3a'];
    for (let i = 0; i < 5; i++) { const px = x - 20 + i * 10, py = y + Math.round(Math.sin((i * 10 + 3) / 46 * Math.PI) * 3) + 1; R(g, px - 3, py, 7, 8, PAL.paper); R(g, px - 2, py + 1, 5, 4, c[i]); P(g, px, py - 1, '#a8402f'); }
  },
  radio(g, x, y) { R(g, x - 9, y - 12, 18, 12, '#8f5440'); poly(g, [[x - 9, y - 9], [x, y - 15], [x + 9, y - 9]], '#8f5440'); R(g, x - 7, y - 9, 8, 7, '#c07f4f'); for (let i = 0; i < 3; i++) hl(g, x - 7, y - 8 + i * 2, 8, '#5c3329'); ell(g, x + 5, y - 6, 2, 2, '#e2ae76'); P(g, x + 5, y - 6, PAL.ink); hl(g, x - 9, y - 1, 18, '#40231d'); },
  violao(g, x, y) { ell(g, x, y + 16, 6, 6, '#c07f4f'); ell(g, x, y + 8, 4.5, 4.5, '#c07f4f'); ell(g, x, y + 13, 2, 2, '#40231d'); R(g, x - 1, y - 8, 3, 14, '#5c3329'); R(g, x - 2, y - 11, 5, 4, '#40231d'); vl(g, x + 4, y + 10, 10, '#93583a'); hl(g, x - 2, y + 18, 5, '#40231d'); },
  vaso(g, x, y, t) { R(g, x - 3, y - 9, 7, 9, '#79a7a2'); vl(g, x + 3, y - 9, 9, '#4b8b93'); hl(g, x - 3, y - 9, 7, '#b9dfd2'); for (let i = 0; i < 3; i++) { const fx = x + (i - 1) * 5, fy = y - 17 - (i === 1 ? 4 : 0); ln(g, x, y - 9, fx, fy, '#33613f'); flower(g, fx, fy, 1); } },
  orquidea(g, x, y) { drawPlant(g, x, y, 'orquidea', 0); },
  cortina(g, x, y, w, h) { for (let side = 0; side < 2; side++) { const x0 = side ? x + w - 12 : x; for (let i = 0; i < 12; i++) { const c = i % 3 === 0 ? '#ece2d4' : '#fff5df'; vl(g, x0 + i, y, h - (side ? (11 - i) : i) * .5, c); } for (let k = 0; k < 3; k++) flower(g, x0 + 4 + (k % 2) * 4, y + 8 + k * 12, 0); } R(g, x - 2, y - 2, w + 4, 2, '#8f5440'); },
};


function drawFood(g, x, y, kind) {
  if (kind === 'paodequeijo') { for (const [dx, dy] of [[-3, 0], [3, 0], [0, -3]]) { ell(g, x + dx, y + dy - 2, 3, 2.5, '#e2ae76'); P(g, x + dx - 1, y + dy - 3, '#f6dfb0'); P(g, x + dx + 1, y + dy - 1, '#c07f4f'); } }
  else if (kind === 'bolo') { R(g, x - 6, y - 6, 12, 6, '#f2bd36'); hl(g, x - 6, y - 6, 12, '#ffe58a'); vl(g, x + 5, y - 6, 6, '#c4861d'); dith(g, x - 5, y - 5, 10, 4, '#f2bd36', 2); }
  else if (kind === 'broa') { ell(g, x, y - 3, 5, 3, '#f39b5e'); dith(g, x - 4, y - 5, 8, 4, '#c4861d', 1); P(g, x - 2, y - 5, '#f3caa3'); }
  else if (kind === 'biscoito') { for (let i = -1; i <= 1; i++) { R(g, x + i * 5 - 2, y - 3, 4, 3, '#ece2d4'); P(g, x + i * 5 - 2, y - 3, '#fff5df'); } }
}


/* ---------- kits de café ---------- */
const KIT_ICON = {
  coador(g, x, y, s) { // suporte de madeira + coador de pano + bule
    R(g, x - 9, y - 2, 18, 2, '#8f5440'); vl(g, x - 8, y - 24, 22, '#8f5440'); vl(g, x + 7, y - 24, 22, '#5c3329'); hl(g, x - 8, y - 24, 16, '#93583a');
    poly(g, [[x - 6, y - 23], [x + 6, y - 23], [x + 1, y - 14], [x - 1, y - 14]], '#fff5df'); hl(g, x - 6, y - 23, 12, '#f6dfb0'); ell(g, x, y - 23, 6, 1, '#40231d');
    R(g, x - 5, y - 10, 10, 8, '#ece2d4'); hl(g, x - 5, y - 10, 10, '#fff5df'); vl(g, x + 4, y - 10, 8, '#ece2d4'); R(g, x + 5, y - 8, 2, 4, '#ece2d4'); poly(g, [[x - 5, y - 9], [x - 8, y - 11], [x - 5, y - 7]], '#ece2d4');
  },
  moka(g, x, y) { poly(g, [[x - 5, y - 1], [x + 5, y - 1], [x + 4, y - 10], [x - 4, y - 10]], '#b3cdea'); R(g, x - 5, y - 12, 10, 2, '#2f5670'); poly(g, [[x - 4, y - 12], [x + 4, y - 12], [x + 5, y - 21], [x - 5, y - 21]], '#b3cdea'); vl(g, x + 3, y - 20, 18, '#79a7a2'); poly(g, [[x - 5, y - 21], [x + 5, y - 21], [x, y - 24]], '#79a7a2'); R(g, x + 5, y - 18, 3, 6, PAL.ink2); poly(g, [[x - 5, y - 20], [x - 8, y - 21], [x - 5, y - 18]], '#b3cdea'); vl(g, x - 3, y - 20, 18, '#fff5df'); },
  prensa(g, x, y) { R(g, x - 5, y - 18, 10, 17, C.mint); R(g, x - 5, y - 10, 10, 9, '#5c3329'); hl(g, x - 5, y - 10, 10, '#93583a'); vl(g, x - 5, y - 18, 17, '#b3cdea'); vl(g, x + 4, y - 18, 17, '#79a7a2'); R(g, x - 6, y - 20, 12, 2, '#2f5670'); vl(g, x, y - 25, 5, '#79a7a2'); ell(g, x, y - 25, 1.5, 1, '#1f2c45'); R(g, x + 5, y - 16, 3, 10, PAL.ink2); hl(g, x - 6, y - 1, 12, '#2f5670'); },
  espresso(g, x, y) { R(g, x - 13, y - 26, 26, 25, '#b3cdea'); R(g, x - 13, y - 26, 26, 3, '#fff5df'); vl(g, x + 12, y - 26, 25, '#79a7a2'); R(g, x - 10, y - 21, 20, 5, '#1f2c45'); P(g, x - 7, y - 19, '#f39b5e'); P(g, x - 4, y - 19, '#79a7a2'); ell(g, x + 5, y - 19, 2, 2, '#fff5df'); R(g, x - 6, y - 14, 12, 3, '#2f5670'); R(g, x - 9, y - 13, 4, 2, PAL.ink2); vl(g, x - 2, y - 11, 3, '#2f5670'); vl(g, x + 1, y - 11, 3, '#2f5670'); R(g, x - 3, y - 6, 6, 5, '#fff5df'); R(g, x - 13, y - 2, 26, 2, '#2f5670'); vl(g, x + 10, y - 14, 8, '#79a7a2'); },
  v60(g, x, y) { R(g, x - 5, y - 9, 10, 8, C.mint); R(g, x - 5, y - 6, 10, 5, '#5c3329'); poly(g, [[x - 7, y - 18], [x + 7, y - 18], [x + 2, y - 10], [x - 2, y - 10]], '#ece2d4'); for (let i = 0; i < 3; i++) ln(g, x - 4 + i * 3, y - 17, x - 1 + i, y - 11, '#b9dfd2'); hl(g, x - 7, y - 18, 14, '#fff5df'); R(g, x - 6, y - 10, 12, 1, '#ece2d4'); },
  coldbrew(g, x, y) { R(g, x - 6, y - 20, 12, 19, C.mint); R(g, x - 6, y - 15, 12, 14, '#40231d'); for (let i = 0; i < 3; i++) R(g, x - 4 + i * 3, y - 13 + (i % 2) * 4, 3, 3, '#b9dfd2'); R(g, x - 6, y - 22, 12, 3, '#d96a3a'); vl(g, x - 6, y - 20, 19, '#fff5df'); R(g, x + 6, y - 16, 3, 9, C.skylight); },
  aeropress(g, x, y) { R(g, x - 4, y - 8, 8, 7, C.mint); R(g, x - 4, y - 5, 8, 4, '#93583a'); R(g, x - 5, y - 10, 10, 2, '#1f2c45'); R(g, x - 4, y - 22, 8, 12, '#2f5670'); R(g, x - 3, y - 22, 6, 12, C.sage); R(g, x - 3, y - 15, 6, 5, '#5c3329'); R(g, x - 3, y - 27, 6, 6, '#1f2c45'); R(g, x - 5, y - 28, 10, 2, '#1f2c45'); },
  chemex(g, x, y) { poly(g, [[x - 8, y - 1], [x + 8, y - 1], [x + 3, y - 11], [x + 8, y - 22], [x - 8, y - 22], [x - 3, y - 11]], C.mint); poly(g, [[x - 7, y - 1], [x + 7, y - 1], [x + 3, y - 7], [x - 3, y - 7]], '#5c3329'); R(g, x - 4, y - 13, 8, 4, '#93583a'); P(g, x, y - 11, '#40231d'); poly(g, [[x - 8, y - 22], [x + 8, y - 22], [x + 3, y - 14], [x - 3, y - 14]], '#fff5df'); },
  ibrik(g, x, y) { poly(g, [[x - 6, y - 1], [x + 6, y - 1], [x + 4, y - 12], [x - 4, y - 12]], '#c07f4f'); hl(g, x - 4, y - 12, 8, '#f3caa3'); vl(g, x + 4, y - 11, 10, '#93583a'); ln(g, x + 5, y - 9, x + 14, y - 14, '#8f5440'); ln(g, x + 5, y - 8, x + 14, y - 13, '#5c3329'); poly(g, [[x - 4, y - 12], [x - 7, y - 14], [x - 4, y - 10]], '#c07f4f'); dith(g, x - 5, y - 8, 10, 6, '#93583a', 2); },
  sifao(g, x, y) { R(g, x - 2, y - 2, 4, 2, '#1f2c45'); ell(g, x, y - 8, 6, 6, C.mint); ell(g, x, y - 7, 5, 4, '#40231d'); vl(g, x, y - 18, 6, '#b3cdea'); poly(g, [[x - 4, y - 30], [x + 4, y - 30], [x + 3, y - 17], [x - 3, y - 17]], C.mint); R(g, x - 3, y - 26, 6, 6, '#93583a'); vl(g, x - 9, y - 20, 18, '#2f5670'); hl(g, x - 9, y - 20, 9, '#2f5670'); R(g, x - 2, y + 0, 4, 1, '#f39b5e'); },
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
  const cupC = d.cupColor || '#fff5df';
  if (cup === 'xicara') { ell(G, ox, oy, w / 2 + 4, 2, '#ece2d4'); hl(G, L - 3, oy, w + 6, '#ece2d4'); }
  // corpo
  if (!glass) {
    R(G, L, T, w, h, cupC); vl(G, L + w - 2, T, h, tone(cupC, -1)); vl(G, L + w - 1, T, h, tone(cupC, -2)); vl(G, L + 1, T + 1, h - 2, tone(cupC, 1));
    if (cup === 'xicara') { R(G, L + 1, oy - 1, w - 2, 1, tone(cupC, -1)); }
    if (d.cupColor && d.cupColor !== '#fff5df') hl(G, L, T + 3, w, tone(cupC, 1));
    // alça
    R(G, L + w, T + 2, 3, 2, cupC); R(G, L + w + 2, T + 3, 2, Math.max(3, h - 6), tone(cupC, -1)); R(G, L + w, T + h - 4, 3, 2, tone(cupC, -1));
    // topo: superfície da bebida
    ell(G, ox, T, w / 2, 2, tone(cupC, -1));
    const top = d.foam ? '#f3caa3' : (d.layers && d.layers.length ? d.layers[d.layers.length - 1].c : PAL.coffee[2]);
    ell(G, ox, T + .5, w / 2 - 1, 1.5, top);
    if (d.art) { P(G, ox, T, '#fff5df'); P(G, ox - 1, T, '#fff5df'); P(G, ox + 1, T + 1, '#fff5df'); }
  } else {
    // vidro com camadas
    const glassC = C.mint;
    let yy = oy - 1;
    const layers = d.layers || [{ c: PAL.coffee[2], h: .7 }];
    const fill = Math.round((h - 3) * layers.reduce((a, b) => a + b.h, 0));
    for (const l of layers) {
      const lh = Math.round((h - 3) * l.h);
      R(G, L + 1, yy - lh + 1, w - 2, lh, l.c); yy -= lh;
    }
    if (d.ice) { for (let i = 0; i < 3; i++) { R(G, L + 2 + i * 3, oy - fill + 1 + (i % 2) * 3, 3, 3, C.paper); P(G, L + 2 + i * 3, oy - fill + 1 + (i % 2) * 3, '#fff5df'); } }
    if (cup === 'americano') for (let i = 0; i < 4; i++) vl(G, L + 2 + i * 3, T + 1, h - 2, C.skylight);
    R(G, L, T, 1, h, glassC); R(G, L + w - 1, T, 1, h, C.sage); R(G, L, oy - 1, w, 1, C.sage); hl(G, L, T, w, C.paper);
    vl(G, L + 2, T + 2, h - 5, C.paper);
  }
  // coberturas
  if (d.top === 'chantilly') { ell(G, ox, T - 1, w / 2 - 1, 2.5, '#fff5df'); ell(G, ox - 1, T - 3, w / 2 - 3, 2, '#fff5df'); P(G, ox, T - 5, '#fff5df'); dith(G, ox - 3, T - 2, 6, 2, '#ece2d4', 2); }
  if (d.top === 'canela') { dith(G, ox - w / 2 + 2, T, w - 4, 1, '#93583a', 1); }
  if (d.top === 'choco') { dith(G, ox - w / 2 + 2, T - 1, w - 4, 2, '#5c3329', 2); }
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
    if (ph > .75 && Math.floor(time * 20 + i) % 2) continue;
    const c = ph < .5 ? C.paper : C.offwhite;
    P(g, xx, yy, c); if (ph < .6) P(g, xx, yy - 1, c);
  }
}
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
    if (p.kind === 'heart') { const c = C.rose; P(g, p.x - 1, p.y, c); P(g, p.x + 1, p.y, c); P(g, p.x, p.y + 1, c); P(g, p.x - 1, p.y - 1, C.skin0); P(g, p.x + 1, p.y - 1, c); P(g, p.x, p.y, c); }
    else if (p.kind === 'coin') { P(g, p.x, p.y, C.sun); P(g, p.x + 1, p.y, C.mustard); }
    else if (p.kind === 'petal') { P(g, p.x, p.y, p.life > .5 ? C.sun : C.butter); }
    else if (p.kind === 'grounds') { P(g, p.x, p.y, C.wood1); }
    else if (p.kind === 'leaf') { p.vy = .25; p.vx = Math.sin(p.life * 20) * .4 + .15; P(g, p.x, p.y, p.c || C.orange); P(g, p.x + 1, p.y, p.c || C.orange); }
    else { P(g, p.x, p.y, p.life > .5 ? C.butter : C.paper); }
  }
}
