'use strict';
/* Cenas isométricas: o salão do café e a esquina da Rua dos Ipês. Tudo na paleta Girassol. */

const ROOM = { o: { x: 216, y: 98 }, RX: 11, RY: 8, WH: 76 };
const ACCENT = { verde: C.green1, vinho: C.wine, azul: C.petrol, marrom: C.wood1, mostarda: C.mustard, branco: C.offwhite, preto: C.plum };
const WALL_C = { amarelo: C.sun, terracota: C.orange, verde: C.sage, azul: C.sky, rosa: C.rose, creme: C.cream, lilas: C.lilac };
const WALL_IN = { listras: [C.cream, C.tan], azulejo: [C.offwhite, C.sky], tijolo: [C.terra, C.wood3], floral: [C.cream, C.rose], madeira: [C.wood2, C.wood3], verde: [C.sage, C.mint], rosa: [C.rose, C.skin0] };
const COUNTER_C = { madeira: [C.tan, C.wood3, C.wood2, C.wood1], escura: [C.wood2, C.wood1, C.wood0, C.ink], azulejo: [C.offwhite, C.skylight, C.sky, C.petrol], marmore: [C.paper, C.offwhite, C.rosegrey, C.mauve] };

function lightOf(t, inside) { return t < .16 ? 'manha' : t < .6 ? 'dia' : t < .84 ? 'tarde' : inside ? 'noiteDentro' : 'noite'; }

/* escurece/clareia um canvas inteiro andando na rampa da paleta */
function shadeCanvas(g, step) {
  const c = g.canvas, im = g.getImageData(0, 0, c.width, c.height), d = im.data;
  const map = PAL_LIST.map(h => h2r(tone(h, step)));
  for (let i = 0; i < d.length; i += 4) {
    if (!d[i + 3]) continue;
    const p = map[QLUT[(d[i] >> 3) << 10 | (d[i + 1] >> 3) << 5 | (d[i + 2] >> 3)]];
    d[i] = p[0]; d[i + 1] = p[1]; d[i + 2] = p[2];
  }
  g.putImageData(im, 0, 0);
}
/* Scale2x: dobra o tamanho suavizando diagonais, usado nos close-ups */
function scale2x(src) {
  const w = src.width, h = src.height, sd = src.getContext('2d').getImageData(0, 0, w, h).data;
  const out = mk(w * 2, h * 2), od = out.createImageData(w * 2, h * 2), o = od.data;
  const px = (x, y) => { x = Math.max(0, Math.min(w - 1, x)); y = Math.max(0, Math.min(h - 1, y)); const i = (y * w + x) * 4; return (sd[i] << 24 | sd[i + 1] << 16 | sd[i + 2] << 8 | sd[i + 3]) >>> 0; };
  const put = (x, y, v) => { const i = (y * w * 2 + x) * 4; o[i] = v >>> 24; o[i + 1] = v >>> 16 & 255; o[i + 2] = v >>> 8 & 255; o[i + 3] = v & 255; };
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const P0 = px(x, y), A = px(x, y - 1), B = px(x + 1, y), Cc = px(x - 1, y), D = px(x, y + 1);
    let e0 = P0, e1 = P0, e2 = P0, e3 = P0;
    if (A !== D && Cc !== B) { if (Cc === A) e0 = Cc; if (A === B) e1 = B; if (Cc === D) e2 = Cc; if (D === B) e3 = B; }
    put(x * 2, y * 2, e0); put(x * 2 + 1, y * 2, e1); put(x * 2, y * 2 + 1, e2); put(x * 2 + 1, y * 2 + 1, e3);
  }
  out.putImageData(od, 0, 0);
  return out.canvas;
}

