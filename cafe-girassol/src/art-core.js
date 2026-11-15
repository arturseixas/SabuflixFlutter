'use strict';
/* Café Girassol — núcleo de pixel art procedural (sem imagens externas). */
const W = 480, H = 270;

function mk(w, h) {
  const c = document.createElement('canvas');
  c.width = w; c.height = h;
  const g = c.getContext('2d');
  g.imageSmoothingEnabled = false;
  return g;
}

/* ---------- RNG determinístico ---------- */
function rng(seed) {
  let a = (seed >>> 0) || 1;
  return function () {
    a |= 0; a = a + 0x6D2B79F5 | 0;
    let t = Math.imul(a ^ a >>> 15, 1 | a);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}
function hashStr(s) {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); }
  return h >>> 0;
}

/* ---------- Cor ---------- */
function h2r(h) { const n = parseInt(h.slice(1), 16); return [n >> 16 & 255, n >> 8 & 255, n & 255]; }
function r2h(r, g, b) {
  return '#' + [r, g, b].map(v => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, '0')).join('');
}
function rgb2hsl(r, g, b) {
  r /= 255; g /= 255; b /= 255;
  const mx = Math.max(r, g, b), mn = Math.min(r, g, b);
  let h = 0, s = 0; const l = (mx + mn) / 2;
  if (mx !== mn) {
    const d = mx - mn;
    s = l > .5 ? d / (2 - mx - mn) : d / (mx + mn);
    if (mx === r) h = (g - b) / d + (g < b ? 6 : 0);
    else if (mx === g) h = (b - r) / d + 2;
    else h = (r - g) / d + 4;
    h *= 60;
  }
  return [h, s, l];
}
function hsl2hex(h, s, l) {
  h = ((h % 360) + 360) % 360;
  const c = (1 - Math.abs(2 * l - 1)) * s, x = c * (1 - Math.abs((h / 60) % 2 - 1)), m = l - c / 2;
  let r = 0, g = 0, b = 0;
  if (h < 60) { r = c; g = x; } else if (h < 120) { r = x; g = c; } else if (h < 180) { g = c; b = x; }
  else if (h < 240) { g = x; b = c; } else if (h < 300) { r = x; b = c; } else { r = c; b = x; }
  return r2h((r + m) * 255, (g + m) * 255, (b + m) * 255);
}
function hueTo(h, target, t) {
  let d = ((target - h + 540) % 360) - 180;
  return h + d * t;
}
/* ---------- Paleta Girassol: 36 cores fixas ---------- */
const PALETTE = {
  ink: '#1b1018', plum: '#3a2430', mauve: '#5e3f45', rosegrey: '#8a6a6a', offwhite: '#ece2d4',
  wood0: '#40231d', wood1: '#663a29', wood2: '#93583a', wood3: '#c07f4f', tan: '#e2ae76', cream: '#f6dfb0', paper: '#fff5df',
  wine: '#6e2630', terra: '#a8402f', orange: '#d96a3a', peach: '#f39b5e', mustard: '#c4861d', sun: '#f2bd36', butter: '#ffe58a',
  green0: '#1f3a31', green1: '#33613f', leaf: '#5a924b', lime: '#a3c463',
  navy: '#1f2c45', petrol: '#2f5670', teal: '#4b8b93', sage: '#79a7a2', mint: '#b9dfd2',
  sky: '#6f8fc4', skylight: '#b3cdea', rose: '#d9798c', lilac: '#8e6aa8',
  skin0: '#f3caa3', skin1: '#c98a66', skin2: '#8f5440', skin3: '#5c3329',
};
const C = PALETTE;
const PAL_LIST = Object.values(PALETTE);
const PAL_RGB = PAL_LIST.map(h2r);
/* rampas de luz: cada cor sobe para o amarelo e desce para o roxo/azul */
const RAMPS = [
  ['ink', 'plum', 'mauve', 'rosegrey', 'offwhite', 'paper'],
  ['ink', 'wood0', 'wood1', 'wood2', 'wood3', 'tan', 'cream', 'paper'],
  ['plum', 'wine', 'terra', 'orange', 'peach', 'skin0', 'paper'],
  ['wood1', 'wood2', 'mustard', 'sun', 'butter', 'paper'],
  ['navy', 'green0', 'green1', 'leaf', 'lime', 'butter'],
  ['navy', 'petrol', 'teal', 'sage', 'mint', 'paper'],
  ['navy', 'petrol', 'sky', 'skylight', 'paper'],
  ['plum', 'lilac', 'rose', 'skin0', 'paper'],
  ['wood0', 'skin3', 'skin2', 'skin1', 'skin0', 'paper'],
].map(r => r.map(k => PALETTE[k]));
const RAMP_OF = {};
RAMPS.forEach((r, ri) => r.forEach((c, i) => { if (!(c in RAMP_OF)) RAMP_OF[c] = [ri, i]; }));
RAMP_OF[C.wood3] = [1, 4]; RAMP_OF[C.tan] = [1, 5]; RAMP_OF[C.skin1] = [8, 3]; RAMP_OF[C.skin2] = [8, 2];
RAMP_OF[C.rose] = [7, 2]; RAMP_OF[C.lilac] = [7, 1]; RAMP_OF[C.sky] = [6, 2]; RAMP_OF[C.skylight] = [6, 3];
RAMP_OF[C.mustard] = [3, 2]; RAMP_OF[C.sun] = [3, 3]; RAMP_OF[C.butter] = [3, 4]; RAMP_OF[C.lime] = [4, 4];
RAMP_OF[C.green0] = [4, 1]; RAMP_OF[C.green1] = [4, 2]; RAMP_OF[C.leaf] = [4, 3];
RAMP_OF[C.petrol] = [5, 1]; RAMP_OF[C.teal] = [5, 2]; RAMP_OF[C.sage] = [5, 3]; RAMP_OF[C.mint] = [5, 4];
RAMP_OF[C.wine] = [2, 1]; RAMP_OF[C.terra] = [2, 2]; RAMP_OF[C.orange] = [2, 3]; RAMP_OF[C.peach] = [2, 4]; RAMP_OF[C.skin0] = [2, 5];
RAMP_OF[C.mauve] = [0, 2]; RAMP_OF[C.rosegrey] = [0, 3]; RAMP_OF[C.offwhite] = [0, 4]; RAMP_OF[C.plum] = [0, 1];
RAMP_OF[C.wood0] = [1, 1]; RAMP_OF[C.wood1] = [1, 2]; RAMP_OF[C.wood2] = [1, 3]; RAMP_OF[C.cream] = [1, 6]; RAMP_OF[C.paper] = [1, 7];
RAMP_OF[C.skin3] = [8, 1]; RAMP_OF[C.navy] = [5, 0]; RAMP_OF[C.ink] = [0, 0];

