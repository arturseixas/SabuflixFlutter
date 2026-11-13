'use strict';
/* Café Girassol — núcleo de pixel art procedural (sem imagens externas). */
const W = 320, H = 180;

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
/* tom(): desce em direção ao roxo-azulado, sobe em direção ao amarelo (hue shifting). */
const _toneCache = new Map();
function tone(hex, step) {
  if (!step) return hex;
  const k = hex + step;
  let v = _toneCache.get(k);
  if (v) return v;
  let [h, s, l] = rgb2hsl(...h2r(hex));
  if (step < 0) {
    const n = -step;
    h = hueTo(h, 268, Math.min(.5, .11 * n));
    l = l * Math.pow(.76, n);
    s = Math.min(1, s * (1 + .10 * n) + .02 * n);
  } else {
    h = hueTo(h, 46, Math.min(.5, .12 * step));
    l = l + (1 - l) * (1 - Math.pow(.74, step));
    s = s * (1 - .05 * step);
  }
  v = hsl2hex(h, s, l);
  _toneCache.set(k, v);
  return v;
}
function mix(a, b, t) {
  const A = h2r(a), B = h2r(b);
  return r2h(A[0] + (B[0] - A[0]) * t, A[1] + (B[1] - A[1]) * t, A[2] + (B[2] - A[2]) * t);
}
function mixN(stops, t) {
  t = Math.max(0, Math.min(1, t));
  for (let i = 1; i < stops.length; i++) {
    if (t <= stops[i][0]) {
      const a = stops[i - 1], b = stops[i];
      return mix(a[1], b[1], (t - a[0]) / (b[0] - a[0] || 1));
    }
  }
  return stops[stops.length - 1][1];
}

/* ---------- Paleta base ---------- */
const PAL = {
  ink: '#22131c', ink2: '#3a2130',
  wood: ['#3a1f26', '#59302d', '#7c4635', '#a56540', '#c98b52', '#e3b271', '#f4d79a'],
  cream: '#fdf0cf', cream2: '#f3dcab', paper: '#fff8e4',
  sun: ['#a35f12', '#dc941b', '#f7c232', '#ffe274', '#fff4b8'],
  terra: ['#6c1f2d', '#a2352f', '#cd5b3b', '#ea8b58', '#f8ba8a'],
  leaf: ['#1d3a34', '#2b5b40', '#4a8648', '#84b752', '#c3da78'],
  teal: ['#1b3048', '#24526b', '#398290', '#6cc0b1', '#c2ead6'],
  sky: ['#3d6caf', '#6ba3d7', '#a7d2ee', '#e2f2fa'],
  dusk: ['#291f3e', '#4a2f60', '#8b4b7b', '#d67a8a', '#f7b68e'],
  grey: ['#2a242f', '#4a4250', '#766d78', '#a9a0a3', '#dad3cc', '#f2ede6'],
  metal: ['#2f3142', '#555a70', '#8d94a8', '#c3cad6', '#eef2f5'],
  coffee: ['#1c0f12', '#3b1d17', '#5e3120', '#8a5231', '#b98250'],
  milk: '#fbf3e3', choc: '#5a2e22', gold: '#e9b23a',
  skin: [
    ['#7a3f3c', '#c98a6b', '#e9b796', '#f8d6ba'],  // claro
    ['#74403a', '#bd7f5d', '#dea57d', '#f1c7a0'],  // bege
    ['#63332f', '#a5673f', '#c98a5c', '#e2ad7f'],  // moreno claro
    ['#4f2828', '#885034', '#ab6d45', '#c98d5f'],  // moreno
    ['#3c1e24', '#6a3a2a', '#8a5238', '#a66f4b'],  // negro
    ['#2c1620', '#4f2a24', '#6c3d2e', '#87523c'],  // negro retinto
  ],
  hair: {
    preto: '#2a1c26', castanho: '#5a3226', castclaro: '#8a5530', loiro: '#d8a445', ruivo: '#b4502a',
    grisalho: '#9a939a', branco: '#e6e1dc', azul: '#3f7fa8', rosa: '#d0668a',
  },
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