/* ======================= TEXTURAS DE PAREDE ======================= */
function wallPatternFlat(g, kind, w, top) {
  const [b1, b2] = WALL_IN[kind] || WALL_IN.listras;
  for (let y = 0; y < top; y++) for (let x = 0; x < w; x++) {
    let c = b1;
    if (kind === 'listras') { const m = x % 9; c = m < 4 ? b1 : m < 8 ? b2 : tone(b2, -1); }
    else if (kind === 'azulejo') { const u = x % 12, v = y % 12; c = C.offwhite; if (u === 0 || v === 0) c = C.skylight; else { const du = Math.abs(u - 6), dv = Math.abs(v - 6); if (du + dv === 3) c = C.sky; if (du + dv <= 1) c = C.petrol; if ((u === 1 || u === 11) && (v === 1 || v === 11)) c = C.sky; if ((du === 0 && dv === 5) || (dv === 0 && du === 5)) c = C.petrol; } }
    else if (kind === 'tijolo') { const row = Math.floor(y / 5), off = row % 2 ? 0 : 6; c = (y % 5 === 0 || (x + off) % 12 === 0) ? C.tan : ((Math.floor((x + off) / 12) + row) % 3 === 0 ? C.wood3 : C.terra); if (c === C.terra && (x * 7 + y * 3) % 11 === 0) c = C.orange; }
    else if (kind === 'floral') { const cx = (x + (Math.floor(y / 10) % 2) * 5) % 10, cy = y % 10; c = C.cream; if (cx === 5 && cy === 5) c = C.butter; else if (Math.abs(cx - 5) + Math.abs(cy - 5) === 1) c = (Math.floor(x / 10) + Math.floor(y / 10)) % 2 ? C.rose : C.sun; else if (cx === 7 && cy === 7) c = C.leaf; }
    else if (kind === 'madeira') { const m = x % 7; c = m === 0 ? C.wood1 : ((x * 13 + Math.floor(y / 6) * 7) % 23 === 0 ? C.wood1 : (m < 3 ? C.wood3 : C.wood2)); }
    else { c = ((x * 3 + y * 5) % 13 === 0) ? tone(b1, 1) : b1; }
    P(g, x, y, c);
  }
}
function wallTex(S, side, light) {
  const D = S.decor.interior, kind = D.wall || 'listras';
  const w = side === 'right' ? ROOM.RX * 16 : ROOM.RY * 16, h = ROOM.WH;
  const g = mk(w, h + 1);
  const wain = 24, top = h - wain;
  wallPatternFlat(g, kind, w, top);
  const wc = kind === 'madeira' ? C.wood1 : kind === 'azulejo' ? C.petrol : C.teal;
  R(g, 0, top, w, wain + 1, wc);
  for (let x = 0; x < w; x += 16) { R(g, x + 2, top + 4, 12, wain - 9, tone(wc, -1)); R(g, x + 3, top + 5, 10, wain - 11, wc); hl(g, x + 3, top + 5, 10, tone(wc, 1)); }
  R(g, 0, top - 2, w, 2, C.wood2); hl(g, 0, top - 2, w, C.tan);
  R(g, 0, h - 4, w, 5, C.wood1); hl(g, 0, h - 4, w, C.wood2);
  R(g, 0, 0, w, 3, C.wood1); hl(g, 0, 2, w, C.wood2);
  if (side === 'right') decorRightWall(g, S, light, top);
  else decorLeftWall(g, S, light, top);
  if (side === 'left') shadeCanvas(g, -1);
  return g.canvas;
}
function gift(S, k) { return S.gifts[k] && S.decor.interior.gifts[k] !== false; }
function decorRightWall(g, S, light, top) {
  const bx = 12, by = 6, bw = 78, bh = 44;
  R(g, bx, by, bw, bh, C.wood1); R(g, bx + 1, by + 1, bw - 2, bh - 2, C.wood2); R(g, bx + 3, by + 3, bw - 6, bh - 6, C.green0);
  dith(g, bx + 3, by + 3, bw - 6, bh - 6, C.navy, 0);
  drawTxt(g, 'Cardápio', bx + bw / 2, by + 2, 6, C.sun, 'c', true);
  const menu = S._menuPreview || [];
  for (let i = 0; i < Math.min(4, menu.length); i++) { const col = i === 0 ? C.butter : C.offwhite; drawTxt(g, menu[i][0], bx + 6, by + 12 + i * 8, 6, col); drawTxt(g, menu[i][1], bx + bw - 6, by + 12 + i * 8, 6, col, 'r'); }
  flower(g, bx + bw - 9, by + 6, 1);
  R(g, bx + 8, by + bh - 1, 10, 2, C.offwhite);
  if (gift(S, 'cartao')) GIFT_DRAW.cartao(g, bx + 8, by + bh - 12);
  const sx = 96, sy = 34;
  if (gift(S, 'fotos')) GIFT_DRAW.fotos(g, sx + 24, sy - 28);
  else drawTxt(g, 'desde ' + (S.foundedYear || 1974), sx + 24, sy - 30, 6, C.wood2, 'c', true);
  R(g, sx, sy, 50, 3, C.wood2); hl(g, sx, sy, 50, C.tan); R(g, sx + 4, sy + 3, 2, 4, C.wood1); R(g, sx + 44, sy + 3, 2, 4, C.wood1);
  const jars = [[C.wood1, C.wood0], [C.paper, C.offwhite], [C.tan, C.wood3], [C.leaf, C.green1]];
  for (let i = 0; i < 4; i++) { const jx = sx + 2 + i * 8; R(g, jx, sy - 9, 6, 9, C.mint); R(g, jx + 1, sy - 6, 4, 6, jars[i][0]); dith(g, jx + 1, sy - 6, 4, 6, jars[i][1], 2); R(g, jx, sy - 10, 6, 2, C.wood3); P(g, jx + 1, sy - 8, C.paper); }
  if (gift(S, 'radio')) GIFT_DRAW.radio(g, sx + 42, sy);
  else for (let i = 0; i < 3; i++) { R(g, sx + 36, sy - 3 - i * 3, 8, 3, C.paper); hl(g, sx + 36, sy - 3 - i * 3, 8, C.offwhite); }
  if (gift(S, 'relogio')) GIFT_DRAW.relogio(g, 156, 8, light === 'tarde' ? .7 : light === 'manha' ? .1 : .3);
  else { ell(g, 156, 16, 7, 7, C.wood1); ell(g, 156, 16, 6, 6, C.paper); P(g, 156, 16, C.ink); vl(g, 156, 11, 5, C.ink); hl(g, 157, 16, 3, C.ink); for (let a = 0; a < 12; a += 3) P(g, 156 + Math.round(Math.cos(a / 6 * Math.PI) * 5), 16 + Math.round(Math.sin(a / 6 * Math.PI) * 5), C.mauve); }
  if (gift(S, 'poema')) GIFT_DRAW.poema(g, 158, 38);
  else { R(g, 150, 36, 16, 20, C.sun); R(g, 151, 37, 14, 18, C.petrol); flower(g, 158, 44, 1); vl(g, 158, 47, 6, C.leaf); }
  if (gift(S, 'violao')) GIFT_DRAW.violao(g, 170, 12);
}
function windowView(g, x, y, w, h, light, S) {
  const sky = ({ manha: [C.skylight, C.butter], dia: [C.sky, C.skylight], tarde: [C.rose, C.peach], noite: [C.navy, C.plum], noiteDentro: [C.navy, C.plum] }[light] || [C.sky, C.skylight]).slice();
  const night = light.startsWith('noite');
  if (S.weather === 'chuva') { sky[0] = night ? C.navy : C.rosegrey; sky[1] = night ? C.mauve : C.offwhite; }
  for (let j = 0; j < h; j++) { const t = j / h; const c = t < .45 ? sky[0] : t < .55 ? ((x + j) % 2 ? sky[0] : sky[1]) : sky[1]; hl(g, x, y + j, w, c); }
  if (night) { const r = rng(8); for (let i = 0; i < 10; i++) P(g, x + r() * w, y + r() * h * .4, C.butter); }
  const r = rng(31); let bx = x;
  while (bx < x + w) { const bw = 6 + Math.floor(r() * 9), bh = Math.min(h - 10, 8 + Math.floor(r() * 14)); const c = night ? C.plum : C.rosegrey; R(g, bx, y + h - 8 - bh, Math.min(bw, x + w - bx), bh, c); for (let wy = y + h - 6 - bh; wy < y + h - 10; wy += 4) for (let wx = bx + 1; wx < Math.min(bx + bw - 1, x + w); wx += 3) P(g, wx, wy, night && r() < .6 ? C.butter : tone(c, -1)); bx += bw + 1; }
  R(g, x, y + h - 8, w, 3, C.leaf); R(g, x, y + h - 5, w, 5, C.offwhite); for (let i = x; i < x + w; i += 2) P(g, i, y + h - 3, C.plum);
  if (S.flags && S.flags.rafaPlaza && !night && w > 30) { R(g, x + w - 14, y + h - 14, 3, 6, C.sun); R(g, x + w - 14, y + h - 17, 3, 3, C.skin1); R(g, x + w - 12, y + h - 11, 4, 3, C.wood3); }
  if (S.weather === 'chuva') for (let i = 0; i < w * h / 40; i++) { const rx = x + ((i * 37) % w), ry = y + ((i * 53) % (h - 2)); vl(g, rx, ry, 2, C.skylight); }
}
function decorLeftWall(g, S, light, top) {
  const D = S.decor.interior, F = S.decor.facade, trim = ACCENT[F.trim] || C.green1, door = ACCENT[F.door] || C.wine;
  const dx = 18, dw = 26, dTop = 22, dh = ROOM.WH - dTop;
  R(g, dx - 2, dTop - 2, dw + 4, dh + 2, trim); R(g, dx, dTop, dw, dh, door);
  windowView(g, dx + 4, dTop + 4, dw - 8, 20, light, S);
  R(g, dx + 3, dTop + 27, dw - 6, 22, tone(door, -1)); R(g, dx + 4, dTop + 28, dw - 8, 20, door); hl(g, dx + 4, dTop + 28, dw - 8, tone(door, 1));
  R(g, dx + dw - 6, dTop + 26, 2, 3, C.sun);
  R(g, dx + 6, dTop + 9, 14, 7, C.paper); drawTxt(g, 'ABERTO', dx + 13, dTop + 7, 6, C.terra, 'c');
  ln(g, dx + 8, dTop + 9, dx + 13, dTop + 5, C.ink); ln(g, dx + 18, dTop + 9, dx + 13, dTop + 5, C.ink);
  vl(g, dx + dw / 2, dTop - 7, 3, C.ink); R(g, dx + dw / 2 - 2, dTop - 4, 5, 3, C.sun); P(g, dx + dw / 2, dTop - 1, C.mustard);
  if (gift(S, 'desenho')) GIFT_DRAW.desenho(g, dx + dw / 2, 1);
  const wx = 52, wy = 10, ww = 58, wh = 44;
  windowView(g, wx, wy, ww, wh, light, S);
  const nm = (S.cafeName || 'Café Girassol').toUpperCase();
  const tc = txt(nm, 6, C.sun, true);
  if (tc.width <= ww - 6) { g.save(); g.translate(wx + ww / 2 + Math.floor(tc.width / 2), wy + 19); g.scale(-1, 1); g.drawImage(tc, 0, 0); g.restore(); }
  R(g, wx - 3, wy - 3, ww + 6, 3, trim); R(g, wx - 3, wy + wh, ww + 6, 3, tone(trim, -1)); R(g, wx - 3, wy, 3, wh, trim); R(g, wx + ww, wy, 3, wh, trim);
  R(g, wx + ww / 2 - 1, wy, 2, wh, trim); R(g, wx, wy + 16, ww, 2, trim); hl(g, wx - 3, wy - 3, ww + 6, tone(trim, 1));
  ln(g, wx + 4, wy + 14, wx + 12, wy + 4, C.paper); ln(g, wx + 34, wy + 40, wx + 44, wy + 22, C.paper);
  R(g, wx - 5, wy + wh + 2, ww + 10, 3, C.wood3); hl(g, wx - 5, wy + wh + 2, ww + 10, C.tan);
  if (gift(S, 'cortina')) GIFT_DRAW.cortina(g, wx - 2, wy - 2, ww + 4, wh + 2);
  if (D.plants && D.plants !== 'nenhuma') drawPlant(g, wx + 7, wy + wh + 2, D.plants, 0);
  if (gift(S, 'vaso')) GIFT_DRAW.vaso(g, wx + ww - 8, wy + wh + 2);
  if (gift(S, 'orquidea')) drawPlant(g, wx + ww / 2 + 8, wy + wh + 2, 'orquidea', 0);
  if (S.gifts.fotovo) GIFT_DRAW.fotovo(g, 119, 24);
}

