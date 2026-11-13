'use strict';
/* Gerador de personagens (busto visto por trás do balcão). Sprite 72x100, âncora embaixo ao centro. */
const CH_W = 72, CH_H = 100;
const _chCache = new Map();

function charGeo(spec) {
  const kid = spec.age === 'kid', elder = spec.age === 'elder';
  const g = { cx: 36, cy: 31, rx: 13, ry: 15, neckW: 10, shY: 50, shHW: 25, shRun: 9, jaw: .12, pw: .85 };
  if (spec.build === 'magro') g.shHW = 22;
  if (spec.build === 'largo') { g.shHW = 29; g.neckW = 12; }
  if (spec.face === 'redondo') { g.jaw = .02; g.rx = 14; }
  if (spec.face === 'fino') { g.jaw = .22; g.rx = 12; }
  if (spec.face === 'quadrado') { g.jaw = .04; g.pw = .62; }
  if (elder) { g.shRun = 13; g.shY = 51; }
  if (kid) { g.rx = 13; g.ry = 13; g.cy = 33; g.neckW = 8; g.shY = 49; g.shHW = 16; g.shRun = 7; g.jaw = .04; }
  return g;
}
function headHW(G, y) {
  const t = (y - G.cy) / G.ry;
  if (Math.abs(t) > 1) return -1;
  let hw = G.rx * Math.pow(Math.max(0, 1 - t * t), G.pw / 2 + .08);
  if (t > .25) hw *= 1 - G.jaw * (t - .25) / .75 * 2.2;
  return hw;
}
function bodyHW(G, y) {
  if (y < G.shY) return -1;
  const t = Math.min(1, (y - G.shY) / G.shRun);
  const n = G.neckW / 2 + 3;
  return n + (G.shHW - n) * Math.pow(Math.sin(t * Math.PI / 2), .75);
}

