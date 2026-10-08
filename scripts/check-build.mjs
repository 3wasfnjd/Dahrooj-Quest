import { readdir, readFile, stat, mkdir, writeFile } from 'node:fs/promises';
import { gzipSync } from 'node:zlib';
import { join } from 'node:path';
async function walk(dir) { const out = []; for (const d of await readdir(dir, { withFileTypes: true })) {
    const p = join(dir, d.name);
    if (d.isDirectory())
        out.push(...await walk(p));
    else
        out.push(p);
} return out; }
const modules = JSON.parse(await readFile('reports/bundled-modules.json', 'utf8'));
if (modules.some(p => /^iwer\/|@iwsdk\/devtools|src\/platform\/(emulator|development)\.ts/.test(p)))
    throw new Error('Development runtime entered the production bundle');
if (modules.some(p => p.startsWith('@drawcall/uikitml/')))
    throw new Error('Unlicensed UIKitML fork must not enter the shipped bundle');
const files = await walk('dist'), report = { bytes: 0, gzipBytes: 0, javascriptBytes: 0, assets: [], errors: [] };
for (const f of files) {
    const data = await readFile(f), bytes = (await stat(f)).size;
    report.bytes += bytes;
    report.gzipBytes += gzipSync(data).length;
    if (f.endsWith('.js'))
        report.javascriptBytes += bytes;
    if (!f.startsWith('dist/licenses/') && /iwer|simulator|living_room|__DAHROOJ_TEST__|\.map$|test-results|playwright/i.test(f))
        report.errors.push('Development artifact: ' + f);
    if (f.endsWith('.js')) {
        const text = data.toString();
        if (text.includes('__DAHROOJ_TEST__') || text.includes('new XRDevice('))
            report.errors.push('Development code: ' + f);
    }
    report.assets.push({ file: f, bytes });
}
if (report.bytes > 24 * 1024 * 1024)
    report.errors.push('Web bundle exceeds 24 MiB uncompressed budget');
if (report.javascriptBytes > 8 * 1024 * 1024)
    report.errors.push('JavaScript exceeds 8 MiB budget');
await mkdir('reports', { recursive: true });
await writeFile('reports/bundle-size.json', JSON.stringify(report, null, 2));
console.log(JSON.stringify({ ...report, assets: `${report.assets.length} files` }, null, 2));
if (report.errors.length)
    process.exitCode = 1;
