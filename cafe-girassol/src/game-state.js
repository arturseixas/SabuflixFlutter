'use strict';
/* Estado, salvamento, calendário real e regras de progressão. */
const SAVE_KEY = 'cafe-girassol-v1';
const HOUR = 3600 * 1000;
const STAGE_MS = 6 * HOUR;

function newState() {
  return {
    v: 1, nome: '', neto: 'neta', cafeName: 'Café Girassol', foundedYear: 1974,
    dia: 1, coins: 30, flores: 0, sementes: 0, xp: 0, nivel: 1,
    kits: { coador: 1, leiteira: 1 }, ings: { acucar: 1, leite: 1, chocolate: 1 }, quitandas: { paodequeijo: 1, bolo: 1 },
    graos: { casa: 1 }, graoAtivo: 'casa', latte: { coracao: 1 }, latteAtivo: 'coracao',
    receitas: {}, reg: {}, gifts: { fotovo: 1 },
    decor: {
      facade: { wall: 'amarelo', trim: 'verde', door: 'vinho', awning: 'listras', awningColor: 'vinho', sign: 'madeira', lights: false, bench: false, bike: false, mural: false },
      interior: { wall: 'listras', floor: 'taco', counter: 'madeira', lamps: 'pendente', tables: 'madeira', plants: 'samambaia', plants2: 'costela', gifts: {} },
    },
    owned: { fw_amarelo: 1, ft_verde: 1, fd_vinho: 1, fa_listras: 1, fac_vinho: 1, fs_madeira: 1, iw_listras: 1, if_taco: 1, ic_madeira: 1, il_pendente: 1, it_madeira: 1, ip_samambaia: 1, ip2_costela: 1 },
    garden: [null, null, null, null], flags: {}, cartas: [], cartasPendentes: [],
    album: {}, diasAbertos: 0, ultimaData: '', marcos: {}, missoes: { data: '', lista: [] },
    passanteHoje: null, stats: { servidos: 0, tres: 0, moedas: 0, dias: 0 }, coldbrew: 0,
    opts: { musica: true, som: true, rapido: false, dicas: true },
    finalVisto: false, iniciado: false,
  };
}
let S = newState();
function save() { try { localStorage.setItem(SAVE_KEY, JSON.stringify(S)); } catch (e) { /* sem armazenamento */ } }
function load() {
  try {
    const raw = localStorage.getItem(SAVE_KEY);
    if (!raw) return false;
    const d = JSON.parse(raw);
    S = Object.assign(newState(), d);
    S.decor.facade = Object.assign(newState().decor.facade, d.decor && d.decor.facade);
    S.decor.interior = Object.assign(newState().decor.interior, d.decor && d.decor.interior);
    S.opts = Object.assign(newState().opts, d.opts);
    return !!S.iniciado;
  } catch (e) { return false; }
}
function exportSave() { return btoa(unescape(encodeURIComponent(JSON.stringify(S)))); }
function importSave(code) {
  const d = JSON.parse(decodeURIComponent(escape(atob(code.trim()))));
  if (!d || !d.v) throw new Error('código inválido');
  S = Object.assign(newState(), d); save();
}

/* ---------- texto ---------- */
function tpl(s) {
  const o = S.neto === 'neto' ? 'o' : S.neto === 'nete' ? 'e' : 'a';
  return String(s).replace(/\{nome\}/g, S.nome || 'você').replace(/\{neto\}/g, S.neto).replace(/\{o\}/g, o).replace(/\{cafe\}/g, S.cafeName);
}