/* tabela de cor mais próxima (5 bits por canal) */
const QLUT = new Uint8Array(32768);
(function () {
  for (let r = 0; r < 32; r++) for (let g = 0; g < 32; g++) for (let b = 0; b < 32; b++) {
    const R0 = r * 8 + 4, G0 = g * 8 + 4, B0 = b * 8 + 4;
    let best = 0, bd = 1e9;
    for (let i = 0; i < PAL_RGB.length; i++) {
      const p = PAL_RGB[i], rm = (R0 + p[0]) / 2, dr = R0 - p[0], dg = G0 - p[1], db = B0 - p[2];
      const d = (2 + rm / 256) * dr * dr + 4 * dg * dg + (2 + (255 - rm) / 256) * db * db;
      if (d < bd) { bd = d; best = i; }
    }
    QLUT[r << 10 | g << 5 | b] = best;
  }
})();
const PAL_IDX = {}; PAL_LIST.forEach((c, i) => { PAL_IDX[c] = i; });
function nearestIdx(r, g, b) { return QLUT[(r >> 3) << 10 | (g >> 3) << 5 | (b >> 3)]; }
function snap(hex) { if (hex in PAL_IDX) return hex; if (hex[0] !== '#') return hex; const [r, g, b] = h2r(hex); return PAL_LIST[nearestIdx(r, g, b)]; }
/* tom(): anda na rampa da paleta. Negativo escurece, positivo clareia. */
function tone(hex, step) {
  hex = snap(hex);
  if (!step) return hex;
  const rp = RAMP_OF[hex];
  if (!rp) return hex;
  const ramp = RAMPS[rp[0]];
  return ramp[Math.max(0, Math.min(ramp.length - 1, rp[1] + step))];
}
function mix(a, b, t) {
  const A = h2r(snap(a)), B = h2r(snap(b));
  return PAL_LIST[nearestIdx(Math.round(A[0] + (B[0] - A[0]) * t), Math.round(A[1] + (B[1] - A[1]) * t), Math.round(A[2] + (B[2] - A[2]) * t))];
}
function mixN(stops, t) {
  t = Math.max(0, Math.min(1, t));
  for (let i = 1; i < stops.length; i++) {
    if (t <= stops[i][0]) { const a = stops[i - 1], b = stops[i]; return mix(a[1], b[1], (t - a[0]) / (b[0] - a[0] || 1)); }
  }
  return stops[stops.length - 1][1];
}
/* converte um canvas inteiro para a paleta (alfa vira 0 ou 1) */
function quantize(g) {
  const c = g.canvas || g, x = c.getContext('2d');
  const im = x.getImageData(0, 0, c.width, c.height), d = im.data;
  for (let i = 0; i < d.length; i += 4) {
    if (d[i + 3] < 110) { d[i + 3] = 0; continue; }
    const p = PAL_RGB[QLUT[(d[i] >> 3) << 10 | (d[i + 1] >> 3) << 5 | (d[i + 2] >> 3)]];
    d[i] = p[0]; d[i + 1] = p[1]; d[i + 2] = p[2]; d[i + 3] = 255;
  }
  x.putImageData(im, 0, 0);
  return c;
}
/* luz do dia: cada estado é uma troca de paleta, cor por cor */
const LIGHTS = {
  manha: { mul: [1.02, .94, .84], add: [10, 4, 0] },
  dia: null,
  tarde: { mul: [1.04, .84, .64], add: [14, 2, 0] },
  noite: { mul: [.42, .46, .7], add: [0, 2, 16] },
  noiteDentro: { mul: [.9, .76, .66], add: [6, 0, 0] },
};
const LIGHT_MAP = {};
for (const k in LIGHTS) {
  const L = LIGHTS[k];
  LIGHT_MAP[k] = PAL_RGB.map((p, i) => {
    if (!L) return i;
    const r = Math.min(255, p[0] * L.mul[0] + L.add[0]), g = Math.min(255, p[1] * L.mul[1] + L.add[1]), b = Math.min(255, p[2] * L.mul[2] + L.add[2]);
    return nearestIdx(r | 0, g | 0, b | 0);
  });
}
const _litCache = new WeakMap();
function lit(canvas, light, keep) {
  if (!light || light === 'dia' || !LIGHTS[light]) return canvas;
  let m = _litCache.get(canvas);
  if (!m) { m = {}; _litCache.set(canvas, m); }
  const key = light + (keep ? keep.join('') : '');
  if (m[key]) return m[key];
  const out = document.createElement('canvas'); out.width = canvas.width; out.height = canvas.height;
  const x = out.getContext('2d'); x.drawImage(canvas, 0, 0);
  const im = x.getImageData(0, 0, out.width, out.height), d = im.data, map = LIGHT_MAP[light].slice();
  if (keep) for (const k of keep) map[PAL_IDX[k]] = PAL_IDX[k];
  for (let i = 0; i < d.length; i += 4) {
    if (!d[i + 3]) continue;
    const p = PAL_RGB[map[QLUT[(d[i] >> 3) << 10 | (d[i + 1] >> 3) << 5 | (d[i + 2] >> 3)]]];
    d[i] = p[0]; d[i + 1] = p[1]; d[i + 2] = p[2];
  }
  x.putImageData(im, 0, 0);
  m[key] = out;
  return out;
}
function litColor(hex, light) { if (!light || !LIGHTS[light]) return snap(hex); return PAL_LIST[LIGHT_MAP[light][PAL_IDX[snap(hex)]]]; }