function drawChar(spec, st) {
  st = st || {};
  const key = (spec._k || (spec._k = JSON.stringify(spec))) + '|' + (st.expr || 'neutro') + '|' + (st.blink ? 1 : 0) + '|' + (st.talk ? 1 : 0);
  const hit = _chCache.get(key);
  if (hit) return hit;
  const g = mk(CH_W, CH_H);
  const G = charGeo(spec), cx = G.cx, cy = G.cy;
  const s = PAL.skin[spec.skin || 0];
  const hcol = PAL.hair[spec.hair && spec.hair.color] || (spec.hair && spec.hair.color) || PAL.hair.preto;
  const hc = [tone(hcol, -1), hcol, tone(hcol, 1), tone(hcol, 2)];
  const cl = spec.clothes || { type: 'camiseta', color: '#cd5b3b' };
  const c1 = cl.color, c2 = cl.color2 || tone(c1, 2);
  const hairStyle = (spec.hair && spec.hair.style) || 'curto';
  const kid = spec.age === 'kid', elder = spec.age === 'elder';
  const acc = spec.acc || [];
  const has = a => acc.indexOf(a) >= 0;

  /* ---- capuz atrás do pescoço ---- */
  if (cl.type === 'moletom') { ell(g, cx, G.shY + 1, G.neckW / 2 + 8, 7, tone(c1, -1)); ell(g, cx, G.shY + 1, G.neckW / 2 + 5, 4, tone(c1, -2)); }

  /* ---- cabelo de trás ---- */
  const hairBlob = (test, x0, y0, x1, y1) => {
    for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
      if (!test(x, y)) continue;
      const dx = x - cx;
      let c = hc[1];
      if (dx > 9 || (x + y * 3) % 11 === 0) c = hc[0];
      else if (dx < -3 && dx > -11 && y < cy - 8 && y > cy - 14 && (x + y) % 5 !== 0) c = hc[2];
      P(g, x, y, c);
    }
  };
  const inEll = (x, y, ex, ey, rx, ry) => { const a = (x - ex) / rx, b = (y - ey) / ry; return a * a + b * b <= 1; };
  if (hairStyle === 'longo' || hairStyle === 'ondulado') {
    hairBlob((x, y) => {
      const wob = hairStyle === 'ondulado' ? Math.round(Math.sin(y * .7) * 1.5) : 0;
      const hw = 16 + wob - (y > 64 ? (y - 64) : 0);
      return y >= cy - 8 && Math.abs(x - cx) <= hw && !(y > 68 && (x % 3 === 0));
    }, cx - 20, cy - 10, cx + 20, 70);
  } else if (hairStyle === 'chanel') {
    hairBlob((x, y) => y >= cy - 8 && Math.abs(x - cx) <= 16 - (y > cy + 11 ? (y - cy - 11) * 2 : 0), cx - 18, cy - 10, cx + 18, cy + 15);
  } else if (hairStyle === 'afro') {
    hairBlob((x, y) => inEll(x, y, cx, cy - 6, 21, 20) && !(inEll(x, y, cx, cy - 6, 21, 20) && !inEll(x, y, cx, cy - 6, 20, 19) && (x + y) % 3 === 0), cx - 22, cy - 27, cx + 22, cy + 14);
  } else if (hairStyle === 'cachos') {
    hairBlob((x, y) => {
      if (inEll(x, y, cx, cy - 3, 17, 17)) return true;
      for (let a = 0; a < 12; a++) { const an = a / 12 * Math.PI * 2; if (inEll(x, y, cx + Math.cos(an) * 16, cy - 3 + Math.sin(an) * 16, 3.4, 3.4)) return true; }
      return false;
    }, cx - 21, cy - 23, cx + 21, cy + 17);
  } else if (hairStyle === 'rabo') {
    hairBlob((x, y) => inEll(x, y, cx + 15, cy + 3, 4, 10) || inEll(x, y, cx + 13, cy - 7, 3, 3), cx + 9, cy - 11, cx + 20, cy + 14);
  } else if (hairStyle === 'calvo') {
    hairBlob((x, y) => (inEll(x, y, cx - 13, cy + 1, 3, 6) || inEll(x, y, cx + 13, cy + 1, 3, 6)), cx - 17, cy - 6, cx + 17, cy + 8);
  }

  /* ---- corpo / roupa ---- */
  const pat = (x, y) => {
    const p = cl.pattern;
    if (p === 'listras') return (y % 6 < 2) ? c2 : c1;
    if (p === 'poa') return ((x % 6 === 1 && y % 6 === 1) || (x % 6 === 4 && y % 6 === 4)) ? c2 : c1;
    if (p === 'xadrez') { const a = x % 8 < 2, b = y % 8 < 2; return a && b ? tone(c2, -1) : (a || b) ? c2 : c1; }
    if (p === 'floral') { const k = (x * 7 + y * 13) % 29; return k === 0 ? c2 : k === 11 ? tone(c2, 2) : c1; }
    return c1;
  };
  const regata = cl.type === 'regata';
  for (let y = G.shY; y < CH_H; y++) {
    const hw = bodyHW(G, y);
    for (let x = Math.round(cx - hw); x < Math.round(cx + hw); x++) {
      const dx = x - cx, ad = Math.abs(dx);
      let base = pat(x, y);
      if (regata && ad > G.shHW - 8) base = null;
      if (cl.type === 'cardigan' || cl.type === 'jaqueta') { if (ad < 5 + (y - G.shY) * .12) base = c2; }
      let c;
      if (base === null) { c = dx > G.shHW - 5 ? s[1] : s[2]; if (y === Math.round(G.shY + (1 - Math.cos(Math.min(1, ad / G.shHW) * 1.2)) * 9)) c = s[3]; }
      else {
        c = base;
        if (dx > hw - 5 || dx > G.shHW * .62) c = tone(base, -1);
        if (dx > hw - 2) c = tone(base, -2);
        const top = y - G.shY < 2 + (ad > 8 ? 0 : 0);
        if (dx < -6 && y - (G.shY + (1 - Math.pow(Math.sin(Math.min(1, (hw > 0 ? 1 : 0)) * 1), 1)) ) < 1 && top) c = tone(base, 1);
      }
      P(g, x, y, c);
    }
  }
  /* luz no topo do ombro esquerdo + separação dos braços */
  for (let x = cx - G.shHW + 2; x < cx - G.neckW / 2 - 3; x++) {
    for (let y = G.shY; y < G.shY + G.shRun + 3; y++) { if (Math.abs(x - cx) < bodyHW(G, y) - 0.5) { if (!regata) P(g, x, y, tone(pat(x, y), 1)); break; } }
  }
  if (!kid) {
    const ax = G.shHW - 7, ay = G.shY + G.shRun + 8;
    vl(g, cx - ax, ay, CH_H - ay, tone(c1, -1)); vl(g, cx + ax, ay, CH_H - ay, tone(c1, -2));
  }
  /* sombra do queixo na roupa */
  ell(g, cx + 1, G.shY + 2, G.neckW / 2 + 4, 2, tone(c1, -1));

  /* detalhes de roupa */
  const nb = G.shY; // base do pescoço
  if (cl.type === 'camiseta' || cl.type === 'moletom' || regata) {
    ell(g, cx, nb + 1, G.neckW / 2 + 2, 3.2, s[1]);
    for (let a = 0; a <= 16; a++) { const an = Math.PI * a / 16; P(g, cx + Math.cos(an) * (G.neckW / 2 + 3), nb + 1 + Math.sin(an) * 4, tone(c1, -1)); }
    if (cl.type === 'moletom') { vl(g, cx - 4, nb + 6, 12, c2); vl(g, cx + 4, nb + 6, 10, c2); P(g, cx - 4, nb + 18, tone(c2, -1)); P(g, cx + 4, nb + 16, tone(c2, -1)); }
  } else if (cl.type === 'blusa') {
    ell(g, cx, nb + 1, G.neckW / 2 + 5, 4.2, s[2]); ell(g, cx + 2, nb, G.neckW / 2 + 2, 2.2, s[1]);
    for (let a = 0; a <= 20; a++) { const an = Math.PI * a / 20; P(g, cx + Math.cos(an) * (G.neckW / 2 + 6), nb + 1 + Math.sin(an) * 5, tone(c1, 1)); }
  } else if (cl.type === 'golav' || cl.type === 'scrubs') {
    poly(g, [[cx - G.neckW / 2 - 2, nb - 1], [cx + G.neckW / 2 + 2, nb - 1], [cx, nb + 11]], s[2]);
    poly(g, [[cx + 1, nb - 1], [cx + G.neckW / 2 + 2, nb - 1], [cx + 1, nb + 9]], s[1]);
    ln(g, cx - G.neckW / 2 - 3, nb - 1, cx, nb + 12, tone(c1, cl.type === 'scrubs' ? 1 : -1)); ln(g, cx + G.neckW / 2 + 3, nb - 1, cx, nb + 12, tone(c1, -1));
    if (cl.type === 'scrubs') { R(g, cx + 8, nb + 16, 9, 8, tone(c1, -1)); R(g, cx + 9, nb + 17, 7, 7, c1); vl(g, cx + 11, nb + 14, 4, PAL.metal[3]); }
  } else if (cl.type === 'camisa' || cl.type === 'uniforme' || cl.type === 'suspensorio') {
    poly(g, [[cx - G.neckW / 2 - 1, nb - 2], [cx + G.neckW / 2 + 1, nb - 2], [cx, nb + 6]], s[1]);
    const col = tone(c1, 1);
    poly(g, [[cx - G.neckW / 2 - 3, nb - 3], [cx - 1, nb + 6], [cx - 8, nb + 8]], col);
    poly(g, [[cx + G.neckW / 2 + 3, nb - 3], [cx + 1, nb + 6], [cx + 8, nb + 8]], c1);
    ln(g, cx - G.neckW / 2 - 3, nb - 3, cx - 8, nb + 8, tone(c1, -1)); ln(g, cx + G.neckW / 2 + 3, nb - 3, cx + 8, nb + 8, tone(c1, -2));
    vl(g, cx, nb + 7, CH_H, tone(c1, -1));
    for (let y = nb + 12; y < CH_H; y += 8) P(g, cx - 1, y, tone(c1, 2));
    if (cl.type === 'uniforme') {
      R(g, cx - 2, nb + 4, 4, 3, tone(c2, -1)); poly(g, [[cx - 2, nb + 7], [cx + 2, nb + 7], [cx + 3, nb + 34], [cx, nb + 38], [cx - 3, nb + 34]], c2);
      vl(g, cx + 1, nb + 8, 28, tone(c2, -1));
      R(g, cx - G.shHW + 4, G.shY + G.shRun - 3, 7, 2, tone(c1, -1)); R(g, cx + G.shHW - 11, G.shY + G.shRun - 3, 7, 2, tone(c1, -2));
      R(g, cx - 17, nb + 16, 8, 6, tone(c1, -1)); R(g, cx - 16, nb + 17, 6, 5, c1); hl(g, cx - 16, nb + 17, 6, tone(c1, 1));
    }
    if (cl.type === 'suspensorio') {
      for (const sx of [-12, 10]) { R(g, cx + sx, G.shY + 3, 3, CH_H, c2); vl(g, cx + sx + 2, G.shY + 3, CH_H, tone(c2, -1)); R(g, cx + sx, nb + 22, 3, 2, PAL.gold); }
    }
  } else if (cl.type === 'cardigan' || cl.type === 'jaqueta') {
    ell(g, cx, nb + 1, G.neckW / 2 + 2, 3.2, s[1]);
    for (let y = G.shY + 2; y < CH_H; y++) { const w = Math.round(5 + (y - G.shY) * .12); P(g, cx - w, y, tone(c1, -1)); P(g, cx + w, y, tone(c1, -2)); P(g, cx - w - 1, y, tone(c1, 1)); }
    if (cl.type === 'jaqueta') { poly(g, [[cx - 11, nb - 1], [cx - 5, nb + 3], [cx - 9, nb + 14]], tone(c1, 1)); poly(g, [[cx + 11, nb - 1], [cx + 5, nb + 3], [cx + 9, nb + 14]], tone(c1, -1)); }
    else for (let y = nb + 14; y < CH_H; y += 9) P(g, cx - 8 - Math.round((y - G.shY) * .12), y, tone(c1, 2));
  }

  /* ---- acessórios sobre a roupa ---- */
  if (has('mochila')) for (const sx of [-1, 1]) {
    const x0 = cx + sx * (G.shHW - 12) - 2;
    R(g, x0, G.shY + 4, 4, CH_H, '#2f3142'); vl(g, x0 + (sx > 0 ? 3 : 0), G.shY + 4, CH_H, '#1f2030'); R(g, x0, G.shY + 24, 4, 2, PAL.metal[2]);
  }
  if (has('xale')) {
    for (let y = G.shY - 1; y < G.shY + 26; y++) {
      const hw = bodyHW(G, Math.max(G.shY, y)) + 1;
      for (let x = Math.round(cx - hw); x < Math.round(cx + hw); x++) {
        const ad = Math.abs(x - cx);
        if (ad < 4 + (y - G.shY) * .9 - 0) { if (y < G.shY + 5 || ad > (y - G.shY) * .9 - 9) { /* dentro do V aberto */ } }
        const inside = ad > (y - G.shY) * .55 + G.neckW / 2 - 2;
        if (!inside) continue;
        if (y - G.shY > 12 + (hw - ad) * .9) continue;
        let c = ((x + y) % 4 === 0) ? tone(c2, 1) : c2;
        if (x - cx > hw * .5) c = tone(c2, -1);
        P(g, x, y, c);
      }
    }
  }
  if (has('fita')) for (const sx of [-1, 1]) {
    const x0 = cx + sx * (G.neckW / 2 + 3) - 1;
    R(g, x0, G.shY - 1, 3, 44 + sx * 5, PAL.sun[2]); vl(g, x0 + 2, G.shY - 1, 44 + sx * 5, PAL.sun[1]);
    for (let y = G.shY + 2; y < G.shY + 42 + sx * 5; y += 3) P(g, x0, y, PAL.ink);
  }
  if (has('cracha')) {
    ln(g, cx - G.neckW / 2 - 2, G.shY, cx, G.shY + 26, PAL.teal[2]); ln(g, cx + G.neckW / 2 + 2, G.shY, cx, G.shY + 26, PAL.teal[1]);
    R(g, cx - 4, G.shY + 26, 9, 11, PAL.paper); R(g, cx - 3, G.shY + 28, 3, 4, s[2]); hl(g, cx - 3, G.shY + 27, 3, hc[1]); hl(g, cx + 1, G.shY + 29, 3, PAL.grey[3]); hl(g, cx + 1, G.shY + 31, 3, PAL.grey[3]); hl(g, cx - 3, G.shY + 34, 7, PAL.teal[2]);
  }
  if (has('camera')) {
    ln(g, cx - G.neckW / 2 - 3, G.shY, cx - 6, G.shY + 24, PAL.ink2); ln(g, cx + G.neckW / 2 + 3, G.shY, cx + 6, G.shY + 24, PAL.ink2);
    R(g, cx - 9, G.shY + 23, 18, 12, PAL.grey[1]); R(g, cx - 9, G.shY + 23, 18, 3, PAL.metal[3]); R(g, cx - 5, G.shY + 21, 5, 2, PAL.metal[2]);
    ell(g, cx, G.shY + 30, 4.5, 4.5, PAL.ink); ell(g, cx, G.shY + 30, 3, 3, PAL.teal[1]); P(g, cx - 1, G.shY + 29, PAL.teal[4]); P(g, cx + 6, G.shY + 24, PAL.terra[2]);
  }
  if (has('colar')) for (let a = 1; a < 12; a++) { const an = Math.PI * a / 12; P(g, cx + Math.cos(an) * (G.neckW / 2 + 4), G.shY + 2 + Math.sin(an) * 7, a % 2 ? '#fff8ee' : '#e0d2c4'); }
  if (has('cordao')) { for (let a = 1; a < 12; a++) { const an = Math.PI * a / 12; P(g, cx + Math.cos(an) * (G.neckW / 2 + 3), G.shY + 2 + Math.sin(an) * 9, PAL.gold); } R(g, cx - 1, G.shY + 11, 2, 3, PAL.gold); }

  /* ---- pescoço ---- */
  const nx = Math.round(cx - G.neckW / 2), ny = cy + G.ry - 4;
  R(g, nx, ny, G.neckW, G.shY - ny + 2, s[2]);
  R(g, nx + G.neckW - 3, ny, 3, G.shY - ny + 2, s[1]);
  R(g, nx, ny, G.neckW, 4, s[1]); hl(g, nx + 1, ny + 4, G.neckW - 4, s[1]);
  if (cl.type === 'camiseta' || cl.type === 'moletom' || cl.type === 'blusa' || regata || cl.type === 'cardigan' || cl.type === 'jaqueta') { /* base do pescoço já coberta pela gola */ }
  if (has('cachecol')) {
    R(g, nx - 4, G.shY - 6, G.neckW + 8, 8, c2); hl(g, nx - 4, G.shY - 6, G.neckW + 8, tone(c2, 1)); R(g, nx + G.neckW, G.shY - 6, 4, 8, tone(c2, -1));
    R(g, nx - 2, G.shY + 2, 6, 14, c2); vl(g, nx + 3, G.shY + 2, 14, tone(c2, -1)); for (let x = nx - 2; x < nx + 4; x += 2) P(g, x, G.shY + 16, c2);
    for (let x = nx - 3; x < nx + G.neckW + 4; x += 3) vl(g, x, G.shY - 5, 6, tone(c2, -1));
  }
  if (has('fones')) {
    for (let a = 0; a <= 20; a++) { const an = Math.PI * a / 20; const X = cx + Math.cos(an) * (G.neckW / 2 + 4), Y = G.shY - 1 + Math.sin(an) * 5; R(g, X, Y, 1, 2, PAL.grey[1]); }
    for (const sx of [-1, 1]) { const x0 = cx + sx * (G.neckW / 2 + 5) - 3; R(g, x0, G.shY - 7, 6, 9, PAL.grey[0]); R(g, x0 + 1, G.shY - 6, 4, 7, sx < 0 ? PAL.terra[2] : PAL.terra[1]); P(g, x0 + 2, G.shY - 5, PAL.terra[3]); }
  }

  /* ---- orelhas ---- */
  if (hairStyle !== 'longo' && hairStyle !== 'chanel' && hairStyle !== 'ondulado' && spec.hat !== 'lenco') {
    for (const sx of [-1, 1]) {
      const ex = cx + sx * (Math.round(headHW(G, cy + 2)) + 1);
      R(g, ex - 1, cy - 1, 3, 6, sx < 0 ? s[2] : s[1]); P(g, ex, cy + 1, s[1]); P(g, ex, cy + 2, s[0]);
      if (has('brincos')) R(g, ex - (sx < 0 ? 1 : -1), cy + 5, 1, 2, PAL.gold);
    }
  } else if (has('brincos')) { for (const sx of [-1, 1]) R(g, cx + sx * (Math.round(headHW(G, cy + 5))), cy + 6, 2, 2, PAL.gold); }

  /* ---- cabeça ---- */
  for (let y = cy - G.ry; y <= cy + G.ry; y++) {
    const hw = headHW(G, y); if (hw < 0) continue;
    const x0 = Math.round(cx - hw), x1 = Math.round(cx + hw);
    for (let x = x0; x < x1; x++) {
      const nxr = (x - cx) / hw;
      let c = s[2];
      if (nxr > .55) c = s[1];
      if (y >= cy + G.ry - 1) c = s[1];
      P(g, x, y, c);
    }
  }
  ell(g, cx - 5, cy - 6, 4, 2.5, s[3]);
  if (!kid && !elder) { P(g, cx - 7, cy + 4, s[3]); P(g, cx - 8, cy + 5, s[3]); }
  const blush = mix(s[2], '#e2605c', .38);
  if (spec.blush !== false) { R(g, cx - 10, cy + 6, 3, 2, blush); R(g, cx + 7, cy + 6, 3, 2, mix(s[1], '#e2605c', .32)); }

  /* ---- rosto ---- */
  const ex = [cx - 8, cx + 4], ey = cy + (kid ? 1 : 0);
  const eyeCol = spec.eyeColor || '#2a1a24', lid = s[0];
  const expr = st.expr || 'neutro';
  const radiant = expr === 'radiante';
  for (let i = 0; i < 2; i++) {
    const x = ex[i];
    if (st.blink) { hl(g, x, ey + 2, 4, lid); P(g, x - (i ? 0 : 1) + (i ? 4 : 0), ey + 1, lid); }
    else if (radiant) { hl(g, x, ey + 1, 4, lid); P(g, x - 1 + i * 5, ey + 2, lid); P(g, x + (i ? 0 : 3), ey + 2, lid); }
    else {
      R(g, x, ey, 4, 3, '#fff8ee');
      if (kid) R(g, x, ey, 4, 4, '#fff8ee');
      const ix = x + 1;
      R(g, ix, ey, 2, kid ? 4 : 3, eyeCol); P(g, ix, ey, '#fff8ee');
      hl(g, x, ey - 1, 4, lid); P(g, i ? x + 4 : x - 1, ey, lid);
      if (expr === 'triste') { P(g, i ? x + 3 : x, ey, lid); }
      if (expr === 'surpreso') { hl(g, x, ey - 1, 4, s[2]); hl(g, x, ey - 2, 4, lid); R(g, x, ey - 1, 4, 1, '#fff8ee'); }
      if (spec.eyes === 'cansado' || elder) hl(g, x, ey + (kid ? 4 : 3) + 1, 4, s[1]);
      if (spec.eyes === 'cansado') { hl(g, x + (i ? 0 : 1), ey + 5, 3, mix(s[1], '#5a3a6a', .35)); }
      if (spec.lashes) { P(g, i ? x + 4 : x - 1, ey - 1, lid); }
    }
  }
  /* sobrancelhas */
  const bcol = spec.browColor ? spec.browColor : (hairStyle === 'careca' && !spec.hair.color ? s[0] : mix(hc[0], s[0], .3));
  const by = ey - 4 + (expr === 'surpreso' ? -1 : 0);
  for (let i = 0; i < 2; i++) {
    const x = ex[i] - (i ? 0 : 1), inner = i ? 0 : 1; // inner=1 → lado interno é o direito
    const thick = spec.brows === 'grossa';
    const seg = (xa, w, yy) => { hl(g, xa, yy, w, bcol); if (thick) hl(g, xa, yy + 1, w, bcol); };
    if (expr === 'triste') { if (inner) { seg(x, 3, by + 1); seg(x + 3, 2, by); } else { seg(x, 2, by); seg(x + 2, 3, by + 1); } }
    else if (expr === 'pensativo' && i === 1) { seg(x, 5, by - 1); }
    else if (expr === 'bravo') { if (inner) { seg(x, 3, by); seg(x + 3, 2, by + 1); } else { seg(x, 2, by + 1); seg(x + 2, 3, by); } }
    else seg(x, 5, by);
  }
  /* nariz */
  if (kid) { P(g, cx, cy + 6, s[1]); P(g, cx + 1, cy + 6, s[1]); }
  else {
    vl(g, cx + 1, cy + 2, 4, s[1]);
    if (spec.nose === 'largo') hl(g, cx - 2, cy + 6, 5, s[1]); else hl(g, cx - 1, cy + 6, 3, s[1]);
    P(g, cx - 1, cy + 5, s[3]);
  }
  /* rugas */
  if (elder) {
    P(g, cx - 5, cy + 7, s[1]); P(g, cx - 6, cy + 8, s[1]); P(g, cx + 5, cy + 7, s[1]); P(g, cx + 6, cy + 8, s[0]);
    hl(g, cx - 4, cy - 8, 3, s[1]); hl(g, cx + 1, cy - 8, 4, s[1]); P(g, cx - 10, cy + 2, s[1]); P(g, cx + 9, cy + 2, s[0]);
  }
  /* boca */
  const my = cy + (kid ? 9 : 10), mc = mix(s[0], '#6d1f2e', .55), lip = spec.lip || null;
  if (st.talk) { R(g, cx - 2, my - 1, 5, 3, '#4a1420'); hl(g, cx - 1, my + 1, 3, '#c85a64'); hl(g, cx - 1, my - 1, 3, '#fff8ee'); }
  else if (radiant) { R(g, cx - 3, my - 1, 7, 3, '#4a1420'); hl(g, cx - 2, my - 1, 5, '#fff8ee'); P(g, cx - 4, my - 2, mc); P(g, cx + 4, my - 2, mc); hl(g, cx - 1, my + 1, 3, '#c85a64'); }
  else if (expr === 'feliz') { hl(g, cx - 3, my, 7, mc); P(g, cx - 4, my - 1, mc); P(g, cx + 4, my - 1, mc); if (lip) hl(g, cx - 2, my + 1, 5, lip); }
  else if (expr === 'triste') { hl(g, cx - 2, my, 5, mc); P(g, cx - 3, my + 1, mc); P(g, cx + 3, my + 1, mc); }
  else if (expr === 'surpreso') { R(g, cx - 1, my - 1, 3, 3, '#4a1420'); }
  else if (expr === 'pensativo') { hl(g, cx - 1, my, 4, mc); P(g, cx + 3, my - 1, mc); }
  else if (expr === 'bravo') { hl(g, cx - 2, my, 5, mc); P(g, cx - 3, my + 1, mc); }
  else { hl(g, cx - 2, my, 5, mc); if (lip) hl(g, cx - 1, my + 1, 3, lip); P(g, cx + 3, my - 1, mc); }

  /* barba / bigode */
  const fh = spec.facial;
  if (fh === 'barba' || fh === 'porfazer') {
    for (let y = cy + 4; y <= cy + G.ry + 1; y++) {
      const hw = headHW(G, Math.min(y, cy + G.ry)); if (hw < 0) continue;
      for (let x = Math.round(cx - hw); x < Math.round(cx + hw); x++) {
        const ad = Math.abs(x - cx);
        const inMouth = ad <= 3 && y >= my - 1 && y <= my + 1;
        const cheek = y < my - 2 && ad < hw - 3 - (y - cy - 4) * .2;
        if (inMouth || cheek) continue;
        if (fh === 'porfazer') { if ((x + y) % 2 === 0) P(g, x, y, mix(s[1], hc[0], .45)); }
        else P(g, x, y, x - cx > 6 ? hc[0] : ((x + y * 2) % 7 === 0 ? hc[2] : hc[1]));
      }
    }
    if (fh === 'barba') { hl(g, cx - 4, my - 2, 9, hc[1]); P(g, cx - 5, my - 1, hc[1]); P(g, cx + 5, my - 1, hc[0]); }
  }
  if (fh === 'bigode' || fh === 'cavanhaque') {
    R(g, cx - 4, my - 3, 9, 2, hc[1]); hl(g, cx - 3, my - 3, 3, hc[2]); P(g, cx - 5, my - 1, hc[1]); P(g, cx + 5, my - 1, hc[0]); P(g, cx - 5, my - 2, hc[1]); P(g, cx + 5, my - 2, hc[0]);
    if (fh === 'cavanhaque') { R(g, cx - 3, my + 2, 7, 4, hc[1]); R(g, cx + 2, my + 2, 2, 4, hc[0]); }
  }

  /* ---- cabelo da frente ---- */
  const vol = hairStyle === 'raspado' ? 0 : hairStyle === 'topete' ? 2 : 1.5;
  const fringe = spec.fringe || 'alto';
  const line = (x) => {
    const dx = x - cx, a = Math.abs(dx);
    if (fringe === 'reto') return cy - 5 + (a > 10 ? 2 : 0);
    if (fringe === 'lado') return cy - 12 + (dx + 13) * .32 + (a > 10 ? 3 : 0);
    if (fringe === 'meio') return cy - 12 + a * .55;
    if (fringe === 'cacheado') return cy - 8 + Math.round(Math.sin(x * 1.3) * 1.2);
    return cy - 11 + Math.pow(a / 13, 2) * 9; // alto
  };
  const front = (extra) => {
    for (let y = cy - G.ry - 3; y <= cy + 4; y++) for (let x = cx - G.rx - 4; x <= cx + G.rx + 4; x++) {
      const a = (x - cx) / (G.rx + vol), b = (y - cy) / (G.ry + vol);
      if (a * a + b * b > 1) continue;
      const ins = headHW(G, y) >= 0 && Math.abs(x - cx) < headHW(G, y);
      if (ins && y >= line(x) && !(extra && extra(x, y))) continue;
      if (!ins && y > cy + 1) continue;
      const dx = x - cx;
      let c = hc[1];
      if (dx > 8) c = hc[0];
      else if (inEll(x, y, cx - 5, cy - G.ry + 3, 5, 1.6)) c = hc[2];
      else if ((x * 3 + y * 5) % 13 === 0) c = hc[0];
      P(g, x, y, c);
    }
    /* sombra do cabelo na testa */
    for (let x = cx - G.rx; x <= cx + G.rx; x++) { const y = Math.ceil(line(x)); if (Math.abs(x - cx) < headHW(G, y) - 1 && y < ey - 2) P(g, x, y, s[1]); }
  };
  if (spec.hat !== 'lenco') {
    if (hairStyle === 'careca') { /* nada */ }
    else if (hairStyle === 'calvo') { /* só as laterais (atrás) */ ell(g, cx - 4, cy - 12, 3, 1.5, s[3]); }
    else if (hairStyle === 'afro') front((x, y) => false);
    else if (hairStyle === 'raspado') {
      for (let y = cy - G.ry; y <= cy - 2; y++) { const hw = headHW(G, y); for (let x = Math.round(cx - hw); x < Math.round(cx + hw); x++) if (y < line(x) && (x + y) % 2 === 0) P(g, x, y, mix(hc[1], s[1], .25)); else if (y < line(x)) P(g, x, y, mix(hc[1], s[2], .5)); }
    }
    else front();
    if (hairStyle === 'topete') { ell(g, cx - 2, cy - G.ry - 2, 9, 4, hc[1]); ell(g, cx - 4, cy - G.ry - 3, 5, 1.5, hc[2]); ell(g, cx + 5, cy - G.ry - 1, 4, 3, hc[0]); }
    if (hairStyle === 'coque') { ell(g, cx, cy - G.ry - 4, 6, 5, hc[1]); ell(g, cx - 2, cy - G.ry - 6, 3, 1.5, hc[2]); ell(g, cx + 3, cy - G.ry - 2, 3, 3, hc[0]); hl(g, cx - 4, cy - G.ry, 9, hc[0]); }
    if (hairStyle === 'trancas') for (const sx of [-1, 1]) {
      const x0 = cx + sx * (G.rx) - 2;
      for (let y = cy - 2; y < 76; y++) { const wob = (y >> 2) % 2; R(g, x0 + wob - (sx > 0 ? 0 : 1), y, 4, 1, y % 4 === 0 ? hc[0] : (sx > 0 ? hc[0] : hc[1])); if (y % 4 === 2) P(g, x0 + 1, y, hc[2]); }
      R(g, x0, 76, 4, 2, spec.hair.tie || PAL.sun[2]);
    }
    if (hairStyle === 'cachos' || hairStyle === 'afro') {
      for (let i = 0; i < 26; i++) { const an = i * 2.4, rr = 6 + (i * 7) % 12; const X = cx + Math.cos(an) * rr, Y = cy - 12 + Math.sin(an) * rr * .7; if (Y < line(X) - 1 && Y > cy - G.ry - (hairStyle === 'afro' ? 10 : 4)) { P(g, X, Y, hc[2]); P(g, X + 1, Y + 1, hc[0]); } }
    }
    if (spec.flower) { const fx = cx - G.rx + 1, fy = cy - 9; R(g, fx - 1, fy, 3, 1, spec.flower); R(g, fx, fy - 1, 1, 3, spec.flower); P(g, fx, fy, PAL.sun[2]); }
  }

  /* ---- chapéus ---- */
  const hatC = spec.hatColor || '#59302d';
  if (spec.hat === 'boina') {
    ell(g, cx, cy - G.ry + 1, G.rx + 4, 6, hatC); ell(g, cx - 3, cy - G.ry - 1, G.rx - 2, 2.5, tone(hatC, 1)); ell(g, cx + 8, cy - G.ry + 2, 6, 4, tone(hatC, -1));
    R(g, cx - G.rx - 5, cy - G.ry + 5, 16, 3, tone(hatC, -1)); hl(g, cx - G.rx - 5, cy - G.ry + 5, 15, hatC); P(g, cx, cy - G.ry - 5, tone(hatC, -1));
  } else if (spec.hat === 'bone') {
    for (let y = cy - G.ry - 3; y <= cy - 8; y++) for (let x = cx - G.rx - 2; x <= cx + G.rx + 2; x++) { const a = (x - cx) / (G.rx + 2), b = (y - (cy - 7)) / (G.ry - 3); if (a * a + b * b <= 1) P(g, x, y, x - cx > 7 ? tone(hatC, -1) : (x - cx < -3 && y < cy - G.ry + 2) ? tone(hatC, 1) : hatC); }
    ell(g, cx, cy - 7, G.rx + 2, 2.6, tone(hatC, -1)); ell(g, cx - 2, cy - 8, G.rx - 1, 1.3, tone(hatC, 1)); R(g, cx - 3, cy - G.ry + 2, 6, 4, spec.hatColor2 || PAL.cream);
  } else if (spec.hat === 'gorro') {
    for (let y = cy - G.ry - 5; y <= cy - 7; y++) for (let x = cx - G.rx - 2; x <= cx + G.rx + 2; x++) { const a = (x - cx) / (G.rx + 2), b = (y - (cy - 6)) / (G.ry + 1); if (a * a + b * b <= 1) P(g, x, y, x - cx > 7 ? tone(hatC, -1) : hatC); }
    R(g, cx - G.rx - 2, cy - 10, G.rx * 2 + 4, 4, tone(hatC, 1)); for (let x = cx - G.rx - 2; x < cx + G.rx + 2; x += 2) vl(g, x, cy - 10, 4, hatC); ell(g, cx, cy - G.ry - 6, 3, 3, tone(hatC, 2));
  } else if (spec.hat === 'lenco') {
    for (let y = cy - G.ry - 2; y <= cy + 2; y++) for (let x = cx - G.rx - 3; x <= cx + G.rx + 3; x++) {
      const a = (x - cx) / (G.rx + 2), b = (y - cy) / (G.ry + 2);
      if (a * a + b * b > 1) continue;
      const ins = headHW(G, y) >= 0 && Math.abs(x - cx) < headHW(G, y);
      const lineY = cy - 9 + Math.pow(Math.abs(x - cx) / 13, 2) * 10;
      if (ins && y >= lineY) continue;
      let c = hatC; const k = (x * 5 + y * 3) % 17;
      if (k === 0) c = spec.hatColor2 || PAL.sun[2]; else if (k === 8) c = tone(hatC, 2);
      if (x - cx > 8) c = tone(c, -1);
      P(g, x, y, c);
    }
    for (let x = cx - G.rx + 1; x <= cx + G.rx - 1; x++) { const y = Math.ceil(cy - 9 + Math.pow(Math.abs(x - cx) / 13, 2) * 10); P(g, x, y - 1, tone(hatC, -1)); if ((x + cx) % 5 < 3) P(g, x, y, hc[1]); }
    poly(g, [[cx + G.rx - 1, cy + 1], [cx + G.rx + 6, cy + 6], [cx + G.rx + 1, cy + 10]], tone(hatC, -1)); poly(g, [[cx + G.rx, cy + 2], [cx + G.rx + 5, cy + 12], [cx + G.rx - 1, cy + 9]], hatC);
  }

  /* ---- óculos ---- */
  if (spec.glasses) {
    const gc = spec.glassColor || PAL.ink;
    for (let i = 0; i < 2; i++) {
      const x = ex[i] - 2, y = ey - 2;
      if (spec.glasses === 'redondo') {
        hl(g, x + 2, y, 4, gc); hl(g, x + 2, y + 7, 4, gc); vl(g, x, y + 2, 4, gc); vl(g, x + 7, y + 2, 4, gc); P(g, x + 1, y + 1, gc); P(g, x + 6, y + 1, gc); P(g, x + 1, y + 6, gc); P(g, x + 6, y + 6, gc);
      } else { hl(g, x, y, 8, gc); hl(g, x, y + 6, 8, gc); vl(g, x, y, 7, gc); vl(g, x + 7, y, 7, gc); hl(g, x, y + 1, 8, gc); }
      P(g, x + 2, y + 2, '#ffffff');
    }
    hl(g, cx - 2, ey, 4, gc); hl(g, ex[0] - 5, ey, 3, gc); hl(g, ex[1] + 6, ey, 3, gc);
  }

  outline(g);
  /* luz de recorte suave à esquerda (janela) */
  const im = g.getImageData(0, 0, CH_W, CH_H), d = im.data;
  for (let y = 1; y < CH_H - 1; y++) for (let x = 2; x < CH_W - 1; x++) {
    const i = (y * CH_W + x) * 4, l = (y * CH_W + x - 2) * 4, l1 = (y * CH_W + x - 1) * 4;
    if (d[i + 3] && d[l1 + 3] && !d[l + 3] && y > G.shY + 2 && y % 2 === 0) { d[i] = Math.min(255, d[i] + 26); d[i + 1] = Math.min(255, d[i + 1] + 20); d[i + 2] = Math.min(255, d[i + 2] + 8); }
  }
  g.putImageData(im, 0, 0);
  if (_chCache.size > 260) _chCache.clear();
  _chCache.set(key, g.canvas);
  return g.canvas;
}

