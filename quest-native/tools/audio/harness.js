// Runs inside headless Chromium (served by render_audio.mjs). Loads the ORIGINAL web-game sound code
// (src/reference/*) and renders it with an OfflineAudioContext standing in for the live AudioContext.
import {createReferenceSounds} from '/ref/sounds.js';
import {createReferenceMusic} from '/ref/music.js';
import {synthesizeFirework} from '/ref/firework-audio';

const RealAC = window.AudioContext;
let pendingCtx = null;
// sounds.js does `new (window.AudioContext||...)()`: hand it the offline context we prepared.
window.AudioContext = function () { if (!pendingCtx) throw new Error('no ctx'); const c = pendingCtx; pendingCtx = null; return c; };
window.webkitAudioContext = window.AudioContext;
void RealAC;

function offline(seconds, sr = 44100) {
  const ctx = new OfflineAudioContext(1, Math.ceil(seconds * sr), sr);
  // startPopSound / firework play() only sound while the context is 'running'.
  Object.defineProperty(ctx, 'state', {get: () => 'running'});
  ctx.resume = () => Promise.resolve();
  return ctx;
}
function freshSounds(ctx) { const s = createReferenceSounds(); pendingCtx = ctx; s.ensureAudio(); return s; }

// Pulls `function name(...){...}` out of an original source file by brace matching.
function extractFn(src, name) {
  const i = src.indexOf('function ' + name + '(');
  if (i < 0) throw new Error('missing function ' + name);
  let j = src.indexOf('{', src.indexOf(')', i)), depth = 0;
  for (let k = j; k < src.length; k++) {
    if (src[k] === '{') depth++;
    else if (src[k] === '}' && --depth === 0) return src.slice(i, k + 1);
  }
  throw new Error('unbalanced ' + name);
}
// Math with forced random draws first (to pick e.g. a bird's call kind), then real Math.random.
function forcedMath(forced) { const M = Object.create(Math); const q = [...(forced || [])]; M.random = () => q.length ? q.shift() : Math.random(); return M; }

async function finish(ctx) { const buf = await ctx.startRendering(); return b64(buf.getChannelData(0)); }
function b64(f32) {
  const u8 = new Uint8Array(f32.buffer, f32.byteOffset, f32.byteLength); let s = '';
  for (let i = 0; i < u8.length; i += 0x8000) s += String.fromCharCode.apply(null, u8.subarray(i, i + 0x8000));
  return btoa(s);
}

window.render = async (spec, sources) => {
  if (spec.kind === 'sounds') { // a function of sounds.js, played through its SFX bus (gain 2.2 + limiter)
    const ctx = offline(spec.dur), s = freshSounds(ctx);
    s[spec.fn](...(spec.args || []));
    return finish(ctx);
  }
  if (spec.kind === 'firework') { // firework-audio.ts play(): cached buffer (seed 17+i*7919) at gain .28/.5 into sfxOut
    const ctx = offline(spec.dur), s = freshSounds(ctx);
    const data = synthesizeFirework(spec.cue, ctx.sampleRate, 17 + spec.index * 7919), buf = ctx.createBuffer(1, data.length, ctx.sampleRate);
    buf.copyToChannel(data, 0);
    const src = ctx.createBufferSource(), g = ctx.createGain(); src.buffer = buf; g.gain.value = spec.cue === 'launch' ? .28 : .5;
    src.connect(g).connect(s.sfxOut()); src.start(0);
    return finish(ctx);
  }
  if (spec.kind === 'stage') { // a stage-local sound function, cut out of the stage file verbatim
    const ctx = offline(spec.dur), s = freshSounds(ctx);
    const body = extractFn(sources[spec.file], spec.fn);
    const fn = new Function('audio', 'sfxOut', 'Math', `let time=1,clangT=-1,clackT=-1;${body};return ${spec.fn};`)(ctx, s.sfxOut, forcedMath(spec.forced));
    fn(...(spec.args || []));
    return finish(ctx);
  }
  if (spec.kind === 'ambience') { // ambience.js event/bed generators, cut out verbatim; spatial panner left to Godot
    const sr = spec.sr || 44100, ctx = offline(spec.dur, sr), src = sources['ambience.js'];
    const out = ctx.createGain(); out.gain.value = spec.out ?? .7; out.connect(ctx.destination);
    const names = ['noise', 'crickets', 'bird', 'plop', 'frog', 'filter', 'gain'];
    const code = `const clamp=(v,a,b)=>Math.max(a,Math.min(b,v)),rnd=(a,b)=>a+Math.random()*(b-a);let calls=0;
      function panner(x,y,z,ref){const g=ctx.createGain();g.connect(out);return g;}
      ${names.map(n => extractFn(src, n)).join('\n')}
      return {${names.join(',')}};`;
    const A = new Function('ctx', 'out', 'Math', 'setTimeout', code)(ctx, out, forcedMath(spec.forced), () => 0);
    if (spec.what === 'bird') A.bird(0, 0, 0);
    else if (spec.what === 'plop') A.plop(0, 0);
    else if (spec.what === 'frog') A.frog(0, 0);
    else if (spec.what === 'rain') { // B.rain bed at gain 1: noise(5) looped -> highpass 1200 -> lowpass 6000
      const s = ctx.createBufferSource(); s.buffer = A.noise(5, false); s.loop = true; s.start(0);
      s.connect(A.filter('highpass', 1200)).connect(A.filter('lowpass', 6000)).connect(out);
      const buf = await ctx.startRendering(), d = buf.getChannelData(0), m = s.buffer.length;
      return b64(d.slice(m, 2 * m)); // one period, after the filters settle: a seamless loop
    } else if (spec.what === 'crickets') { // the cricket buffer itself (looped by three panned sources in the game)
      return b64(A.crickets(3.1).getChannelData(0).slice());
    }
    return finish(ctx);
  }
  if (spec.kind === 'music') { // music.js, whole piece scheduled offline into a unity-gain destination
    const ctx = new OfflineAudioContext(1, Math.ceil(spec.dur * 44100), 44100);
    const m = createReferenceMusic(ctx, ctx.destination);
    m.start(0); m.renderAll(spec.dur);
    const buf = await ctx.startRendering();
    return {data: b64(buf.getChannelData(0)), intro: m.introSeconds, loop: m.loopSeconds};
  }
  throw new Error('bad spec ' + JSON.stringify(spec));
};
window.harnessReady = true;
