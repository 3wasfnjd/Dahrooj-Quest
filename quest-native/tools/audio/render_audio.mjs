// Renders every sound of the web game from its ORIGINAL Web Audio code into quest-native/assets/audio/.
//   cd /home/user/dahrooj-quest && PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers /opt/node22/bin/node quest-native/tools/audio/render_audio.mjs [filter]
// Headless Chromium loads src/reference/{sounds,music,ambience}.js, firework-audio.ts (via esbuild) and the stage
// files, and renders each sound with an OfflineAudioContext (harness.js). ffmpeg writes the files:
//   SFX: mono 22050 Hz 16-bit WAV, at the level the web SFX bus outputs (gain 2.2 + limiter baked in).
//   Music / ambience beds: OGG Vorbis, scaled by a fixed factor (see SCALE) that game_audio.gd undoes.
import {chromium} from 'playwright';
import {build} from 'esbuild';
import {readFileSync, writeFileSync, mkdirSync, rmSync, statSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {tmpdir} from 'node:os';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, '../../..');
const REF = join(ROOT, 'src/reference');
const OUT = resolve(HERE, '../../assets/audio');
const TMP = join(tmpdir(), 'dahrooj-audio-render');
mkdirSync(OUT, {recursive: true}); mkdirSync(TMP, {recursive: true});
const only = process.argv[2] ? new RegExp(process.argv[2]) : null;

// Fixed scales for the long files (so game_audio.gd can undo them): file = original * SCALE.
export const SCALE = {music: 0.5, rain: 0.35, crickets: 1.0};

const kTag = k => 'k' + String(Math.round(k * 100)).padStart(2, '0');
const specs = [];
const add = (name, spec) => specs.push({name, ...spec});
const R3 = [1, 2, 3];
// ---- sounds.js (shared) ----
for (const k of [.25, .5, .75, 1]) add(`thump_${kTag(k)}`, {kind: 'sounds', fn: 'thump', args: [k], dur: .26});
for (const p of [.7, 1, 1.15, 1.35]) add(`squeak_${kTag(p)}`, {kind: 'sounds', fn: 'squeak', args: [p], dur: .25});
for (const i of R3) add(`pew_${i}`, {kind: 'sounds', fn: 'pew', dur: .18});
for (const k of [.25, .5, .75, 1]) for (const i of R3) add(`splash_${kTag(k)}_${i}`, {kind: 'sounds', fn: 'splash', args: [k], dur: .5});
for (const i of R3) add(`boom_${i}`, {kind: 'sounds', fn: 'boom', dur: .78});
for (const p of [.2, .4, .6, .8, 1]) add(`whoosh_${kTag(p)}`, {kind: 'sounds', fn: 'whoosh', args: [p], dur: .2});
for (const i of R3) add(`swish_${i}`, {kind: 'sounds', fn: 'swish', dur: .4});
add('chime', {kind: 'sounds', fn: 'chime', dur: .52});
add('start_pop', {kind: 'sounds', fn: 'startPopSound', dur: .14});
for (const i of [0, 1, 2]) {
  add(`firework_launch_${i + 1}`, {kind: 'firework', cue: 'launch', index: i, dur: .28});
  add(`firework_burst_${i + 1}`, {kind: 'firework', cue: 'burst', index: i, dur: .76});
}
// ---- stage-local ----
for (const k of [.25, .5, .75, 1]) for (const i of R3) add(`cans_clang_${kTag(k)}_${i}`, {kind: 'stage', file: 'stages/cans.js', fn: 'clang', args: [k], dur: .52});
for (const k of [.25, .5, .75, 1]) for (const i of R3) add(`bowling_clack_${kTag(k)}_${i}`, {kind: 'stage', file: 'stages/bowling.js', fn: 'clack', args: [k], dur: .2});
for (const k of [0, .25, .5, .75, 1]) add(`bricks_tink_${kTag(k)}`, {kind: 'stage', file: 'stages/bricks.js', fn: 'tink', args: [k], dur: .32});
add('fair_ding', {kind: 'stage', file: 'stages/fair.js', fn: 'ding', dur: 1.27});
// ---- ambience.js events (spatial in the game; levels include the ambience out gain .7) ----
for (let kind = 0; kind < 4; kind++) for (const i of [1, 2]) add(`amb_bird_${kind}_${i}`, {kind: 'ambience', what: 'bird', forced: [kind / 4 + .01], dur: kind === 1 ? .75 : .65});
for (const i of R3) add(`amb_plop_${i}`, {kind: 'ambience', what: 'plop', dur: .15});
for (const i of R3) add(`amb_frog_${i}`, {kind: 'ambience', what: 'frog', dur: .66});
// ---- beds and music ----
add('amb_rain_loop', {kind: 'ambience', what: 'rain', sr: 22050, out: 1, dur: 10.5, ogg: true, scale: SCALE.rain, rate: 22050});
add('amb_crickets_loop', {kind: 'ambience', what: 'crickets', sr: 22050, out: 1, dur: .1, ogg: true, scale: SCALE.crickets, rate: 22050});
add('music', {kind: 'music', dur: 125, ogg: true, scale: SCALE.music, rate: 44100});