/* ---------- Paleta por papel ---------- */
const PAL = {
  ink: C.ink, ink2: C.plum,
  wood: [C.wood0, C.wood1, C.wood2, C.wood3, C.wood3, C.tan, C.cream],
  cream: C.cream, cream2: C.tan, paper: C.paper,
  sun: [C.wood2, C.mustard, C.sun, C.butter, C.paper],
  terra: [C.wine, C.terra, C.orange, C.peach, C.skin0],
  leaf: [C.green0, C.green1, C.leaf, C.lime, C.lime],
  teal: [C.navy, C.petrol, C.teal, C.sage, C.mint],
  sky: [C.petrol, C.sky, C.skylight, C.paper],
  dusk: [C.navy, C.plum, C.lilac, C.rose, C.peach],
  grey: [C.plum, C.mauve, C.rosegrey, C.rosegrey, C.offwhite, C.paper],
  metal: [C.navy, C.petrol, C.sage, C.skylight, C.paper],
  coffee: [C.ink, C.wood0, C.wood1, C.wood2, C.wood3],
  milk: C.paper, choc: C.wood1, gold: C.sun,
  skin: [
    [C.skin2, C.skin1, C.skin0, C.paper],
    [C.skin2, C.wood3, C.tan, C.skin0],
    [C.wood1, C.wood2, C.skin1, C.tan],
    [C.skin3, C.wood2, C.wood3, C.tan],
    [C.wood0, C.skin3, C.skin2, C.wood2],
    [C.plum, C.wood0, C.skin3, C.skin2],
  ],
  hair: { preto: C.plum, castanho: C.wood1, castclaro: C.wood2, loiro: C.mustard, ruivo: C.terra, grisalho: C.rosegrey, branco: C.offwhite, azul: C.sky, rosa: C.rose },
};