/* ======================= PISO ======================= */
const LAMPS = [[2.6, 2.5, 52], [5.6, 2.5, 52], [2.6, 6.3, 50], [6.4, 6.4, 50]];
function floorColor(kind, x, y, light) {
  let c;
  if (kind === 'xadrez') c = ((Math.floor(x * 2) + Math.floor(y * 2)) & 1) ? C.navy : C.offwhite;
  else if (kind === 'ladrilho') {
    const u = ((x * 16) % 16 + 16) % 16, v = ((y * 16) % 16 + 16) % 16, du = Math.abs(u - 8), dv = Math.abs(v - 8), r2 = du * du + dv * dv;
    c = C.cream; if (u < 1 || v < 1) c = C.tan; else if (r2 < 5) c = C.terra; else if (r2 < 13 && (du < 1.5 || dv < 1.5)) c = C.teal; else if (r2 > 40 && du > 5 && dv > 5) c = C.mustard; else if (Math.abs(du - dv) < .8 && r2 < 30) c = C.terra;
  } else if (kind === 'cimento') { const u = x * 16, v = y * 16; c = (u % 32 < .9 || v % 32 < .9) ? C.mauve : (((u * 7 + v * 13) | 0) % 17 === 0 ? C.offwhite : C.rosegrey); }
  else {
    const v = y * 16, row = Math.floor(v / 4), off = (row * 9) % 24, u = x * 16 + off, seg = Math.floor(u / 24);
    c = (v % 4 < 1 || u % 24 < 1) ? C.wood1 : ((row + seg) % 3 === 0 ? C.wood3 : C.wood2);
    if (c === C.wood2 && ((u * 5 + v * 3) | 0) % 19 === 0) c = C.wood3;
  }
  if (!light.startsWith('noite') && x < 3.4 && y > 1.3 + x * .35 && y < 4.4 + x * .35 && x > .6) { const k = (y - x * .35); if (!(k > 2.75 && k < 2.95)) c = tone(c, 1); }
  if (x > .15 && x < 1.75 && y > 5.2 && y < 7.1) { const bx = Math.min(x - .15, 1.75 - x), by = Math.min(y - 5.2, 7.1 - y); c = (bx < .12 || by < .12) ? C.wine : ((Math.floor(x * 8) + Math.floor(y * 8)) % 4 === 0 ? C.sun : C.terra); }
  if (light.startsWith('noite')) for (const L of LAMPS) { const dx = x - L[0], dy = y - L[1]; if (dx * dx + dy * dy < .9) c = tone(c, 1); }
  return c;
}

