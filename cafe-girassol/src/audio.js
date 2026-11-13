'use strict';
/* Áudio gerado com Web Audio: trilha bossa-lofi e efeitos. Nada é baixado. */
const AUD = (function () {
  let ctx = null, master = null, musicBus = null, sfxBus = null, noiseBuf = null, timer = null, nextT = 0, step = 0, rainNode = null;
  const loops = {};
  const BPM = 84, SPB = 60 / BPM / 2; // colcheias
  // Cmaj7 Am7 Dm7 G7 Em7 A7 Dm7 G7(b9)
  const CH = [[48, 52, 55, 59], [45, 52, 55, 60], [50, 53, 57, 60], [43, 53, 57, 59], [52, 55, 59, 62], [45, 55, 58, 61], [50, 53, 57, 60], [43, 53, 56, 59]];
  const COMP = [1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0]; // levada de bossa em 2 compassos
  const SCALE = [72, 74, 76, 79, 81, 84, 86];
  const f = m => 440 * Math.pow(2, (m - 69) / 12);

  function init() {
    if (ctx) { if (ctx.state === 'suspended') ctx.resume(); return; }
    try { ctx = new (window.AudioContext || window.webkitAudioContext)(); } catch (e) { return; }
    master = ctx.createGain(); master.gain.value = .8; master.connect(ctx.destination);
    musicBus = ctx.createGain(); musicBus.gain.value = S.opts.musica ? .32 : 0;
    const lp = ctx.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 2600;
    musicBus.connect(lp); lp.connect(master);
    sfxBus = ctx.createGain(); sfxBus.gain.value = S.opts.som ? .9 : 0; sfxBus.connect(master);
    noiseBuf = ctx.createBuffer(1, ctx.sampleRate * 2, ctx.sampleRate);
    const d = noiseBuf.getChannelData(0); for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
    nextT = ctx.currentTime + .1;
    timer = setInterval(sched, 90);
    document.addEventListener('visibilitychange', () => { if (!ctx) return; if (document.hidden) ctx.suspend(); else ctx.resume(); });
  }
  function env(g, t, a, peak, dec, sus) {
    g.gain.cancelScheduledValues(t); g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(peak, t + a);
    g.gain.exponentialRampToValueAtTime(Math.max(.0001, sus || .0001), t + a + dec);
  }
  function tone(type, freq, t, dur, vol, bus, a) {
    const o = ctx.createOscillator(), g = ctx.createGain();
    o.type = type; o.frequency.setValueAtTime(freq, t);
    env(g, t, a || .005, vol, dur);
    o.connect(g); g.connect(bus || sfxBus); o.start(t); o.stop(t + (a || .005) + dur + .05);
    return o;
  }
  function ep(m, t, dur, vol) { // piano elétrico: seno + leve trêmulo de harmônico
    tone('sine', f(m), t, dur, vol, musicBus, .01);
    tone('triangle', f(m) * 2, t, dur * .5, vol * .18, musicBus, .01);
  }
  function noise(t, dur, vol, type, freq, q, bus) {
    const s = ctx.createBufferSource(); s.buffer = noiseBuf;
    const fl = ctx.createBiquadFilter(); fl.type = type || 'highpass'; fl.frequency.value = freq || 6000; fl.Q.value = q || .7;
    const g = ctx.createGain(); env(g, t, .002, vol, dur);
    s.connect(fl); fl.connect(g); g.connect(bus || sfxBus); s.start(t, Math.random()); s.stop(t + dur + .05);
  }
  function sched() {
    if (!ctx || ctx.state !== 'running') return;
    while (nextT < ctx.currentTime + .4) {
      const bar = Math.floor(step / 8), chord = CH[bar % CH.length], pos = step % 16, t = nextT;
      if (S.opts.musica) {
        if (COMP[pos]) chord.forEach((m, i) => ep(m + 12, t + i * .012, SPB * 2.6, .045));
        if (pos % 8 === 0) tone('sine', f(chord[0] - 12), t, SPB * 3, .16, musicBus, .01);
        if (pos % 8 === 5) tone('sine', f(chord[2] - 24 + (chord[2] - chord[0] > 6 ? 0 : 7)), t, SPB * 2, .12, musicBus, .01);
        noise(t, .04, pos % 2 ? .018 : .03, 'highpass', 7000, .7, musicBus);
        const r = Math.random();
        if (pos % 2 === 0 && r < .2) { const m = SCALE[Math.floor(Math.random() * SCALE.length)]; ep(m, t, SPB * 3, .035); }
      }
      nextT += SPB; step++;
    }
  }
  const SFX = {
    bell() { const t = ctx.currentTime; tone('sine', 1318, t, 1.2, .18); tone('sine', 1975, t, .8, .08); tone('sine', 1318, t + .14, 1, .12); tone('sine', 2637, t + .14, .5, .04); },
    coin() { const t = ctx.currentTime; tone('square', 988, t, .06, .05); tone('square', 1318, t + .06, .14, .05); },
    click() { const t = ctx.currentTime; tone('triangle', 660, t, .03, .06); },
    chime() { const t = ctx.currentTime;[72, 76, 79, 84].forEach((m, i) => tone('sine', f(m), t + i * .07, .5, .07)); },
    serve() { const t = ctx.currentTime; tone('sine', f(79), t, .25, .07); tone('sine', f(84), t + .08, .4, .06); noise(t, .05, .05, 'bandpass', 3000, 2); },
    heart() { const t = ctx.currentTime; tone('sine', f(76), t, .2, .07); tone('sine', f(81), t + .1, .35, .07); },
    level() { const t = ctx.currentTime;[60, 64, 67, 72, 76, 79, 84].forEach((m, i) => tone('triangle', f(m), t + i * .06, .35, .06)); },
    page() { const t = ctx.currentTime; noise(t, .12, .06, 'bandpass', 2400, .8); },
    good() { const t = ctx.currentTime; tone('sine', f(84), t, .18, .06); tone('sine', f(88), t + .06, .25, .05); },
    meh() { const t = ctx.currentTime; tone('sine', f(72), t, .2, .05); },
    door() { const t = ctx.currentTime; noise(t, .2, .04, 'lowpass', 400, 1); },
    gurgle() { const t = ctx.currentTime; for (let i = 0; i < 5; i++) tone('sine', 200 + Math.random() * 300, t + i * .05 + Math.random() * .03, .05, .05); },
  };
  function sfx(n) { if (!ctx || !S.opts.som) return; try { SFX[n] && SFX[n](); } catch (e) { } }
  /* sons contínuos enquanto o botão está pressionado */
  const LOOP_DEF = {
    grind: { type: 'bandpass', freq: 1800, q: 1.5, vol: .22, lfo: 22 },
    pour: { type: 'lowpass', freq: 900, q: 1, vol: .2, lfo: 5 },
    steam: { type: 'highpass', freq: 3500, q: .7, vol: .12, lfo: 9 },
    heat: { type: 'lowpass', freq: 300, q: 1, vol: .18, lfo: 3 },
    espresso: { type: 'bandpass', freq: 500, q: 3, vol: .16, lfo: 14 },
  };
  function loopStart(n) {
    if (!ctx || !S.opts.som || loops[n]) return;
    const d = LOOP_DEF[n]; if (!d) return;
    const s = ctx.createBufferSource(); s.buffer = noiseBuf; s.loop = true;
    const fl = ctx.createBiquadFilter(); fl.type = d.type; fl.frequency.value = d.freq; fl.Q.value = d.q;
    const g = ctx.createGain(); g.gain.value = 0; g.gain.linearRampToValueAtTime(d.vol, ctx.currentTime + .08);
    const lfo = ctx.createOscillator(), lg = ctx.createGain(); lfo.frequency.value = d.lfo; lg.gain.value = d.vol * .4; lfo.connect(lg); lg.connect(g.gain); lfo.start();
    s.connect(fl); fl.connect(g); g.connect(sfxBus); s.start();
    loops[n] = { s, g, lfo };
  }
  function loopStop(n) {
    const l = loops[n]; if (!l) return; delete loops[n];
    const t = ctx.currentTime; l.g.gain.cancelScheduledValues(t); l.g.gain.setValueAtTime(l.g.gain.value, t); l.g.gain.linearRampToValueAtTime(0, t + .12);
    l.s.stop(t + .15); l.lfo.stop(t + .15);
  }
  function rain(on) {
    if (!ctx) return;
    if (on && !rainNode && S.opts.som) {
      const s = ctx.createBufferSource(); s.buffer = noiseBuf; s.loop = true;
      const fl = ctx.createBiquadFilter(); fl.type = 'lowpass'; fl.frequency.value = 1400;
      const g = ctx.createGain(); g.gain.value = .05; s.connect(fl); fl.connect(g); g.connect(master); s.start(); rainNode = { s, g };
    } else if (!on && rainNode) { rainNode.s.stop(); rainNode = null; }
  }
  function setOpts() { if (!ctx) return; musicBus.gain.value = S.opts.musica ? .32 : 0; sfxBus.gain.value = S.opts.som ? .9 : 0; if (!S.opts.som) { rain(false); Object.keys(loops).forEach(loopStop); } }
  return { init, sfx, loopStart, loopStop, rain, setOpts };
})();
