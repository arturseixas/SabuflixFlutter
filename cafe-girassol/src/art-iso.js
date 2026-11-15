'use strict';
/* Projeção isométrica 2:1 (tile 32x16) e rasterização em pixel. */
const TILE = 16; // meia largura do tile; 1 unidade do mundo = 16 px no chão
function isoXY(o, x, y, z) { return [o.x + (x - y) * 16, o.y + (x + y) * 8 - (z || 0)]; }
function isoR(o, x, y, z) { const p = isoXY(o, x, y, z); return [Math.round(p[0]), Math.round(p[1])]; }

/* Preenche um paralelogramo (p0 + s*e1 + t*e2, s,t em [0,1)) com cor vinda de fn(s,t,u,v)
   u,v = posição em pixels ao longo de e1/e2. Escreve direto nos pixels (sem antialias). */
function texPara(g, p0, e1, e2, fn, opt) {
  opt = opt || {};
  const xs = [p0[0], p0[0] + e1[0], p0[0] + e2[0], p0[0] + e1[0] + e2[0]];
  const ys = [p0[1], p0[1] + e1[1], p0[1] + e2[1], p0[1] + e1[1] + e2[1]];
  const cw = g.canvas.width, ch = g.canvas.height;
  const x0 = Math.max(0, Math.floor(Math.min(...xs))), x1 = Math.min(cw, Math.ceil(Math.max(...xs)));
  const y0 = Math.max(0, Math.floor(Math.min(...ys))), y1 = Math.min(ch, Math.ceil(Math.max(...ys)));
  if (x1 <= x0 || y1 <= y0) return;
  const det = e1[0] * e2[1] - e1[1] * e2[0];
  if (!det) return;
  const L1 = Math.hypot(e1[0], e1[1]), L2 = Math.hypot(e2[0], e2[1]);
  const lu = opt.lenU || L1, lv = opt.lenV || L2;
  const im = g.getImageData(x0, y0, x1 - x0, y1 - y0), d = im.data, W2 = x1 - x0;
  let lastC = null, lastRGB = null;
  for (let py = y0; py < y1; py++) {
    for (let px = x0; px < x1; px++) {
      const dx = px + .5 - p0[0], dy = py + .5 - p0[1];
      const s = (dx * e2[1] - dy * e2[0]) / det, t = (dy * e1[0] - dx * e1[1]) / det;
      if (s < 0 || s >= 1 || t < 0 || t >= 1) continue;
      const c = fn(s, t, s * lu, t * lv, px, py);
      if (!c) continue;
      if (c !== lastC) { lastC = c; lastRGB = h2r(c); }
      const i = ((py - y0) * W2 + (px - x0)) * 4;
      d[i] = lastRGB[0]; d[i + 1] = lastRGB[1]; d[i + 2] = lastRGB[2]; d[i + 3] = 255;
    }
  }
  g.putImageData(im, x0, y0);
}
/* Cola uma textura plana (canvas) num paralelogramo: coluna 0 = começo de e1, linha 0 = topo (fim de e2) */
function texParaImg(g, p0, e1, e2, tex) {
  const tw = tex.width, th = tex.height;
  const td = tex.getContext('2d').getImageData(0, 0, tw, th).data;
  const hex = (i) => '#' + ((1 << 24) | (td[i] << 16) | (td[i + 1] << 8) | td[i + 2]).toString(16).slice(1);
  texPara(g, p0, e1, e2, (s, t) => {
    const tx = Math.min(tw - 1, Math.floor(s * tw)), ty = Math.min(th - 1, Math.floor((1 - t) * th));
    const i = (ty * tw + tx) * 4;
    return td[i + 3] > 100 ? hex(i) : null;
  });
}
/* Faces de uma caixa no mundo. f = {top, left, right} : cor ou função (s,t,u,v) */
function isoBox(g, o, x, y, z, w, d, h, f) {
  const P = (a, b, c) => isoXY(o, a, b, c);
  const asFn = (v) => typeof v === 'function' ? v : () => v;
  if (h > 0 && f.left) { const p0 = P(x, y + d, z); const p1 = P(x + w, y + d, z); texPara(g, [p0[0], p0[1] - h], [p1[0] - p0[0], p1[1] - p0[1]], [0, h], (s, t, u, v) => asFn(f.left)(s, 1 - t, u, h - v)); }
  if (h > 0 && f.right) { const p0 = P(x + w, y + d, z); const p1 = P(x + w, y, z); texPara(g, [p0[0], p0[1] - h], [p1[0] - p0[0], p1[1] - p0[1]], [0, h], (s, t, u, v) => asFn(f.right)(1 - s, 1 - t, (1 - s) * d * 16, h - v)); }
  if (f.top) { const p0 = P(x, y, z + h); const p1 = P(x + w, y, z + h); const p2 = P(x, y + d, z + h); texPara(g, p0, [p1[0] - p0[0], p1[1] - p0[1]], [p2[0] - p0[0], p2[1] - p0[1]], (s, t) => asFn(f.top)(s, t, s * w * 16, t * d * 16)); }
  if (f.edge) {
    const c = f.edge, A = isoR(o, x, y + d, z + h), B = isoR(o, x + w, y + d, z + h), Cc = isoR(o, x + w, y, z + h), D = isoR(o, x, y, z + h);
    const A0 = isoR(o, x, y + d, z), B0 = isoR(o, x + w, y + d, z), C0 = isoR(o, x + w, y, z);
    ln(g, D[0], D[1], A[0], A[1], c); ln(g, D[0], D[1], Cc[0], Cc[1], c); ln(g, A[0], A[1], A0[0], A0[1] - 1, c); ln(g, Cc[0] - 1, Cc[1], C0[0] - 1, C0[1] - 1, c);
    ln(g, A0[0], A0[1] - 1, B0[0], B0[1] - 1, c); ln(g, B0[0], B0[1] - 1, C0[0] - 1, C0[1] - 1, c);
    if (f.hi) { ln(g, A[0], A[1], B[0], B[1], f.hi); ln(g, B[0], B[1], Cc[0] - 1, Cc[1], f.hi); }
  }
}
/* elipse isométrica (2:1) cheia */
function isoEll(g, cx, cy, rx, c) { ell(g, cx, cy, rx, rx / 2, c); }
/* sombra suave no chão: pontilhado */
function isoShadow(g, cx, cy, rx, c) {
  c = c || C.ink;
  g.fillStyle = c;
  const ry = rx / 2;
  for (let y = Math.ceil(cy - ry); y <= cy + ry; y++) for (let x = Math.ceil(cx - rx); x <= cx + rx; x++) {
    const a = (x - cx) / rx, b = (y - cy) / ry;
    if (a * a + b * b <= 1 && (x + y) % 2 === 0) g.fillRect(x, y, 1, 1);
  }
}