/* ======================= SALÃO ======================= */
const _bake = { key: '', bg: {}, spr: null };
function interiorKey(S) { return JSON.stringify([S.decor, S.gifts, S.flags.rafaPlaza, S.weather, S._menuPreview, S.cafeName, S._kitCounter]); }
function bakeRoomBg(S, light) {
  const g = mk(W, H), o = ROOM.o, { RX, RY, WH } = ROOM;
  R(g, 0, 0, W, H, C.sage);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (((x + 2 * y) % 32 === 0 || (x - 2 * y + 640) % 32 === 0) && (x + y) % 2 === 0) P(g, x, y, C.teal);
  const pL = isoXY(o, 0, RY, 0), pB = isoXY(o, RX, RY, 0), pR = isoXY(o, RX, 0, 0);
  texPara(g, pL, [pB[0] - pL[0], pB[1] - pL[1]], [0, 9], (s, t) => t < .12 ? C.wood2 : C.wood1);
  texPara(g, pB, [pR[0] - pB[0], pR[1] - pB[1]], [0, 9], (s, t) => t < .12 ? C.wood1 : C.wood0);
  const kind = S.decor.interior.floor || 'xadrez';
  texPara(g, isoXY(o, 0, 0, 0), [RX * 16, RX * 8], [-RY * 16, RY * 8], (s, t) => floorColor(kind, s * RX, t * RY, light));
  for (let x = 0; x < RX * 16; x += 2) P(g, o.x + x, o.y + Math.floor(x / 2) + 1, C.ink);
  for (let x = 0; x < RY * 16; x += 2) P(g, o.x - x - 1, o.y + Math.floor(x / 2) + 1, C.ink);
  const rt = wallTex(S, 'right', light), lt = wallTex(S, 'left', light);
  for (let u = 0; u < rt.width; u++) g.drawImage(rt, u, 0, 1, rt.height, o.x + u, o.y + Math.floor(u / 2) - WH, 1, rt.height);
  for (let u = 0; u < lt.width; u++) g.drawImage(lt, u, 0, 1, lt.height, o.x - RY * 16 + u, o.y + Math.floor((RY * 16 - u) / 2) - WH, 1, lt.height);
  const t1 = isoXY(o, 0, 0, WH);
  texPara(g, [t1[0], t1[1] - 3], [RX * 16, RX * 8], [0, 3], () => C.cream);
  texPara(g, [t1[0] - RY * 16, t1[1] + RY * 8 - 3], [RY * 16, -RY * 8], [0, 3], () => C.cream);
  R(g, pR[0], pR[1] - WH - 3, 3, WH + 3, C.tan); vl(g, pR[0] + 2, pR[1] - WH - 1, WH + 1, C.wood3);
  R(g, pL[0] - 3, pL[1] - WH - 3, 3, WH + 3, C.tan); vl(g, pL[0] - 3, pL[1] - WH - 1, WH + 1, C.cream);
  isoBox(g, o, 0, 1.5, 0, .55, 3.0, 9, { top: C.terra, left: C.wood2, right: C.wood1, edge: C.ink });
  isoBox(g, o, .05, 1.6, 9, .45, 2.8, 2, { top: C.orange, left: C.terra, right: C.wine });
  quantize(g);
  return g.canvas;
}
function bakeRoomSprites(S) {
  const o = ROOM.o, out = [];
  const D = S.decor.interior, cc = COUNTER_C[D.counter] || COUNTER_C.madeira;
  {
    const g = mk(W, H);
    const panel = (s, t, u, v) => { if (D.counter === 'azulejo') return ((Math.floor(u / 5) + Math.floor(v / 5)) % 2) ? C.offwhite : C.skylight; const m = u % 22; if (m < 1) return cc[3]; if (m === 1 || v < 2) return cc[1]; return v > 16 ? cc[3] : cc[2]; };
    isoBox(g, o, 1.25, 2.05, 0, 6.3, .8, 19, { left: panel, right: cc[3], top: cc[2], edge: C.ink });
    isoBox(g, o, 1.1, 1.95, 19, 6.6, 1.0, 3, { top: (s, t, u, v) => (D.counter === 'marmore' && ((u * 3 + v * 7) | 0) % 23 === 0) ? cc[2] : (t > .85 ? cc[1] : cc[0]), left: cc[1], right: cc[2], edge: C.ink, hi: tone(cc[0], 1) });
    const gx = 5.0, gy = 2.1;
    isoBox(g, o, gx, gy, 22, 1.3, .75, 2, { top: C.offwhite, left: C.rosegrey, right: C.mauve });
    for (const [k, dx] of [['paodequeijo', .25], ['bolo', .65], ['broa', 1.05]]) { const p = isoR(o, gx + dx, gy + .4, 26); drawFood(g, p[0], p[1] + 2, k); }
    const A = isoR(o, gx, gy + .75, 24), B = isoR(o, gx + 1.3, gy + .75, 24), Cc = isoR(o, gx + 1.3, gy, 24), Dd = isoR(o, gx, gy, 24);
    for (const [p, q] of [[A, B], [B, Cc], [Dd, A], [Dd, Cc]]) ln(g, p[0], p[1] - 12, q[0], q[1] - 12, C.paper);
    for (const p of [A, B, Cc]) vl(g, p[0], p[1] - 12, 12, C.skylight);
    ln(g, A[0] + 3, A[1] - 3, A[0] + 9, A[1] - 9, C.paper);
    { const p = isoR(o, 6.95, 2.45, 22); R(g, p[0] - 6, p[1] - 9, 12, 9, C.petrol); R(g, p[0] - 6, p[1] - 9, 12, 2, C.sage); R(g, p[0] - 4, p[1] - 14, 8, 5, C.navy); R(g, p[0] - 3, p[1] - 13, 6, 3, C.teal); for (let i = 0; i < 3; i++) P(g, p[0] - 4 + i * 3, p[1] - 5, [C.terra, C.sun, C.mint][i]); }
    { const p = isoR(o, 3.15, 2.35, 22); R(g, p[0] - 3, p[1] - 6, 6, 6, C.offwhite); R(g, p[0] - 3, p[1] - 7, 6, 1, C.rosegrey); P(g, p[0], p[1] - 8, C.rosegrey); }
    { const p = isoR(o, 4.25, 2.3, 22); for (let i = 0; i < 3; i++) { R(g, p[0] - 4, p[1] - 3 - i * 3, 8, 3, C.paper); hl(g, p[0] - 4, p[1] - 3 - i * 3, 8, C.offwhite); P(g, p[0] + 3, p[1] - 2 - i * 3, C.rosegrey); } }
    { const p = isoR(o, 2.0, 2.4, 22); const k = mk(40, 40); drawKitIcon(k, 20, 38, S._kitCounter || 'coador'); g.drawImage(k.canvas, p[0] - 20, p[1] - 38); }
    if (gift(S, 'vaso')) { const p = isoR(o, 7.45, 2.3, 22); GIFT_DRAW.vaso(g, p[0], p[1]); }
    quantize(g);
    out.push({ c: g.canvas, y: 2.9, x: 4 });
  }
  const tables = [[2.6, 6.3], [6.4, 6.4], [9.3, 4.4]];
  tables.forEach((T, i) => {
    const [tx, ty] = T;
    const iron = D.tables === 'ferro';
    const topC = iron ? C.offwhite : C.wood3, topS = iron ? C.rosegrey : C.wood2, legC = iron ? C.plum : C.wood1;
    const chair = (cx, cy, backSide) => {
      const g = mk(W, H);
      const w = .5, d = .5, x = cx - w / 2, y = cy - d / 2;
      for (const [lx, ly] of [[x + .05, y + d - .05], [x + w - .05, y + d - .05], [x + w - .05, y + .05], [x + .05, y + .05]]) { const p = isoR(o, lx, ly, 0); vl(g, p[0], p[1] - 9, 9, legC); }
      isoBox(g, o, x, y, 9, w, d, 2, { top: topC, left: topS, right: legC, edge: C.ink });
      if (backSide === 'back') isoBox(g, o, x, y, 11, w, .08, 11, { top: topC, left: topS, right: legC, edge: C.ink });
      if (backSide === 'right') isoBox(g, o, x + w - .08, y, 11, .08, d, 11, { top: topC, left: topS, right: legC, edge: C.ink });
      quantize(g);
      return g.canvas;
    };
    out.push({ c: chair(tx, ty - .95, 'back'), y: ty - .95, x: tx, seat: { table: i, slot: 0, x: tx, y: ty - .95, facing: 'front' } });
    out.push({ c: chair(tx + .95, ty + .05, 'right'), y: ty + .05, x: tx + .95, seat: { table: i, slot: 1, x: tx + .95, y: ty + .05, facing: 'back' } });
    const g = mk(W, H), p = isoR(o, tx, ty, 0);
    isoShadow(g, p[0], p[1], 12);
    vl(g, p[0], p[1] - 16, 16, legC); vl(g, p[0] + 1, p[1] - 16, 16, tone(legC, -1)); ell(g, p[0], p[1], 6, 3, legC);
    ell(g, p[0], p[1] - 17, 16, 8, C.ink); ell(g, p[0], p[1] - 18, 15, 7.5, topS); ell(g, p[0], p[1] - 19, 15, 7.5, topC); ell(g, p[0] - 4, p[1] - 21, 6, 2, tone(topC, 1));
    if (S.gifts.toalha) { ell(g, p[0], p[1] - 19, 10, 5, C.paper); for (let k = -9; k <= 9; k += 3) P(g, p[0] + k, p[1] - 15 + Math.round(Math.abs(k) / 4), C.paper); }
    R(g, p[0] - 1, p[1] - 23, 2, 4, C.mint); P(g, p[0] - 1, p[1] - 25, C.rose); P(g, p[0], p[1] - 26, C.rose);
    quantize(g);
    out.push({ c: g.canvas, y: ty + .01, x: tx, table: i });
  });
  for (const [px, py, k] of [[.55, .55, D.plants2 || 'costela'], [10.3, 7.2, 'samambaia'], [.6, 4.75, D.plants2 === 'girassol' ? 'girassol' : 'costela']]) {
    const g = mk(W, H), p = isoR(o, px, py, 0);
    isoShadow(g, p[0], p[1], 8);
    bigPlant(g, p[0], p[1], k);
    quantize(g);
    out.push({ c: g.canvas, y: py, x: px });
  }
  return out;
}
function bigPlant(g, x, y, kind) {
  poly(g, [[x - 7, y - 12], [x + 7, y - 12], [x + 5, y], [x - 5, y]], C.terra);
  R(g, x - 8, y - 14, 16, 3, C.orange); hl(g, x - 8, y - 14, 16, C.peach); vl(g, x + 4, y - 11, 10, C.wine); vl(g, x - 5, y - 11, 9, C.orange);
  ell(g, x, y - 14, 6, 1.5, C.wood0);
  if (kind === 'girassol') { for (let i = 0; i < 3; i++) { const fx = x - 6 + i * 6, fy = y - 34 + (i === 1 ? -6 : 0); ln(g, x, y - 14, fx, fy, C.green1); ell(g, fx - 3, (y - 14 + fy) / 2, 3, 1.5, C.leaf); flower(g, fx, fy, 1); } return; }
  if (kind === 'samambaia') { for (let i = 0; i < 9; i++) { const a = -Math.PI + i * Math.PI / 8; const ex = x + Math.cos(a) * 16, ey = y - 18 + Math.sin(a) * 10 + 8; ln(g, x, y - 16, ex, ey, i % 2 ? C.leaf : C.green1); P(g, ex, ey + 1, C.lime); } ell(g, x, y - 20, 9, 5, C.leaf); for (let i = 0; i < 6; i++) P(g, x - 6 + i * 2, y - 22 + (i % 2), C.lime); return; }
  for (const [dx, dy] of [[-9, -30], [6, -36], [-2, -42], [10, -24], [-12, -20]]) { ln(g, x, y - 14, x + dx, y + dy + 4, C.green1); ell(g, x + dx, y + dy, 6, 4, C.green1); ell(g, x + dx - 1, y + dy - 1, 5, 3, C.leaf); P(g, x + dx - 2, y + dy - 2, C.lime); hl(g, x + dx + 1, y + dy, 3, C.green1); P(g, x + dx + 4, y + dy + 1, C.sage); }
}
function roomBg(S, light) {
  const k = interiorKey(S);
  if (_bake.key !== k) { _bake.key = k; _bake.bg = {}; _bake.spr = bakeRoomSprites(S); }
  if (!_bake.bg[light]) { const base = bakeRoomBg(S, light); _bake.bg[light] = light === 'dia' ? base : lit(base, light, [C.butter]); }
  return _bake.bg[light];
}
function drawLamps(g, S, light, time) {
  const o = ROOM.o, kind = S.decor.interior.lamps || 'pendente';
  const on = light === 'tarde' || light.startsWith('noite');
  if (kind === 'pisca') {
    const a = isoXY(o, 0, 0, ROOM.WH - 6);
    for (let u = 0; u < ROOM.RX * 16; u++) { const y = a[1] + u / 2 + Math.round(Math.sin(u / 22 * Math.PI) * 4) + 4; P(g, a[0] + u, y, C.plum); if (u % 9 === 4) R(g, a[0] + u, y + 1, 2, 2, [C.sun, C.orange, C.mint, C.rose][(Math.floor(u / 9) + Math.floor(time * 2)) % 4]); }
    for (let u = 0; u < ROOM.RY * 16; u++) { const y = a[1] + u / 2 + Math.round(Math.sin(u / 22 * Math.PI) * 4) + 4; P(g, a[0] - u, y, C.plum); if (u % 9 === 4) R(g, a[0] - u, y + 1, 2, 2, [C.sun, C.orange, C.mint, C.rose][(Math.floor(u / 9) + Math.floor(time * 2) + 1) % 4]); }
    return;
  }
  const L = c => litColor(c, light === 'dia' ? null : light);
  for (const [lx, ly, lz] of LAMPS) {
    const p = isoR(o, lx, ly, lz);
    const top = isoR(o, lx, ly, ROOM.WH + 34)[1]; vl(g, p[0], top, p[1] - 6 - top, L(C.plum)); R(g, p[0] - 2, top, 5, 1, L(C.plum));
    if (kind === 'lustre') { R(g, p[0] - 7, p[1] - 6, 14, 2, L(C.mustard)); for (let k = -2; k <= 2; k++) { vl(g, p[0] + k * 3, p[1] - 4, 3, L(C.mustard)); P(g, p[0] + k * 3, p[1] - 1, on ? C.butter : C.cream); } }
    else { poly(g, [[p[0] - 7, p[1]], [p[0] - 3, p[1] - 7], [p[0] + 3, p[1] - 7], [p[0] + 7, p[1]]], L(C.green1)); hl(g, p[0] - 7, p[1], 14, L(C.green0)); hl(g, p[0] - 3, p[1] - 7, 6, L(C.leaf)); ln(g, p[0] - 5, p[1] - 2, p[0] - 2, p[1] - 6, L(C.leaf)); R(g, p[0] - 2, p[1] + 1, 4, 2, on ? C.butter : C.cream); }
    if (on) { g.fillStyle = C.butter; for (let a = 0; a < 16; a++) { const an = a / 16 * Math.PI * 2, r = 9 + (Math.floor(time * 3 + a) % 2); g.fillRect(Math.round(p[0] + Math.cos(an) * r), Math.round(p[1] + 3 + Math.sin(an) * r * .5), 1, 1); } }
  }
}
function drawCatIso(g, x, y, time) {
  const c = C.orange, d = C.terra, br = Math.round((Math.sin(time * 1.5) + 1) / 2);
  ell(g, x, y - 3 - br, 7, 3 + br, c); ell(g, x + 6, y - 5, 3.5, 3, c); P(g, x + 4, y - 9, c); P(g, x + 8, y - 9, c); P(g, x + 4, y - 8, d); P(g, x + 8, y - 8, d);
  P(g, x + 5, y - 5, C.ink); P(g, x + 7, y - 5, C.ink); for (let i = -5; i < 3; i += 3) vl(g, x + i, y - 6, 2, d); P(g, x + 6, y - 3, C.paper);
  ln(g, x - 7, y - 2, x - 10, y - 1, c); ln(g, x - 10, y - 1, x - 9, y - 4, c);
  if (Math.floor(time / 2) % 3 === 0) drawTxt(g, 'z', x + 10, y - 18 - Math.floor(time * 2) % 3, 6, C.paper);
}
function drawRoom(g, S, t, time, actors) {
  const light = lightOf(t, true), Lk = light === 'dia' ? null : light;
  g.drawImage(roomBg(S, light), 0, 0);
  const o = ROOM.o, list = [];
  for (const sp of _bake.spr) list.push({ y: sp.y, x: sp.x, draw: () => g.drawImage(lit(sp.c, Lk, [C.butter]), 0, 0) });
  for (const a of actors) {
    if (a.alpha != null && a.alpha < .5) continue;
    list.push({ y: a.y + (a.pose === 'sit' ? .03 : 0), x: a.x, draw: () => {
      const p = isoR(o, a.x, a.y, 0);
      const c = lit(drawPerson(a.spec, { facing: a.facing, pose: a.pose, frame: a.frame, apron: a.apron, blink: a.blink }), Lk, [C.butter]);
      g.drawImage(c, p[0] - 12, p[1] - 39 - (a.pose === 'sit' ? 6 : 0));
      if (a.talk) { R(g, p[0] - 1, p[1] - 52, 3, 1, C.paper); R(g, p[0] - 2, p[1] - 51, 5, 3, C.paper); P(g, p[0] - 1, p[1] - 50, C.ink); P(g, p[0] + 1, p[1] - 50, C.ink); P(g, p[0], p[1] - 48, C.paper); }
    } });
  }
  if (S.flags && S.flags.gato) list.push({ y: 3.0, x: .3, draw: () => { const p = isoR(o, .3, 3.0, 11); drawCatIso(g, p[0], p[1], time); } });
  if (S._drink) list.push({ y: 2.95, x: S._drink.x, draw: () => { const p = isoR(o, S._drink.x, 2.45, 22); drawDrink(g, p[0], p[1], S._drink.vis, time); if (S._drink.food) drawFood(g, p[0] + 12, p[1] + 1, S._drink.food); if (S._drink.cups > 1) { const q = isoR(o, S._drink.x + .7, 2.45, 22); drawDrink(g, q[0], q[1], { cup: 'xicara', steam: true }, time + 1); } } });
  list.sort((a, b) => a.y - b.y || a.x - b.x);
  for (const it of list) it.draw();
  drawLamps(g, S, light, time);
}
const ROOM_SPOTS = { door: { x: .35, y: 6.2 }, counter: { x: 3.7, y: 3.75 }, barista: { x: 4.1, y: 1.15 } };