/* ---------- figurantes pequenos (mesas e calçada) ---------- */
function drawMini(g, x, y, seed, sitting, frame) {
  const r = rng(seed);
  const skin = PAL.skin[Math.floor(r() * 6)];
  const hairs = Object.values(PAL.hair).slice(0, 7), hair = hairs[Math.floor(r() * hairs.length)];
  const shirts = ['#cd5b3b', '#398290', '#dc941b', '#4a8648', '#8b4b7b', '#6ba3d7', '#f3dcab', '#a2352f'];
  const sh = shirts[Math.floor(r() * shirts.length)];
  const long = r() < .45, bob = frame ? 1 : 0;
  const hy = y - (sitting ? 17 : 24) + bob;
  if (long) R(g, x - 4, hy + 1, 8, 9, tone(hair, -1));
  R(g, x - 4, hy + 8, 8, sitting ? 9 : 10, sh); R(g, x + 2, hy + 8, 2, sitting ? 9 : 10, tone(sh, -1)); hl(g, x - 4, hy + 8, 5, tone(sh, 1));
  R(g, x - 5, hy + 9, 1, 6, tone(sh, -1)); R(g, x + 4, hy + 9, 1, 6, tone(sh, -2));
  R(g, x - 1, hy + 6, 2, 2, skin[1]);
  R(g, x - 3, hy, 6, 7, skin[2]); R(g, x + 2, hy + 1, 1, 6, skin[1]);
  R(g, x - 3, hy - 1, 6, 3, hair); R(g, x - 4, hy, 1, 3, hair); R(g, x + 3, hy, 1, 4, tone(hair, -1)); hl(g, x - 2, hy - 1, 3, tone(hair, 1));
  P(g, x - 2, hy + 3, PAL.ink); P(g, x + 1, hy + 3, PAL.ink);
  if (!sitting) {
    const pants = ['#2f3142', '#4a4250', '#24526b', '#59302d'][Math.floor(r() * 4)];
    R(g, x - 3, hy + 18, 3, 6 - bob, pants); R(g, x, hy + 18, 3, 6 - bob, tone(pants, -1));
    R(g, x - 4 + (frame ? 0 : 1), hy + 24 - bob, 4, 1, PAL.ink); R(g, x + (frame ? 1 : 0), hy + 24 - bob, 4, 1, PAL.ink);
  }
}