function wavFloat(path, f32, sr) {
  const h = Buffer.alloc(44), n = f32.length * 4;
  h.write('RIFF', 0); h.writeUInt32LE(36 + n, 4); h.write('WAVE', 8); h.write('fmt ', 12); h.writeUInt32LE(16, 16);
  h.writeUInt16LE(3, 20); h.writeUInt16LE(1, 22); h.writeUInt32LE(sr, 24); h.writeUInt32LE(sr * 4, 28); h.writeUInt16LE(4, 32); h.writeUInt16LE(32, 34);
  h.write('data', 36); h.writeUInt32LE(n, 40);
  writeFileSync(path, Buffer.concat([h, Buffer.from(f32.buffer, f32.byteOffset, f32.byteLength)]));
}
const f32of = b64 => { const b = Buffer.from(b64, 'base64'); return new Float32Array(b.buffer.slice(b.byteOffset, b.byteOffset + b.byteLength)); };
function stats(f) { let pk = 0, ss = 0; for (const v of f) { const a = Math.abs(v); if (a > pk) pk = a; ss += v * v; } return {pk, rms: Math.sqrt(ss / f.length)}; }
const db = v => (20 * Math.log10(Math.max(v, 1e-9))).toFixed(1);

const sources = {};
for (const f of ['stages/cans.js', 'stages/bowling.js', 'stages/bricks.js', 'stages/fair.js', 'ambience.js']) sources[f] = readFileSync(join(REF, f), 'utf8');
const fw = (await build({entryPoints: [join(REF, 'firework-audio.ts')], bundle: false, write: false, format: 'esm', target: 'es2022'})).outputFiles[0].text;

// Use the preinstalled headless shell if the playwright package expects a different browser build.
const shell = process.env.CHROMIUM_PATH || [1194, 1248].map(v => `/opt/pw-browsers/chromium_headless_shell-${v}/chrome-linux/headless_shell`).find(p => { try { return statSync(p).isFile(); } catch { return false; } });
const browser = await chromium.launch({args: ['--autoplay-policy=no-user-gesture-required'], ...(shell ? {executablePath: shell} : {})});
const page = await browser.newPage();
const JS = {'content-type': 'text/javascript'};
await page.route('http://audio.local/**', route => {
  const p = new URL(route.request().url()).pathname;
  if (p === '/') return route.fulfill({contentType: 'text/html', body: '<!doctype html><script type="module" src="/harness.js"></script>'});
  if (p === '/harness.js') return route.fulfill({headers: JS, body: readFileSync(join(HERE, 'harness.js'), 'utf8')});
  if (p === '/ref/firework-audio') return route.fulfill({headers: JS, body: fw});
  if (p.startsWith('/ref/')) return route.fulfill({headers: JS, body: readFileSync(join(REF, p.slice(5)), 'utf8')});
  return route.fulfill({status: 404, body: ''});
});
page.on('console', m => console.log('[page]', m.text()));
page.on('pageerror', e => console.log('[page error]', e.message));
await page.goto('http://audio.local/');
await page.waitForFunction(() => window.harnessReady === true);

const report = [];
let bad = 0;
for (const s of specs) {
  if (only && !only.test(s.name)) continue;
  const res = await page.evaluate(([spec, src]) => window.render(spec, src), [s, sources]);
  let f = typeof res === 'string' ? f32of(res) : f32of(res.data);
  const srcRate = s.sr || 44100;
  if (s.kind === 'music') { // intro + second loop pass (its start holds the first pass's ringing tails): seamless at loop_offset = intro
    const i0 = Math.round(res.intro * srcRate), L = Math.round(res.loop * srcRate);
    const out = new Float32Array(i0 + L); out.set(f.subarray(0, i0), 0); out.set(f.subarray(i0 + L, i0 + 2 * L), i0); f = out;
    s.note = `intro ${res.intro}s, loop ${res.loop}s (loop_offset=${res.intro})`;
  }
  const orig = stats(f);
  if (s.scale) f = f.map(v => v * s.scale);
  const st = stats(f);
  const tmp = join(TMP, s.name + '.wav'), dst = join(OUT, s.name + (s.ogg ? '.ogg' : '.wav'));
  wavFloat(tmp, f, srcRate);
  const rate = s.rate || 22050;
  const args = s.ogg ? ['-y', '-loglevel', 'error', '-i', tmp, '-ar', String(rate), '-ac', '1', '-c:a', 'libvorbis', '-q:a', '4', dst]
    : ['-y', '-loglevel', 'error', '-i', tmp, '-ar', String(rate), '-ac', '1', '-c:a', 'pcm_s16le', '-map_metadata', '-1', '-fflags', '+bitexact', dst];
  execFileSync('ffmpeg', args);
  rmSync(tmp);
  const dur = f.length / srcRate, silent = st.pk < 1e-3, clip = st.pk >= .999;
  if (silent || clip) bad++;
  const line = `${s.name.padEnd(24)} ${dur.toFixed(3).padStart(7)}s  peak ${db(st.pk).padStart(6)} dBFS  rms ${db(st.rms).padStart(6)} dBFS` +
    (s.scale ? `  (original peak ${db(orig.pk)} dB, x${s.scale})` : '') + `  ${(statSync(dst).size / 1024).toFixed(0)} KB` +
    (silent ? '  SILENT!' : '') + (clip ? '  CLIPPING!' : '') + (s.note ? '  ' + s.note : '');
  console.log(line); report.push(line);
}
await browser.close();
console.log(bad ? `${bad} file(s) silent or clipping` : 'all files non-silent and unclipped');
process.exit(bad ? 1 : 0);