/* ======================= FACHADA (diorama da esquina) ======================= */
const FAC = { o: { x: 216, y: 122 }, BX: 9, BY: 6, HT: 112 };
function skyBands(light, weather) {
  let b = ({ manha: [C.sky, C.skylight, C.butter, C.peach], dia: [C.sky, C.sky, C.skylight, C.mint], tarde: [C.lilac, C.rose, C.peach, C.butter], noite: [C.navy, C.navy, C.plum, C.lilac] }[light] || [C.sky, C.skylight, C.mint, C.paper]).slice();
  if (weather === 'chuva') b = light === 'noite' ? [C.navy, C.navy, C.mauve, C.mauve] : [C.rosegrey, C.rosegrey, C.offwhite, C.offwhite];
  else if (weather === 'nublado' && light !== 'noite') b = [b[0], C.skylight, C.offwhite, C.offwhite];
  return b;
}
function drawSky(g, light, weather) {
  const b = skyBands(light, weather), n = b.length, bh = 150 / n;
  for (let i = 0; i < n; i++) { const y0 = Math.round(i * bh), y1 = i === n - 1 ? H : Math.round((i + 1) * bh); R(g, 0, y0, W, y1 - y0, b[i]); if (i) { dith(g, 0, y0 - 2, W, 1, b[i], 2); dith(g, 0, y0 - 1, W, 1, b[i], 1); dith(g, 0, y0, W, 1, b[i - 1], 2); } }
  const r = rng(77);
  if (light === 'noite') { for (let i = 0; i < 70; i++) P(g, r() * W, r() * 110, r() < .3 ? C.butter : C.skylight); ell(g, 420, 34, 7, 7, C.paper); ell(g, 423, 32, 6, 6, b[0]); }
  else if (weather !== 'chuva') {
    if (light !== 'tarde') ell(g, 60, 30, 8, 8, C.butter);
    const cc = light === 'tarde' ? [C.skin0, C.peach] : [C.paper, C.skylight];
    for (let i = 0; i < 5; i++) { const cx = 30 + i * 110 + r() * 40, cy = 16 + r() * 40; ell(g, cx, cy, 22, 5, cc[1]); ell(g, cx - 8, cy - 4, 10, 5, cc[0]); ell(g, cx + 7, cy - 3, 12, 5, cc[0]); ell(g, cx + 2, cy - 7, 8, 4, cc[0]); hl(g, cx - 18, cy + 4, 36, cc[1]); }
  }
  const hill = light === 'noite' ? C.navy : light === 'tarde' ? C.mauve : C.sage;
  for (let x = 0; x < W; x++) { const y = 118 + Math.round(Math.sin(x / 50) * 8 + Math.sin(x / 17) * 3); R(g, x, y, 1, H - y, hill); }
  const far = light === 'noite' ? C.plum : light === 'tarde' ? C.rosegrey : C.teal;
  let x = 0; while (x < W) { const bw = 10 + Math.floor(r() * 18), bh = 18 + Math.floor(r() * 40); R(g, x, 150 - bh, bw, bh + 120, far); for (let wy = 152 - bh; wy < 150; wy += 5) for (let wx = x + 2; wx < x + bw - 2; wx += 4) if (r() < (light === 'noite' ? .45 : .15)) P(g, wx, wy, light === 'noite' ? C.butter : tone(far, 1)); x += bw + 2; }
}
function groundColor(x, y) {
  const { BX, BY } = FAC;
  const inL = y >= BY && y < BY + 1.8 && x < BX + 1.8, inR = x >= BX && x < BX + 1.8 && y < BY + 1.8;
  if (inL || inR) {
    const useL = inL && !(inR && y < BY + .2);
    const along = useL ? x * 16 : y * 16, across = useL ? (y - BY) * 16 : (x - BX) * 16;
    const wv = (across + Math.sin(along / 11) * 5 + 60) % 7;
    return wv < 2 ? C.mauve : (((along * 3 + across * 5) | 0) % 13 === 0 ? C.offwhite : C.paper);
  }
  const inCurbL = y >= BY + 1.8 && y < BY + 2.05 && x < BX + 2.05, inCurbR = x >= BX + 1.8 && x < BX + 2.05 && y < BY + 2.05;
  if (inCurbL || inCurbR) return (y >= BY + 1.8 && y < BY + 1.87) || (x >= BX + 1.8 && x < BX + 1.87) ? C.paper : C.rosegrey;
  let c = ((x * 16 * 7 + y * 16 * 13) | 0) % 9 === 0 ? C.plum : C.mauve;
  if (y > BY + 2 && Math.abs(y - (BY + 4.2)) < .06 && Math.floor(x * 1.5) % 2 === 0) c = C.butter;
  if (x > BX + 2 && Math.abs(x - (BX + 4.2)) < .06 && Math.floor(y * 1.5) % 2 === 0) c = C.butter;
  if (x > BX + 2.2 && x < BX + 6 && y > BY - 1.2 && y < BY + 1.6 && Math.floor(y * 3) % 2 === 0) c = C.offwhite;
  return c;
}
function facadeTex(S, side, light) {
  const F = S.decor.facade, wall = WALL_C[F.wall] || C.sun, trim = ACCENT[F.trim] || C.green1, door = ACCENT[F.door] || C.wine;
  const w = side === 'left' ? FAC.BX * 16 : FAC.BY * 16, h = FAC.HT;
  const g = mk(w, h + 1);
  const night = light === 'noite';
  const glass = night ? C.butter : C.skylight, glass2 = night ? C.sun : C.sky;
  R(g, 0, 0, w, h + 1, wall);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) if ((x * 5 + y * 3) % 11 === 0) P(g, x, y, tone(wall, 1)); else if ((x * 7 + y * 11) % 29 === 0) P(g, x, y, tone(wall, -1));
  R(g, 0, 0, w, 10, trim); hl(g, 0, 9, w, tone(trim, -1)); hl(g, 0, 0, w, tone(trim, 1));
  for (let x = 4; x < w; x += 10) R(g, x, 3, 6, 4, tone(trim, -1));
  R(g, 0, 50, w, 3, trim); hl(g, 0, 50, w, tone(trim, 1));
  const nWin = side === 'left' ? 3 : 2, step = w / nWin;
  for (let i = 0; i < nWin; i++) {
    const wx = Math.round(step * i + step / 2 - 9), wy = 16;
    R(g, wx - 5, wy - 1, 4, 24, trim); R(g, wx + 19, wy - 1, 4, 24, trim);
    for (let k = 0; k < 24; k += 3) { hl(g, wx - 5, wy - 1 + k, 4, tone(trim, -1)); hl(g, wx + 19, wy - 1 + k, 4, tone(trim, -1)); }
    R(g, wx - 1, wy - 2, 20, 26, C.paper); R(g, wx, wy, 18, 22, glass); R(g, wx, wy + 12, 18, 10, glass2); vl(g, wx + 9, wy, 22, C.paper); hl(g, wx, wy + 11, 18, C.paper);
    if (!night) ln(g, wx + 2, wy + 9, wx + 6, wy + 2, C.paper); else R(g, wx + 1, wy + 14, 6, 8, C.mustard);
    R(g, wx - 2, wy + 22, 22, 4, C.terra); hl(g, wx - 2, wy + 22, 22, C.orange); for (let k = 0; k < 6; k++) flower(g, wx + 1 + k * 3, wy + 21, 0);
  }
  if (side === 'left') {
    R(g, w / 2 - 14, 0, 28, 10, tone(trim, -1)); drawTxt(g, String(S.foundedYear || 1974), w / 2, -1, 6, C.paper, 'c', true);
    const nm = S.cafeName || 'Café Girassol', sx0 = 6, sw = 108, sy = 53;
    const sz = fitTxt(nm, sw - 10, 10), sb = sz === 8, ty = sy + (sz >= 10 ? -5 : -1);
    if (F.sign === 'neon') { R(g, sx0, sy, sw, 14, C.ink); const on = night || light === 'tarde'; drawTxt(g, nm, sx0 + sw / 2, ty, sz, on ? C.rose : C.mauve, 'c', sb, on ? C.wine : null); }
    else if (F.sign === 'pintado') drawTxt(g, nm, sx0 + sw / 2, ty, sz, tone(trim, -1), 'c', sb, tone(wall, -1));
    else { R(g, sx0, sy, sw, 14, C.wood1); R(g, sx0 + 1, sy + 1, sw - 2, 12, C.wood2); for (let x = sx0 + 4; x < sx0 + sw - 4; x += 9) hl(g, x, sy + 4 + (x % 3), 5, C.wood1); drawTxt(g, nm, sx0 + sw / 2, ty, sz, C.sun, 'c', sb, C.wood0); }
    const vx = 8, vy = 74, vw = 68, vh = 28;
    R(g, vx - 3, vy - 3, vw + 6, vh + 6, trim); R(g, vx, vy, vw, vh, night ? C.butter : C.tan);
    R(g, vx, vy + 18, vw, 10, C.wood2); hl(g, vx, vy + 18, vw, C.wood3);
    for (let i = 0; i < 3; i++) { vl(g, vx + 12 + i * 22, vy, 4, C.plum); R(g, vx + 9 + i * 22, vy + 4, 7, 3, C.green1); P(g, vx + 12 + i * 22, vy + 7, C.butter); }
    if (!S._closed) { R(g, vx + 26, vy + 8, 6, 10, C.terra); R(g, vx + 27, vy + 4, 4, 4, C.skin1); R(g, vx + 46, vy + 10, 6, 8, C.petrol); R(g, vx + 47, vy + 6, 4, 4, C.skin2); }
    if (!night) { ln(g, vx + 4, vy + 24, vx + 18, vy + 4, C.paper); ln(g, vx + 10, vy + 26, vx + 24, vy + 6, C.cream); }
    vl(g, vx + vw / 2, vy, vh, trim); R(g, vx - 4, vy + vh + 3, vw + 8, 3, C.wood2);
    const dx = 86, dw = 24, dy = 66;
    R(g, dx - 3, dy - 3, dw + 6, h - dy + 4, trim); R(g, dx, dy, dw, h - dy + 1, door);
    R(g, dx + 3, dy + 3, dw - 6, 18, night ? C.butter : C.tan); vl(g, dx + dw / 2, dy + 3, 18, door);
    R(g, dx + 4, dy + 25, dw - 8, 16, tone(door, -1)); R(g, dx + 5, dy + 26, dw - 10, 14, door); hl(g, dx + 5, dy + 26, dw - 10, tone(door, 1));
    R(g, dx + dw - 6, dy + 22, 2, 3, C.sun);
    R(g, dx + 1, dy + 8, 22, 9, C.paper); drawTxt(g, S._closed ? 'FECHADO' : 'ABERTO', dx + dw / 2, dy + 7, 6, S._closed ? C.petrol : C.terra, 'c');
    R(g, 118, 76, 20, 22, trim); R(g, 120, 78, 16, 18, glass); R(g, 120, 88, 16, 8, glass2); vl(g, 128, 78, 18, trim);
    R(g, 116, 96, 24, 3, C.terra); for (let k = 0; k < 7; k++) flower(g, 118 + k * 3, 95, 0);
  } else {
    if (F.mural) {
      R(g, 6, 58, w - 12, 44, tone(wall, 1));
      for (let i = 0; i < 5; i++) { const fx = 14 + i * 17, fy = 70 + (i % 2) * 8; ln(g, fx, fy + 6, fx + (i % 2 ? 2 : -2), 102, C.green1); ell(g, fx - 4, fy + 14, 4, 2, C.leaf); for (let a = 0; a < 12; a++) { const an = a / 12 * Math.PI * 2; ell(g, fx + Math.cos(an) * 5, fy + Math.sin(an) * 5, 2, 2, a % 2 ? C.sun : C.butter); } ell(g, fx, fy, 3.5, 3.5, C.wood1); dith(g, fx - 3, fy - 3, 6, 6, C.wood0, 1); }
    } else {
      R(g, 30, 72, 34, 24, trim); R(g, 32, 74, 30, 20, glass); R(g, 32, 84, 30, 10, glass2); vl(g, 47, 74, 20, trim); R(g, 28, 94, 38, 3, C.wood2);
      drawTxt(g, 'cafés', 47, 54, 6, tone(trim, -1), 'c', true); drawTxt(g, 'quitandas', 47, 62, 6, tone(trim, -1), 'c');
    }
    vl(g, w - 4, 10, h - 10, C.rosegrey); vl(g, w - 3, 10, h - 10, C.offwhite); for (let y = 20; y < h; y += 18) R(g, w - 5, y, 4, 2, C.mauve);
  }
  for (let x = 0; x < w; x++) for (let y = h - 6; y <= h; y++) P(g, x, y, ((Math.floor(x / 7) + Math.floor(y / 3)) % 2) ? C.rosegrey : C.offwhite);
  return g.canvas;
}
function neighborTex(kind, w, h, light) {
  const g = mk(w, h + 1), night = light === 'noite';
  const wall = kind === 'cris' ? C.rose : C.skylight, trim = kind === 'cris' ? C.wine : C.petrol;
  R(g, 0, 0, w, h + 1, wall);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) if ((x * 5 + y * 3) % 13 === 0) P(g, x, y, tone(wall, 1));
  R(g, 0, 0, w, 6, trim);
  if (kind === 'cris') {
    R(g, 8, 12, w - 16, 12, C.paper); drawTxt(g, 'Flores da Cris', w / 2, 12, 6, C.wine, 'c', true);
    R(g, 10, 34, w - 20, h - 40, trim); R(g, 12, 36, w - 24, h - 44, night ? C.butter : C.mint); R(g, 12, h - 18, w - 24, 10, C.wood2);
    for (let i = 0; i < 7; i++) { const fx = 18 + i * 10; vl(g, fx, h - 24, 6, C.green1); flower(g, fx, h - 25, 0); }
    poly(g, [[6, 28], [w - 6, 28], [w - 10, 34], [10, 34]], C.leaf); for (let x = 8; x < w - 8; x += 6) poly(g, [[x, 34], [x + 6, 34], [x + 3, 37]], C.green1);
  } else {
    R(g, 6, 12, 18, 20, C.paper); R(g, 7, 13, 16, 18, night ? C.butter : C.sky); R(g, w - 24, 12, 18, 20, C.paper); R(g, w - 23, 13, 16, 18, night ? C.mustard : C.sky);
    R(g, 4, 38, w - 8, 10, C.wood1); drawTxt(g, 'Sapataria', w / 2, 37, 6, C.cream, 'c', true);
    R(g, 8, 50, w - 16, h - 56, trim); R(g, 10, 52, w - 20, h - 60, night ? C.sun : C.skylight); R(g, 12, h - 14, 10, 6, C.wood1); R(g, 26, h - 12, 8, 4, C.terra);
  }
  for (let x = 0; x < w; x++) for (let y = h - 5; y <= h; y++) P(g, x, y, ((Math.floor(x / 7) + Math.floor(y / 3)) % 2) ? C.rosegrey : C.offwhite);
  return g.canvas;
}
function blitWall(g, tex, x0, y0, dir) {
  const th = tex.height;
  for (let u = 0; u < tex.width; u++) g.drawImage(tex, u, 0, 1, th, x0 + u, y0 + (dir > 0 ? Math.floor(u / 2) : -Math.floor((u + 1) / 2)), 1, th);
}
const _fbake = { key: '', bg: {} };
function facadeKey(S) { return JSON.stringify([S.decor.facade, S.cafeName, S._closed, S.weather, S.foundedYear]); }
function bakeFacade(S, light) {
  const g = mk(W, H), o = FAC.o, { BX, BY, HT } = FAC;
  const gx0 = -6, gy0 = -7, gx1 = BX + 3.4, gy1 = BY + 3.4;
  const pL = isoXY(o, gx0, gy1, 0), pB = isoXY(o, gx1, gy1, 0), pR = isoXY(o, gx1, gy0, 0);
  const scene = mk(W, H);
  texPara(scene, isoXY(o, gx0, gy0, 0), [(gx1 - gx0) * 16, (gx1 - gx0) * 8], [-(gy1 - gy0) * 16, (gy1 - gy0) * 8], (s, t) => groundColor(gx0 + s * (gx1 - gx0), gy0 + t * (gy1 - gy0)));
  texPara(scene, pL, [pB[0] - pL[0], pB[1] - pL[1]], [0, 10], (s, t, u, v) => t < .15 ? C.leaf : ((u * 3 + v * 7 | 0) % 7 === 0 ? C.wood2 : C.wood1));
  texPara(scene, pB, [pR[0] - pB[0], pR[1] - pB[1]], [0, 10], (s, t, u, v) => t < .15 ? C.green1 : ((u * 3 + v * 7 | 0) % 7 === 0 ? C.wood1 : C.wood0));
  // floricultura da Cris (atrás, à direita)
  const ch = 58;
  texPara(scene, isoXY(o, 2, -6, ch), [(BX - 2) * 16, (BX - 2) * 8], [-6 * 16, 6 * 8], (s, t, u, v) => (u % 10 < 1 || v % 10 < 1) ? C.mauve : (((u + v) | 0) % 7 === 0 ? C.offwhite : C.rosegrey));
  isoBox(scene, o, 2, -.3, ch, BX - 2, .3, 4, { top: C.rose, left: C.wine, right: C.wine });
  isoBox(scene, o, 3.5, -4.2, ch, 1.4, 1.2, 10, { top: C.skylight, left: C.sky, right: C.petrol, edge: C.ink });
  const nr = neighborTex('cris', 6 * 16, ch, light), nrp = isoXY(o, BX, 0, ch); blitWall(scene, nr, nrp[0], nrp[1], -1);
  // sapataria (à esquerda)
  const nh = 70, nl = neighborTex('sapataria', 5 * 16, nh, light), nlp = isoXY(o, -5, BY, nh);
  texPara(scene, isoXY(o, -5, 1, nh), [5 * 16, 5 * 8], [-(BY - 1) * 16, (BY - 1) * 8], (s, t, u, v) => (v % 6 < 1) ? C.wine : (u % 12 < 1 ? C.terra : C.orange));
  isoBox(scene, o, -5, BY - .3, nh, 5, .3, 4, { top: C.skylight, left: C.petrol, right: C.petrol });
  blitWall(scene, nl, nlp[0], nlp[1], 1);
  // prédio do café
  const lt = facadeTex(S, 'left', light), rt = facadeTex(S, 'right', light);
  const lp = isoXY(o, 0, BY, HT); blitWall(scene, lt, lp[0], lp[1], 1);
  const rp = isoXY(o, BX, BY, HT); blitWall(scene, rt, rp[0], rp[1], -1);
  texPara(scene, isoXY(o, 0, 0, HT), [BX * 16, BX * 8], [-BY * 16, BY * 8], (s, t, u, v) => ((u * 3 + v * 5) | 0) % 11 === 0 ? C.rosegrey : C.mauve);
  const trim = ACCENT[S.decor.facade.trim] || C.green1;
  isoBox(scene, o, 0, 0, HT, BX, .25, 6, { top: tone(trim, 1), left: trim, right: tone(trim, -1) });
  isoBox(scene, o, 0, 0, HT, .25, BY, 6, { top: tone(trim, 1), left: trim, right: tone(trim, -1) });
  isoBox(scene, o, 1.0, .8, HT, 1.6, 1.4, 16, { top: C.sky, left: C.petrol, right: C.navy, edge: C.ink });
  isoBox(scene, o, 1.2, 1.0, HT + 16, 1.2, 1.0, 2, { top: C.skylight, left: C.sky, right: C.petrol });
  for (const [px, py] of [[4.5, 1.6], [6.2, 2.0], [7.6, 3.6]]) { const p = isoR(o, px, py, HT); bigPlant(scene, p[0], p[1], px > 7 ? 'samambaia' : 'costela'); }
  isoBox(scene, o, 0, BY - .25, HT, BX, .25, 6, { top: tone(trim, 1), left: trim, right: tone(trim, -1) });
  isoBox(scene, o, BX - .25, 0, HT, .25, BY, 6, { top: tone(trim, 1), left: trim, right: tone(trim, -1) });
  // toldo
  const F = S.decor.facade, ac = ACCENT[F.awningColor] || C.wine, aw = F.awning || 'listras';
  const a0 = .35, a1 = 7.1, az = 42, ad = 1.05, adz = 11;
  const A = isoXY(o, a0, BY, az), Bp = isoXY(o, a1, BY, az), Cp = isoXY(o, a0, BY + ad, az - adz);
  texPara(scene, A, [Bp[0] - A[0], Bp[1] - A[1]], [Cp[0] - A[0], Cp[1] - A[1]], (s, t, u) => {
    let c = aw === 'listras' ? (Math.floor(u / 8) % 2 ? ac : C.paper) : aw === 'ondas' ? ((Math.floor(u / 4) + Math.floor(t * 6)) % 2 ? ac : tone(ac, 1)) : ac;
    if (t < .12) c = tone(c, 1);
    if (t > .8) { const m = u % 8; if (t > .8 + (Math.abs(m - 4) / 4) * .2) return null; c = tone(c, -1); }
    return c;
  });
  const corner = isoR(o, BX, BY, 0); vl(scene, corner[0], corner[1] - HT, HT, tone(WALL_C[F.wall] || C.sun, 1));
  for (let i = 0; i < 4; i++) isoBox(scene, o, .7 + i * 1.6, BY + .12, 0, 1.1, .45, 6, { top: C.wood0, left: C.terra, right: C.wine, edge: C.ink });
  isoBox(scene, o, -4.6, BY + .35, 0, 1.4, .9, 24, { top: C.green1, left: (s, t, u, v) => v > 6 && v < 18 && u > 2 && u < 20 ? [C.terra, C.sun, C.sky, C.rose, C.lime][Math.floor(u / 4) % 5] : C.green1, right: C.green0, edge: C.ink });
  isoBox(scene, o, -4.75, BY + .25, 24, 1.7, 1.1, 3, { top: C.terra, left: C.wine, right: C.wine });
  { const p = isoR(o, -3.9, BY + 1.2, 28); drawTxt(scene, 'BANCA', p[0] - 4, p[1] - 4, 6, C.paper, 'c'); }
  quantize(scene);
  drawSky(g, light, S.weather);
  g.drawImage(light === 'dia' ? scene.canvas : lit(scene.canvas, light, [C.butter]), 0, 0);
  quantize(g);
  return g.canvas;
}
function facadeBg(S, light) {
  const k = facadeKey(S);
  if (_fbake.key !== k) { _fbake.key = k; _fbake.bg = {}; }
  if (!_fbake.bg[light]) _fbake.bg[light] = bakeFacade(S, light);
  return _fbake.bg[light];
}
function drawStreet(g, S, t, time, walkers) {
  const light = lightOf(t, false), Lk = light === 'dia' ? null : light, o = FAC.o, { BX, BY, HT } = FAC;
  g.drawImage(facadeBg(S, light), 0, 0);
  const on = light === 'noite' || light === 'tarde';
  const L = c => litColor(c, Lk);
  const list = [];
  (S.garden || []).forEach((b, i) => { if (!b) return; list.push({ k: BY + .4 + 1.25 + i * 1.6, draw: () => { const p = isoR(o, 1.25 + i * 1.6, BY + .35, 6); const c = mk(40, 50); drawSunflowerStage(c, 20, 46, b.stage, Math.round(Math.sin(time * 1.2 + i))); g.drawImage(lit(quantize(c), Lk, [C.butter]), p[0] - 20, p[1] - 46); } }); });
  const season = S.season, ipe = season === 'inverno' || season === 'primavera';
  const leaf = ipe ? (season === 'inverno' ? C.sun : C.rose) : season === 'outono' ? C.orange : C.leaf;
  list.push({ k: BY + 1.45 - 1.6, draw: () => { const p = isoR(o, -1.6, BY + 1.45, 0); isoShadow(g, p[0], p[1], 14); R(g, p[0] - 2, p[1] - 40, 5, 40, L(C.wood1)); vl(g, p[0] + 2, p[1] - 40, 40, L(C.wood0)); ln(g, p[0], p[1] - 30, p[0] - 10, p[1] - 44, L(C.wood1)); for (let i = 0; i < 10; i++) { const a = i / 10 * Math.PI * 2; ell(g, p[0] + Math.cos(a) * 16, p[1] - 52 + Math.sin(a) * 9, 10, 8, L(i % 3 ? leaf : tone(leaf, -1))); } ell(g, p[0] - 3, p[1] - 56, 14, 9, L(tone(leaf, 1))); } });
  list.push({ k: BX + BY + 3.2, draw: () => { const p = isoR(o, BX + 1.6, BY + 1.6, 0); R(g, p[0] - 1, p[1] - 70, 3, 70, L(C.navy)); R(g, p[0] - 1, p[1] - 70, 12, 2, L(C.navy)); R(g, p[0] + 7, p[1] - 68, 6, 3, on ? C.butter : L(C.offwhite)); if (on) { g.fillStyle = C.butter; for (let a = 0; a < 20; a++) { const an = a / 20 * Math.PI * 2; g.fillRect(Math.round(p[0] + 10 + Math.cos(an) * 10), Math.round(p[1] - 64 + Math.sin(an) * 6), 1, 1); } } } });
  const F = S.decor.facade;
  if (F.bench) list.push({ k: BX + 2.4, draw: () => { const c = mk(W, H); isoBox(c, o, BX + .35, 1.4, 6, .45, 1.6, 2, { top: C.wood3, left: C.wood2, right: C.wood1, edge: C.ink }); isoBox(c, o, BX + .35, 1.4, 8, .08, 1.6, 8, { top: C.wood3, left: C.wood2, right: C.wood1, edge: C.ink }); for (const yy of [1.5, 2.9]) { const p = isoR(o, BX + .55, yy, 0); vl(c, p[0], p[1] - 6, 6, C.plum); } g.drawImage(lit(quantize(c), Lk), 0, 0); if (S.flags && S.flags.gato) { const p = isoR(o, BX + .6, 2.2, 8); drawCatIso(g, p[0], p[1], time); } } });
  else if (S.flags && S.flags.gato) list.push({ k: BY + 8.2, draw: () => { const p = isoR(o, 7.7, BY + .5, 0); drawCatIso(g, p[0], p[1], time); } });
  if (F.bike) list.push({ k: BX + 5.7, draw: () => { const p = isoR(o, BX + 1.1, 4.6, 0); const x = p[0], y = p[1] - 6; ell(g, x - 8, y, 5, 5, L(C.plum)); ell(g, x - 8, y, 4, 4, L(C.offwhite)); ell(g, x + 8, y, 5, 5, L(C.plum)); ell(g, x + 8, y, 4, 4, L(C.offwhite)); ln(g, x - 8, y, x, y - 7, L(C.orange)); ln(g, x, y - 7, x + 8, y, L(C.orange)); ln(g, x - 2, y - 8, x + 6, y - 8, L(C.orange)); R(g, x + 5, y - 13, 7, 4, L(C.wood3)); flower(g, x + 8, y - 13, 0); } });
  for (let i = 0; i < 4; i++) list.push({ k: BX + .45 - 4.6 + i * 1.1, draw: () => { const p = isoR(o, BX + .45, -4.6 + i * 1.1, 0); R(g, p[0] - 3, p[1] - 6, 7, 6, L(C.sage)); hl(g, p[0] - 3, p[1] - 6, 7, L(C.mint)); for (let k = 0; k < 3; k++) { vl(g, p[0] - 2 + k * 2, p[1] - 11, 5, L(C.green1)); P(g, p[0] - 2 + k * 2, p[1] - 12, L([C.rose, C.sun, C.lilac, C.peach][(i + k) % 4])); } } });
  if (S.flags && S.flags.rafaPlaza && light !== 'noite') list.push({ k: BX + BY + 2.2, draw: () => { const p = isoR(o, BX + 1.0, BY + 1.2, 0); g.drawImage(lit(drawPerson(REGULARES.rafa.spec, { pose: 'sit' }), Lk), p[0] - 12, p[1] - 45); ell(g, p[0] + 3, p[1] - 18, 4, 4, L(C.wood3)); ln(g, p[0] + 4, p[1] - 20, p[0] - 6, p[1] - 28, L(C.wood1)); R(g, p[0] + 8, p[1] - 3, 10, 4, L(C.wood1)); R(g, p[0] + 9, p[1] - 2, 8, 2, L(C.wine)); } });
  for (const w of walkers) list.push({ k: w.x + w.y, draw: () => { const p = isoR(o, w.x, w.y, 0); g.drawImage(lit(drawPerson(w.spec, { facing: w.facing, pose: 'walk', frame: w.frame }), Lk), p[0] - 12, p[1] - 39); } });
  list.sort((a, b) => a.k - b.k);
  for (const it of list) it.draw();
  if (F.lights) for (let i = 0; i <= 28; i++) { const x = .3 + i * .24, sag = Math.sin(i / 7 * Math.PI) * 3; const p = isoR(o, x, BY + .02, 46 - sag); P(g, p[0], p[1], C.plum); if (i % 2 === 0) R(g, p[0], p[1] + 1, 2, 2, on ? [C.butter, C.sun, C.peach][(i + Math.floor(time * 2)) % 3] : L(C.offwhite)); }
  if (S.festa === 'junina') for (let i = 0; i < 40; i++) { const x = -3 + i * .32, p = isoR(o, x, BY + 2.6, 80 - Math.sin(i / 39 * Math.PI) * 14); P(g, p[0], p[1], C.plum); if (i % 2 === 0) poly(g, [[p[0], p[1] + 1], [p[0] + 5, p[1] + 1], [p[0] + 2, p[1] + 6]], [C.terra, C.sun, C.teal, C.rose, C.lime][(i / 2) % 5]); }
  if (S.festa === 'natal') for (let i = 0; i < 30; i++) { const p = isoR(o, i * .3, BY, HT + 3); if (i % 2 === 0) R(g, p[0], p[1], 2, 2, [C.terra, C.lime, C.sun][(i / 2 + Math.floor(time * 2)) % 3]); }
  if (Math.random() < .06) { const p = isoR(o, -1.6, BY + 1.45, 52); fxAdd({ x: p[0] - 16 + Math.random() * 32, y: p[1], vx: .2 + Math.random() * .3, vy: .25, life: 1, decay: .004, kind: 'leaf', c: L(leaf) }); }
  if (S.weather === 'chuva') { const r = rng(Math.floor(time * 14)); g.fillStyle = C.skylight; for (let i = 0; i < 120; i++) g.fillRect((r() * W) | 0, (r() * H) | 0, 1, 4); }
}