/* ---------- calendário real ---------- */
function dateKey(d) { d = d || new Date(); return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0'); }
const MESES = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];
const SEMANA = ['domingo', 'segunda-feira', 'terça-feira', 'quarta-feira', 'quinta-feira', 'sexta-feira', 'sábado'];
function seasonOf(d) { const m = d.getMonth(); return m === 11 || m <= 1 ? 'verão' : m <= 4 ? 'outono' : m <= 7 ? 'inverno' : 'primavera'; }
function easter(y) {
  const a = y % 19, b = Math.floor(y / 100), c = y % 100, d = Math.floor(b / 4), e = b % 4, f = Math.floor((b + 8) / 25), g = Math.floor((b - f + 1) / 3);
  const h = (19 * a + b - d - g + 15) % 30, i = Math.floor(c / 4), k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7, m = Math.floor((a + 11 * h + 22 * l) / 451);
  const mo = Math.floor((h + l - 7 * m + 114) / 31), da = ((h + l - 7 * m + 114) % 31) + 1;
  return new Date(y, mo - 1, da);
}
function festaOf(d) {
  const m = d.getMonth(), day = d.getDate();
  const e = easter(d.getFullYear()), carn = new Date(e.getTime() - 47 * 864e5);
  const diff = Math.round((new Date(d.getFullYear(), m, day) - new Date(carn.getFullYear(), carn.getMonth(), carn.getDate())) / 864e5);
  if (diff >= -3 && diff <= 1) return 'carnaval';
  if (m === 5) return 'junina';
  if (m === 11 && day <= 26) return 'natal';
  if (m === 4 && day === 24) return 'diadocafe';
  if (m === 9 && day === 12) return 'criancas';
  return null;
}
const FESTA_NOMES = { carnaval: 'Carnaval', junina: 'Festa Junina', natal: 'Natal', diadocafe: 'Dia Nacional do Café', criancas: 'Dia das Crianças' };
const FESTA_TXT = {
  carnaval: 'Confete na calçada e marchinha no rádio. Hoje o povo pede coisa gelada.',
  junina: 'Bandeirinhas na fachada. Café com paçoca entra no cardápio enquanto durar junho.',
  natal: 'Pisca-pisca no letreiro. Café com doce de leite entra no cardápio até o dia 26.',
  diadocafe: 'Dia Nacional do Café, 24 de maio. Toda bebida com café rende gorjeta em dobro.',
  criancas: 'Dia das Crianças. Chocolate quente sai por conta da casa e rende carinho em dobro.',
};
function dayInfo() {
  const d = new Date();
  return { d, key: dateKey(d), season: seasonOf(d), festa: festaOf(d), txt: SEMANA[d.getDay()] + ', ' + d.getDate() + ' de ' + MESES[d.getMonth()] };
}
function seedOfKey(k) { return hashStr('cg' + k); }

/* clima do dia de jogo: sorteado por estação (verão chove mais no Sudeste) */
function weatherFor(dia, season) {
  const r = rng(hashStr('w' + dia + S.nome))();
  const chuva = season === 'verão' ? .35 : season === 'primavera' ? .22 : season === 'outono' ? .15 : .07;
  return r < chuva ? 'chuva' : r < chuva + .2 ? 'nublado' : 'sol';
}

/* ---------- novo dia real ---------- */
function rollRealDay() {
  const info = dayInfo();
  if (S.ultimaData === info.key) return null;
  const novo = { primeiro: !S.ultimaData, ganhos: [] };
  S.ultimaData = info.key;
  S.diasAbertos++;
  // presente diário modesto
  S.sementes += 1; novo.ganhos.push('1 semente de girassol');
  // missões
  const r = rng(seedOfKey(info.key));
  const pool = MISSOES.slice();
  S.missoes = { data: info.key, lista: [] };
  for (let i = 0; i < 3 && pool.length; i++) {
    const m = pool.splice(Math.floor(r() * pool.length), 1)[0];
    const alvo = m.n[0] + Math.floor(r() * (m.n[1] - m.n[0] + 1));
    S.missoes.lista.push({ id: m.id, chave: m.chave, txt: m.txt.replace('{n}', alvo), alvo, prog: 0, feito: false, vistos: [] });
  }
  // visitante do dia
  const pas = PASSANTES[Math.floor(r() * PASSANTES.length)];
  const naoVistos = PASSANTES.filter(p => !S.album[p.id]);
  const escolha = naoVistos.length ? naoVistos[Math.floor(r() * naoVistos.length)] : pas;
  S.passanteHoje = { id: escolha.id, visto: false };
  // cartas pendentes
  const libera = S.cartasPendentes.filter(c => c.em <= info.key || c.em === 'proximo');
  S.cartasPendentes = S.cartasPendentes.filter(c => !(c.em <= info.key || c.em === 'proximo'));
  for (const c of libera) addCarta(c.id);
  // marcos cumulativos
  for (const m of MARCOS) {
    if (S.diasAbertos >= m.dias && !S.marcos[m.dias]) { S.marcos[m.dias] = 1; aplicarPremio(m.premio); novo.ganhos.push('Marco de ' + m.dias + ' dias: ' + m.txt); }
  }
  if (S.flags.gato && S.album.gatoperdido && !S.flags.cartaFuba) { S.flags.cartaFuba = 1; addCarta('fuba'); }
  novo.libera = libera.length;
  return novo;
}
function aplicarPremio(p) {
  if (p.latte) S.latte[p.latte] = 1;
  if (p.sementes) S.sementes += p.sementes;
  if (p.flores) S.flores += p.flores;
  if (p.moedas) S.coins += p.moedas;
  if (p.flag) S.flags[p.flag] = 1;
  if (p.gift) S.gifts[p.gift] = 1;
  if (p.carta) addCarta(p.carta);
}
function addCarta(id) { if (!S.cartas.find(c => c.id === id)) S.cartas.push({ id, lida: false, dia: S.dia }); if (CARTAS[id] && CARTAS[id].gift) S.gifts[CARTAS[id].gift] = 1; }
function agendarCarta(id) { const amanha = new Date(Date.now() + 864e5); S.cartasPendentes.push({ id, em: dateKey(amanha) }); }
function missao(chave, n, extra) {
  for (const m of S.missoes.lista) {
    if (m.feito || m.chave !== chave) continue;
    if (chave === 'variedade') { if (m.vistos.indexOf(extra) >= 0) continue; m.vistos.push(extra); m.prog = m.vistos.length >= 1 ? 1 : 0; }
    else m.prog += n || 1;
    if (m.prog >= m.alvo) { m.feito = true; S.coins += 25; S.sementes += 1; UI.toast('Pedido da rua cumprido: ' + m.txt + ' (+25 moedas, +1 semente)'); AUD.sfx('chime'); }
  }
}

