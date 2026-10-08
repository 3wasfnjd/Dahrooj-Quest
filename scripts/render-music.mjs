// Original Aboden Games score, migrated with the owner's project directive.
// Source: quest@c7925b7cd7371b6bb87c44a0743721ad55f177dd/assets/audio/background-music.js.
// Only the owned note/chord data is reused. New offline synthesis; no legacy runtime.
import { mkdir, writeFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
const A = [[72, -1, 69, 72, 77, -1, 76, 74], [72, -1, 67, -1, 76, -1, 74, 72], [74, -1, 69, 74, 77, -1, 76, 74], [74, 72, 70, -1, 74, -1, 0, 0], [72, -1, 69, 72, 77, -1, 79, 81], [79, -1, 76, -1, 72, -1, 0, 72], [74, 70, 74, 77, 76, -1, 79, -1], [77, -1, -1, -1, 0, 0, 0, 0]];
const B = [[77, -1, 74, -1, 70, -1, 74, 77], [81, -1, 77, -1, 72, -1, 0, 0], [79, 77, 74, 70, 74, -1, 79, -1], [76, -1, 79, -1, 72, -1, 0, 0], [74, 77, 82, -1, 81, 79, 77, 74], [72, -1, 77, -1, 81, -1, 0, 0], [82, 81, 79, 77, 76, -1, 79, -1], [77, -1, -1, -1, 0, 0, 0, 0]];
const chordsA = [[53, 4], [48, 4], [50, 3], [46, 4], [53, 4], [48, 4], [46, 4], [53, 4]], chordsB = [[46, 4], [53, 4], [55, 3], [48, 4], [46, 4], [53, 4], [55, 3], [53, 4]], sampleRate = 32000, beat = 60 / 96, duration = 60, samples = new Float32Array(sampleRate * duration);
function note(midi, at, length, volume, kind = 'pluck') { const hz = 440 * 2 ** ((midi - 69) / 12), start = Math.round(at * sampleRate), n = Math.round(length * sampleRate); for (let j = 0; j < n; j++) {
    const t = j / sampleRate, p = t * hz * Math.PI * 2, envelope = Math.min(1, t * 250) * Math.exp(-t / (kind === 'bass' ? .14 : kind === 'bell' ? .45 : .22));
    const wave = Math.sin(p) + (kind === 'bell' ? .28 * Math.sin(p * 2.76) : .25 * Math.sin(p * 2) + .12 * Math.sin(p * 3));
    samples[(start + j) % samples.length] += wave * envelope * volume;
} }
const bars = [...A, ...B, ...A], chords = [...chordsA, ...chordsB, ...chordsA];
for (let i = 0; i < bars.length; i++) {
    const bar = bars[i], at = i * 4 * beat;
    for (let k = 0; k < 8; k++)
        if (bar[k] > 0) {
            const eighth = Math.floor(k / 2) + (k % 2 ? .58 : 0);
            note(bar[k], at + eighth * beat, .9, .23);
            if (i >= 8 && k % 2 === 0)
                note(bar[k] + 12, at + eighth * beat, 1.5, .055, 'bell');
        }
    const [root, third] = chords[i];
    for (const b of [0, 2])
        note(root - 12 + (b === 2 ? 7 : 0), at + b * beat, .6, .2, 'bass');
    for (const b of [1, 3, 3.58])
        for (const [k, m] of [root + 12, root + 12 + third, root + 19, root + 24].entries())
            note(m, at + b * beat + k * .012, .65, b === 3.58 ? .035 : .06);
}
const pcm = Buffer.alloc(samples.length * 2);
let peak = 0;
for (const s of samples)
    peak = Math.max(peak, Math.abs(s));
for (let i = 0; i < samples.length; i++)
    pcm.writeInt16LE(Math.round(samples[i] / Math.max(1, peak) * 26000), i * 2);
const header = Buffer.alloc(44);
header.write('RIFF', 0);
header.writeUInt32LE(pcm.length + 36, 4);
header.write('WAVEfmt ', 8);
header.writeUInt32LE(16, 16);
header.writeUInt16LE(1, 20);
header.writeUInt16LE(1, 22);
header.writeUInt32LE(sampleRate, 24);
header.writeUInt32LE(sampleRate * 2, 28);
header.writeUInt16LE(2, 32);
header.writeUInt16LE(16, 34);
header.write('data', 36);
header.writeUInt32LE(pcm.length, 40);
await mkdir('reports', { recursive: true });
await mkdir('assets/audio', { recursive: true });
await writeFile('reports/music-master.wav', Buffer.concat([header, pcm]));
const result = spawnSync('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', '-i', 'reports/music-master.wav', '-c:a', 'libvorbis', '-q:a', '2', 'assets/audio/dahrooj-theme.ogg'], { stdio: 'inherit' });
if (result.status !== 0)
    throw new Error('ffmpeg music encoding failed');
console.log('Original 60-second A–B–A score rendered to a local Ogg asset.');