/* ---------- fregueses aleatórios ---------- */
function randomSpec(r, opts) {
  opts = opts || {};
  const pick = a => a[Math.floor(r() * a.length)];
  const age = opts.age || pick(['young', 'young', 'adult', 'adult', 'adult', 'elder']);
  const fem = r() < .5;
  const skin = Math.floor(r() * 6);
  const natural = skin >= 3 ? ['preto', 'preto', 'castanho'] : ['preto', 'castanho', 'castanho', 'castclaro', 'loiro', 'ruivo'];
  let color = age === 'elder' ? pick(['grisalho', 'branco', 'grisalho', 'castanho']) : (r() < .06 ? pick(['azul', 'rosa']) : pick(natural));
  const fStyles = ['longo', 'ondulado', 'chanel', 'coque', 'rabo', 'cachos', 'afro', 'trancas', 'curto'];
  const mStyles = ['curto', 'curto', 'topete', 'raspado', 'cachos', 'afro', 'careca', 'calvo'];
  let style = pick(fem ? fStyles : mStyles);
  if (age !== 'elder' && style === 'calvo') style = 'curto';
  const cols = ['#cd5b3b', '#398290', '#dc941b', '#4a8648', '#8b4b7b', '#6ba3d7', '#f3dcab', '#a2352f', '#2b5b40', '#d67a8a', '#555a70', '#fdf0cf', '#24526b', '#e9b23a'];
  const types = fem ? ['blusa', 'camiseta', 'cardigan', 'golav', 'camisa', 'regata', 'moletom'] : ['camiseta', 'camisa', 'moletom', 'jaqueta', 'golav', 'camiseta'];
  const spec = {
    age, skin, face: pick(['oval', 'oval', 'redondo', 'fino', 'quadrado']), build: pick(['medio', 'medio', 'magro', 'largo']),
    hair: { style, color }, fringe: pick(fem ? ['lado', 'reto', 'meio', 'alto'] : ['alto', 'alto', 'lado']),
    clothes: { type: pick(types), color: pick(cols), color2: pick(cols), pattern: r() < .3 ? pick(['listras', 'poa', 'xadrez', 'floral']) : null },
    acc: [], lashes: fem,
  };
  if (style === 'cachos' || style === 'afro') spec.fringe = 'cacheado';
  if (!fem && r() < .4) spec.facial = pick(['barba', 'bigode', 'porfazer', 'cavanhaque']);
  if (r() < .25) spec.glasses = pick(['redondo', 'quadrado']);
  if (fem && r() < .5) spec.acc.push('brincos');
  if (fem && r() < .35) spec.lip = pick(['#b03a48', '#c85a64', '#8b3a52']);
  if (r() < .1) spec.acc.push('mochila');
  if (r() < .08) spec.acc.push('fones');
  if (opts.cold && r() < .5) { spec.acc.push('cachecol'); }
  if (!fem && r() < .12) { spec.hat = pick(['bone', 'boina']); spec.hatColor = pick(cols); }
  if (opts.cold && r() < .25) { spec.hat = 'gorro'; spec.hatColor = pick(cols); }
  if (r() < .08) spec.nose = 'largo';
  return spec;
}