/* ---------- nível ---------- */
function xpNeed(n) { return 60 + 22 * n; }
function addXP(x) {
  S.xp += x;
  const ups = [];
  while (S.xp >= xpNeed(S.nivel)) { S.xp -= xpNeed(S.nivel); S.nivel++; ups.push(S.nivel); }
  return ups;
}
function unlocksAt(n) {
  const out = [];
  for (const k of KIT_ORDER) if (KITS[k].nivel === n) out.push('Kit: ' + KITS[k].nome);
  for (const k of ING_ORDER) if (INGREDIENTES[k].nivel === n && !INGREDIENTES[k].sazonal) out.push('Ingrediente: ' + INGREDIENTES[k].nome);
  for (const k in GRAOS) if (GRAOS[k].nivel === n) out.push('Grão: ' + GRAOS[k].nome);
  for (const k in QUITANDAS) if (QUITANDAS[k].nivel === n) out.push('Quitanda: ' + QUITANDAS[k].nome);
  return out;
}

/* ---------- disponibilidade ---------- */
function ingDisponivel(id) {
  const i = INGREDIENTES[id];
  if (i.sazonal) return dayInfo().festa === i.sazonal;
  if (i.requer && !S.kits[i.requer]) return false;
  return !!S.ings[id] || (i.preco === 0 && S.nivel >= i.nivel && (!i.requer || S.kits[i.requer]));
}
function receitaPossivel(id) {
  const r = RECEITAS[id];
  if (!r || !S.kits[r.kit]) return false;
  if (r.sazonal && dayInfo().festa !== r.sazonal) return false;
  return r.adds.every(ingDisponivel);
}
function matchRecipe(kit, adds) {
  const key = adds.slice().sort().join(',');
  for (const id in RECEITAS) { const r = RECEITAS[id]; if (r.kit === kit && r.adds.slice().sort().join(',') === key) return id; }
  return null;
}
function receitaDoDia() {
  const k = dayInfo().key;
  const ids = Object.keys(RECEITAS).filter(id => receitaPossivel(id) && !RECEITAS[id].secreta);
  if (!ids.length) return 'coado';
  return ids[seedOfKey(k + 'r') % ids.length];
}

/* ---------- fregueses regulares ---------- */
function regState(id) {
  if (!S.reg[id]) S.reg[id] = { afin: 0, beat: 0, visto: [], ultimoDiaBeat: -1, ultimaVisita: -9, intro: false, fim: false, sempre: REGULARES[id].sempre, xicaras: REGULARES[id].xicaras || 1, sempreConhecido: false, final: false, visitas: 0 };
  return S.reg[id];
}
function afinLevel(a) { let l = 0; for (let i = 0; i < AFINIDADE.length; i++) if (a >= AFINIDADE[i]) l = i; return l; }
function reqOk(req) {
  if (!req) return true;
  return req.every(r => { const [id, n] = r.split(':'); const st = S.reg[id]; return st && st.visto.indexOf(+n) >= 0; });
}
function beatPronto(id) {
  const st = regState(id), C = REGULARES[id];
  if (st.fim) return null;
  const b = C.beats[st.beat];
  if (!b) return null;
  if (st.ultimoDiaBeat >= S.dia) return null;
  if (st.afin < AFINIDADE[b.lvl]) return null;
  if (!reqOk(b.req)) return null;
  if (b.pedido && b.pedido.receita && !receitaPossivel(b.pedido.receita) && st.beat > 0) return null;
  return b;
}
function introPronto(id) {
  const C = REGULARES[id], st = regState(id);
  if (st.intro) return false;
  if (S.dia < C.intro.dia) return false;
  if (C.intro.kit && !S.kits[C.intro.kit]) return false;
  const b = C.beats[0];
  if (b.pedido && b.pedido.receita && !receitaPossivel(b.pedido.receita)) return false;
  return true;
}
function sempreAtual(id) {
  const st = regState(id), C = REGULARES[id];
  const tries = [st.sempre, C.sempre].concat(C.sempreFallback || ['coado']);
  for (const t of tries) if (receitaPossivel(t)) return t;
  return 'coado';
}
function todosFinais() { return REG_ORDER.every(id => S.reg[id] && S.reg[id].fim); }
