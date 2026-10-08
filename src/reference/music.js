/* Aboden Games reference implementation, owner-authorized complete port 2026-10-08. See COMPLETE-REFERENCE-PORT-AR.md. */
// Dahrooj's background music, made in the browser by Aboden Games: an original, light-hearted tune in
// F major at 96 beats a minute, a plucked melody over a ukulele strum, an oom-pah bass, a glockenspiel
// answer, a soft shaker and kick. Nothing is recorded; every note is built here with Web Audio.
// The note button beside the game starts and mutes it; the game's own sounds are separate.
export const createReferenceMusic=(() => {
  'use strict';
  const hz = m => 440 * Math.pow(2, (m - 69) / 12);
  const _ = -1, R = 0; // _ holds the note before, R is a rest

  // Melody: eight eighth-notes a bar.
  const A = [
    [72,_,69,72,77,_,76,74], [72,_,67,_,76,_,74,72], [74,_,69,74,77,_,76,74], [74,72,70,_,74,_,R,R],
    [72,_,69,72,77,_,79,81], [79,_,76,_,72,_,R,72], [74,70,74,77,76,_,79,_], [77,_,_,_,R,R,R,R]];
  const B = [
    [77,_,74,_,70,_,74,77], [81,_,77,_,72,_,R,R], [79,77,74,70,74,_,79,_], [76,_,79,_,72,_,R,R],
    [74,77,82,_,81,79,77,74], [72,_,77,_,81,_,R,R], [82,81,79,77,76,_,79,_], [77,_,_,_,R,R,R,R]];
  // Chords: one or two a bar, as [root midi, quality].
  const F = [53,'M'], C = [48,'M'], Dm = [50,'m'], Bb = [46,'M'], Gm = [55,'m'];
  const chA = [[F],[C],[Dm],[Bb],[F],[C],[Bb,C],[F]];
  const chB = [[Bb],[F],[Gm],[C],[Bb],[F],[Gm,C],[F]];
  // Form: two bars of strum, then A, B, A with the bells; it loops from the top of A.
  const intro = {mel: [[R,R,R,R,R,R,R,R],[R,R,R,R,R,R,R,R]], ch: [[F],[C]]};
  const parts = [{mel: A, ch: chA}, {mel: B, ch: chB, bells: true}, {mel: A, ch: chA, bells: true, high: true}];

  // The events of the whole piece, in beats: {at, kind, midi, len, vel}.
  function score(P) {
    const SWING = P.swing;
    const ev = [], bars = [];
    const add = (mel, ch, opts) => { for (let i = 0; i < mel.length; i++) bars.push({...opts, mel: mel[i], ch: ch[i]}); };
    add(intro.mel, intro.ch, {intro: true});
    const loopBar = bars.length;
    for (const p of parts) add(p.mel, p.ch, p);
    bars.forEach((b, i) => {
      const t0 = i * 4;
      const at8 = k => t0 + Math.floor(k / 2) + (k % 2 ? SWING : 0);
      // Melody: plucked, a held note lasts until the next one.
      for (let k = 0; k < 8; k++) {
        const m = b.mel[k]; if (m <= 0) continue;
        let n = 1; while (k + n < 8 && b.mel[k + n] === _) n++;
        const len = at8(k + n) - at8(k);
        ev.push({at: at8(k), kind: P.lead, midi: m + 12 * P.oct, len, vel: k % 2 ? .8 : 1});
        if (P.bells && b.bells && (k % 2 === 0)) ev.push({at: at8(k), kind: 'bell', midi: m + 12, len, vel: b.high ? .55 : .4});
      }
      // Harmony: bass on beats 1 and 3 (root, then fifth), ukulele on 2 and 4 with a pick-up on the last "and".
      const chordAt = beat => b.ch.length > 1 && beat >= 2 ? b.ch[1] : b.ch[0];
      for (const beat of [0, 2]) { const [root] = chordAt(beat); ev.push({at: t0 + beat, kind: 'bass', midi: root - 12 + (beat === 2 ? 7 : 0), len: .8, vel: P.bass}); }
      for (const [beat, vel] of P.strums.map(([b, v]) => [b === 3.5 ? 3 + SWING : b, v])) { const c = chordAt(beat); ev.push({at: t0 + beat, kind: 'strum', chord: c, len: .5, vel: vel * P.strum, up: beat % 1 !== 0}); }
      // Shaker on every eighth, soft kick on 1 and 3.
      if (P.shaker && (!b.intro || i === 1)) for (let k = 0; k < 8; k++) ev.push({at: at8(k), kind: 'shake', vel: k % 2 ? .6 : 1});
      if (P.kick) for (const beat of [0, 2]) ev.push({at: t0 + beat, kind: 'kick', vel: beat ? .7 : 1});
    });
    return {ev, beats: bars.length * 4, loopAt: loopBar * 4};
  }

  // The instruments. Each plays one event into dest at time t (seconds).
  function instruments(ctx, dest, BEAT) {
    const noise = (() => { const b = ctx.createBuffer(1, ctx.sampleRate, ctx.sampleRate), d = b.getChannelData(0); for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1; return b; })();
    const env = (g, t, peak, a, d) => { g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(peak, t + a); g.gain.setTargetAtTime(0, t + a, d); };
    const osc = (type, f, t, stop) => { const o = ctx.createOscillator(); o.type = type; o.frequency.setValueAtTime(f, t); o.start(t); o.stop(stop); return o; };
    function pluck(t, f, vel, len, out, bright = 1) {
      const g = ctx.createGain(), lp = ctx.createBiquadFilter(), end = t + Math.min(1.6, len * BEAT + .5);
      lp.type = 'lowpass'; lp.Q.value = 1.5; lp.frequency.setValueAtTime(f * 6 * bright, t); lp.frequency.setTargetAtTime(f * 1.5, t, .08);
      const a = osc('triangle', f, t, end), b = osc('square', f * 1.003, t, end), bg = ctx.createGain(); bg.gain.value = .25;
      a.connect(lp); b.connect(bg).connect(lp); lp.connect(g).connect(out);
      env(g, t, .32 * vel, .004, Math.min(.35, len * BEAT * .5 + .08));
    }
    return {
      pluck(e, t) { pluck(t, hz(e.midi), e.vel, e.len, dest); },
      bell(e, t) {
        const end = t + 2.2;
        for (const [k, v, d] of [[1, .16, .55], [2.76, .05, .18], [5.4, .025, .08]]) {
          const g = ctx.createGain(); osc('sine', hz(e.midi) * k, t, end).connect(g).connect(dest); env(g, t, v * e.vel, .002, d);
        }
      },
      bass(e, t) {
        const end = t + 1, f = hz(e.midi), g = ctx.createGain(), lp = ctx.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 420; lp.Q.value = .8;
        osc('sawtooth', f, t, end).connect(lp); osc('sine', f, t, end).connect(g);
        lp.connect(g).connect(dest); env(g, t, .3 * e.vel, .02, .16);
      },
      strum(e, t) {
        const [root, q] = e.chord, notes = [root + 12, root + 12 + (q === 'm' ? 3 : 4), root + 19, root + 24];
        (e.up ? notes.slice().reverse() : notes).forEach((m, i) => pluck(t + i * .012, hz(m), e.vel * .38, .4, dest, .7));
      },
      shake(e, t) {
        const s = ctx.createBufferSource(), bp = ctx.createBiquadFilter(), g = ctx.createGain(); s.buffer = noise;
        bp.type = 'highpass'; bp.frequency.value = 6500; s.connect(bp).connect(g).connect(dest);
        env(g, t, .05 * e.vel, .006, .025); s.start(t, Math.random() * .8); s.stop(t + .15);
      },
      kick(e, t) {
        const o = osc('sine', 120, t, t + .3), g = ctx.createGain(); o.frequency.exponentialRampToValueAtTime(48, t + .12);
        o.connect(g).connect(dest); env(g, t, .3 * e.vel, .003, .07);
      }
    };
  }

  // Plays the piece into ctx from time `start`, looping, until stop(). Notes are scheduled a little ahead.
  // The settings can be changed (tempo, lead, which parts play); these are the game's.
  const DEFAULTS = {bpm: 96, swing: .58, lead: 'pluck', oct: 0, bells: true, kick: true, shaker: true, strum: 1, bass: 1, strums: [[1, 1], [3, .9], [3.5, .55]]};
  return  (ctx, dest, preset = {}) => {
    const P = {...DEFAULTS, ...preset}, BPM = P.bpm, BEAT = 60 / BPM;
    const {ev, beats, loopAt} = score(P), inst = instruments(ctx, dest, BEAT);
    let timer = null, origin = 0, nextBeat = 0;
    function scheduleUntil(until) {
      // until is in seconds of ctx time; the piece plays once through, then from loopAt again and again.
      while (true) {
        const loopLen = beats - loopAt;
        const pieceBeat = nextBeat < beats ? nextBeat : loopAt + ((nextBeat - beats) % loopLen);
        const passBase = nextBeat - pieceBeat; // beats already played before this pass
        const t = origin + nextBeat * BEAT;
        if (t > until) return;
        const windowEnd = Math.min(pieceBeat + .25, nextBeat < beats ? beats : beats);
        for (const e of ev) if (e.at >= pieceBeat && e.at < windowEnd) inst[e.kind](e, origin + (passBase + e.at) * BEAT);
        nextBeat += windowEnd - pieceBeat;
      }
    }
    return {
      bpm: BPM, loopSeconds: (beats - loopAt) * BEAT, introSeconds: loopAt * BEAT,
      start(at = ctx.currentTime + .05) { origin = at; nextBeat = 0; scheduleUntil(at + .4); if (!(ctx instanceof OfflineAudioContext)) timer = setInterval(() => scheduleUntil(ctx.currentTime + .4), 100); },
      renderAll(seconds) { scheduleUntil(origin + seconds); },
      stop() { clearInterval(timer); timer = null; }
    };
  };


})();