/* ---------- Primitivas ---------- */
function R(g, x, y, w, h, c) { g.fillStyle = c; g.fillRect(x | 0, y | 0, w | 0, h | 0); }
function P(g, x, y, c) { g.fillStyle = c; g.fillRect(x | 0, y | 0, 1, 1); }
function hl(g, x, y, w, c) { R(g, x, y, w, 1, c); }
function vl(g, x, y, h, c) { R(g, x, y, 1, h, c); }
function ell(g, cx, cy, rx, ry, c) {
  g.fillStyle = c;
  for (let y = Math.ceil(cy - ry); y <= Math.floor(cy + ry); y++) {
    const t = (y - cy) / ry;
    const hw = rx * Math.sqrt(Math.max(0, 1 - t * t));
    const x0 = Math.round(cx - hw), x1 = Math.round(cx + hw);
    if (x1 > x0) g.fillRect(x0, y, x1 - x0, 1);
  }
}
function ln(g, x0, y0, x1, y1, c) {
  x0 |= 0; y0 |= 0; x1 |= 0; y1 |= 0;
  g.fillStyle = c;
  const dx = Math.abs(x1 - x0), dy = -Math.abs(y1 - y0), sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1;
  let e = dx + dy;
  for (;;) {
    g.fillRect(x0, y0, 1, 1);
    if (x0 === x1 && y0 === y1) break;
    const e2 = 2 * e;
    if (e2 >= dy) { e += dy; x0 += sx; }
    if (e2 <= dx) { e += dx; y0 += sy; }
  }
}
function poly(g, pts, c) {
  g.fillStyle = c;
  let y0 = Infinity, y1 = -Infinity;
  for (const p of pts) { y0 = Math.min(y0, p[1]); y1 = Math.max(y1, p[1]); }
  for (let y = Math.floor(y0); y <= Math.ceil(y1); y++) {
    const xs = [];
    for (let i = 0; i < pts.length; i++) {
      const a = pts[i], b = pts[(i + 1) % pts.length];
      if ((a[1] <= y && b[1] > y) || (b[1] <= y && a[1] > y)) {
        xs.push(a[0] + (y - a[1]) / (b[1] - a[1]) * (b[0] - a[0]));
      }
    }
    xs.sort((p, q) => p - q);
    for (let i = 0; i + 1 < xs.length; i += 2) {
      const xa = Math.round(xs[i]), xb = Math.round(xs[i + 1]);
      if (xb > xa) g.fillRect(xa, y, xb - xa, 1);
    }
  }
}
/* retículas (dithering) */
function dith(g, x, y, w, h, c, mode) {
  g.fillStyle = c;
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
    const X = x + i, Y = y + j;
    let on;
    if (mode === 1) on = (X + Y) % 2 === 0;                    // 50%
    else if (mode === 2) on = X % 2 === 0 && Y % 2 === 0;      // 25%
    else if (mode === 3) on = !(X % 2 === 0 && Y % 2 === 0);   // 75%
    else on = (X % 4 === 0 && Y % 4 === 0) || (X % 4 === 2 && Y % 4 === 2); // 12%
    if (on) g.fillRect(X, Y, 1, 1);
  }
}
/* gradiente vertical em faixas com retícula entre elas */
function vgrad(g, x, y, w, h, cols) {
  const n = cols.length, bh = h / n;
  for (let i = 0; i < n; i++) {
    const y0 = Math.round(y + i * bh), y1 = Math.round(y + (i + 1) * bh);
    R(g, x, y0, w, y1 - y0, cols[i]);
    if (i > 0) { dith(g, x, y0 - 2, w, 1, cols[i], 2); dith(g, x, y0 - 1, w, 1, cols[i], 1); dith(g, x, y0, w, 1, cols[i - 1], 2); }
  }
}
/* contorno colorido automático (selective outline) */
function outline(g, mixInk) {
  const c = g.canvas, w = c.width, h = c.height;
  const im = g.getImageData(0, 0, w, h), d = im.data, o = new Uint8ClampedArray(d);
  const ink = h2r(PAL.ink), k = mixInk == null ? .62 : mixInk;
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const i = (y * w + x) * 4;
    if (d[i + 3] > 40) continue;
    let r = 0, gg = 0, b = 0, n = 0;
    const nb = [[1, 0], [-1, 0], [0, 1], [0, -1]];
    for (const [dx, dy] of nb) {
      const X = x + dx, Y = y + dy;
      if (X < 0 || Y < 0 || X >= w || Y >= h) continue;
      const j = (Y * w + X) * 4;
      if (d[j + 3] > 200) { r += d[j]; gg += d[j + 1]; b += d[j + 2]; n++; }
    }
    if (n) {
      o[i] = (r / n) * (1 - k) * .55 + ink[0] * k;
      o[i + 1] = (gg / n) * (1 - k) * .45 + ink[1] * k;
      o[i + 2] = (b / n) * (1 - k) * .55 + ink[2] * k;
      o[i + 3] = 255;
    }
  }
  im.data.set(o);
  g.putImageData(im, 0, 0);
}
/* ---------- fonte bitmap 5x7 com acentos (desenhada à mão) ---------- */
const GLYPHS = {
A:'.###.|#...#|#...#|#####|#...#|#...#|#...#',B:'####.|#...#|#...#|####.|#...#|#...#|####.',C:'.###.|#...#|#....|#....|#....|#...#|.###.',
D:'####.|#...#|#...#|#...#|#...#|#...#|####.',E:'#####|#....|#....|####.|#....|#....|#####',F:'#####|#....|#....|####.|#....|#....|#....',
G:'.###.|#...#|#....|#.###|#...#|#...#|.####',H:'#...#|#...#|#...#|#####|#...#|#...#|#...#',I:'###|.#.|.#.|.#.|.#.|.#.|###',
J:'..###|...#.|...#.|...#.|...#.|#..#.|.##..',K:'#...#|#..#.|#.#..|##...|#.#..|#..#.|#...#',L:'#....|#....|#....|#....|#....|#....|#####',
M:'#...#|##.##|#.#.#|#.#.#|#...#|#...#|#...#',N:'#...#|##..#|#.#.#|#.#.#|#..##|#...#|#...#',O:'.###.|#...#|#...#|#...#|#...#|#...#|.###.',
P:'####.|#...#|#...#|####.|#....|#....|#....',Q:'.###.|#...#|#...#|#...#|#.#.#|#..#.|.##.#',R:'####.|#...#|#...#|####.|#.#..|#..#.|#...#',
S:'.###.|#...#|#....|.###.|....#|#...#|.###.',T:'#####|..#..|..#..|..#..|..#..|..#..|..#..',U:'#...#|#...#|#...#|#...#|#...#|#...#|.###.',
V:'#...#|#...#|#...#|#...#|#...#|.#.#.|..#..',W:'#...#|#...#|#...#|#.#.#|#.#.#|##.##|#...#',X:'#...#|#...#|.#.#.|..#..|.#.#.|#...#|#...#',
Y:'#...#|#...#|.#.#.|..#..|..#..|..#..|..#..',Z:'#####|....#|...#.|..#..|.#...|#....|#####',
a:'....|....|.##.|...#|.###|#..#|.###',b:'#...|#...|###.|#..#|#..#|#..#|###.',c:'....|....|.###|#...|#...|#...|.###',
d:'...#|...#|.###|#..#|#..#|#..#|.###',e:'....|....|.##.|#..#|####|#...|.###',f:'.##|#..|###|#..|#..|#..|#..',
g:'....|....|.###|#..#|#..#|#..#|.###|...#|.##.',h:'#...|#...|###.|#..#|#..#|#..#|#..#',i:'#|.|#|#|#|#|#',
j:'..#|...|.##|..#|..#|..#|..#|..#|##.',k:'#...|#...|#..#|#.#.|##..|#.#.|#..#',l:'#.|#.|#.|#.|#.|#.|.#',
m:'.....|.....|##.#.|#.#.#|#.#.#|#.#.#|#.#.#',n:'....|....|###.|#..#|#..#|#..#|#..#',o:'....|....|.##.|#..#|#..#|#..#|.##.',
p:'....|....|###.|#..#|#..#|#..#|###.|#...|#...',q:'....|....|.###|#..#|#..#|#..#|.###|...#|...#',r:'...|...|#.#|##.|#..|#..|#..',
s:'....|....|.###|#...|.##.|...#|###.',t:'#..|#..|###|#..|#..|#..|.##',u:'....|....|#..#|#..#|#..#|#..#|.###',
v:'.....|.....|#...#|#...#|#...#|.#.#.|..#..',w:'.....|.....|#...#|#...#|#.#.#|#.#.#|.#.#.',x:'....|....|#..#|#..#|.##.|#..#|#..#',
y:'....|....|#..#|#..#|#..#|#..#|.###|...#|.##.',z:'....|....|####|...#|.##.|#...|####','ı':'.|.|#|#|#|#|#',
'0':'.###.|#...#|#..##|#.#.#|##..#|#...#|.###.','1':'.#.|##.|.#.|.#.|.#.|.#.|###','2':'.###.|#...#|....#|...#.|..#..|.#...|#####',
'3':'####.|....#|....#|.###.|....#|....#|####.','4':'...#.|..##.|.#.#.|#..#.|#####|...#.|...#.','5':'#####|#....|####.|....#|....#|#...#|.###.',
'6':'.###.|#....|#....|####.|#...#|#...#|.###.','7':'#####|....#|...#.|..#..|.#...|.#...|.#...','8':'.###.|#...#|#...#|.###.|#...#|#...#|.###.',
'9':'.###.|#...#|#...#|.####|....#|....#|.###.',
'.':'.|.|.|.|.|.|#',',':'..|..|..|..|..|..|.#|#.',':':'.|.|#|.|.|#|.',';':'..|..|.#|..|..|.#|#.','!':'#|#|#|#|#|.|#',
'?':'.###.|#...#|....#|...#.|..#..|.....|..#..',"'":'#|#|.|.|.|.|.','"':'#.#|#.#|...|...|...|...|...','-':'...|...|...|###|...|...|...',
'+':'.....|..#..|..#..|#####|..#..|..#..|.....','/':'....#|...#.|...#.|..#..|.#...|.#...|#....','(':'.#|#.|#.|#.|#.|#.|.#',')':'#.|.#|.#|.#|.#|.#|#.',
'%':'##..#|##.#.|...#.|..#..|.#...|.#.##|#..##','$':'..#..|.####|#.#..|.###.|..#.#|####.|..#..','&':'.##..|#..#.|#.#..|.#...|#.#.#|#..#.|.##.#',
'•':'..|..|##|##|..|..|..','*':'.....|#.#.#|.###.|#####|.###.|#.#.#|.....','♥':'.....|.#.#.|#####|#####|.###.|..#..|.....',
'★':'..#..|..#..|#####|.###.|.#.#.|#...#|.....','º':'###|#.#|###|...|###|...|...','ª':'.##|#.#|.##|...|###|...|...','=':'....|....|####|....|####|....|....',
'>':'#...|.#..|..#.|...#|..#.|.#..|#...','<':'...#|..#.|.#..|#...|.#..|..#.|...#','_':'....|....|....|....|....|....|####','#':'.#.#.|#####|.#.#.|.#.#.|#####|.#.#.|.....',
'°':'.#.|#.#|.#.|...|...|...|...','·':'.|.|.|#|.|.|.','|':'#|#|#|#|#|#|#','[':'##|#.|#.|#.|#.|#.|##',']':'##|.#|.#|.#|.#|.#|##',
};
const ACC = { '´': ['.#', '#.'], '`': ['#.', '.#'], '^': ['.#.', '#.#'], '~': ['.##.#'.slice(0, 4), '#..#'.slice(0, 4)] };
ACC['~'] = ['.#.#', '#.#.'];
const ACCENTED = {
  'á': 'a´', 'à': 'a`', 'â': 'a^', 'ã': 'a~', 'é': 'e´', 'ê': 'e^', 'í': 'ı´', 'ó': 'o´', 'ô': 'o^', 'õ': 'o~', 'ú': 'u´', 'ü': 'u^',
  'Á': 'A´', 'À': 'A`', 'Â': 'A^', 'Ã': 'A~', 'É': 'E´', 'Ê': 'E^', 'Í': 'I´', 'Ó': 'O´', 'Ô': 'O^', 'Õ': 'O~', 'Ú': 'U´', 'ñ': 'n~', 'Ñ': 'N~',
};
const FONT = {};
(function buildFont() {
  const parse = (s) => s.split('|');
  for (const k in GLYPHS) {
    const rows = parse(GLYPHS[k]);
    const w = Math.max(...rows.map(r => r.length));
    const px = [];
    rows.forEach((r, y) => { for (let x = 0; x < r.length; x++) if (r[x] === '#') px.push([x, y + 2]); });
    FONT[k] = { w, px };
  }
  for (const k in ACCENTED) {
    const base = FONT[ACCENTED[k][0]], acc = ACC[ACCENTED[k][1]];
    const caps = ACCENTED[k][0] === ACCENTED[k][0].toUpperCase() && ACCENTED[k][0] !== 'ı';
    const px = base.px.slice();
    const aw = acc[0].length, ox = Math.max(0, Math.floor((base.w - aw) / 2) + (aw === 2 && base.w > 3 ? 1 : 0));
    acc.forEach((r, y) => { for (let x = 0; x < r.length; x++) if (r[x] === '#') px.push([x + ox, y + (caps ? 0 : 2)]); });
    FONT[k] = { w: Math.max(base.w, ox + aw), px };
  }
  const cb = FONT.c; FONT['ç'] = { w: cb.w, px: cb.px.concat([[1, 9], [1, 10], [0, 10]]) };
  const CB = FONT.C; FONT['Ç'] = { w: CB.w, px: CB.px.concat([[2, 9], [2, 10], [1, 10]]) };
  FONT['’'] = FONT["'"]; FONT['‘'] = FONT["'"]; FONT['“'] = FONT['"']; FONT['”'] = FONT['"']; FONT['…'] = { w: 5, px: [[0, 8], [2, 8], [4, 8]] };
  FONT['—'] = { w: 5, px: [[0, 5], [1, 5], [2, 5], [3, 5], [4, 5]] }; FONT['–'] = FONT['—'];
})();
const FONT_H = 11;
function measure(str, scale, bold) {
  let w = 0;
  for (const ch of str) { const gl = FONT[ch] || (ch === ' ' ? null : FONT['?']); w += (gl ? gl.w + 1 : 3) + (bold && gl ? 1 : 0); }
  return Math.max(0, w - 1) * scale;
}
const _txtCache = new Map();
function txt(str, size, color, bold) {
  const scale = size >= 10 ? 2 : 1;
  const b = !!bold;
  const key = str + '|' + scale + '|' + color + '|' + (b ? 1 : 0);
  let c = _txtCache.get(key);
  if (c) return c;
  const w = Math.max(1, measure(str, scale, b) + scale), h = FONT_H * scale;
  const g = mk(w, h);
  g.fillStyle = color;
  let x = 0;
  for (const ch of str) {
    const gl = FONT[ch] || (ch === ' ' ? null : FONT['?']);
    if (!gl) { x += 3; continue; }
    for (const [px, py] of gl.px) { g.fillRect((x + px) * scale, py * scale, scale * (b ? 2 : 1), scale); }
    x += gl.w + 1 + (b ? 1 : 0);
  }
  c = g.canvas;
  if (_txtCache.size > 500) _txtCache.clear();
  _txtCache.set(key, c);
  return c;
}
function drawTxt(g, str, x, y, size, color, align, bold, shadow) {
  const c = txt(str, size, color, bold);
  let X = x;
  if (align === 'c') X = Math.round(x - c.width / 2); else if (align === 'r') X = x - c.width;
  if (shadow) g.drawImage(txt(str, size, shadow, bold), X + 1, y + 1);
  g.drawImage(c, X, y);
  return c.width;
}
/* escolhe o maior tamanho que cabe: 10 (2x), 8 (negrito), 6 */
function fitTxt(str, maxW, size) {
  if (size >= 10 && measure(str, 2, false) <= maxW) return 10;
  if (measure(str, 1, true) <= maxW) return 8;
  return 6;
}
