import { mkdir, cp, readFile, readdir, writeFile, rm } from 'node:fs/promises';
import { join } from 'node:path';
await rm('public/assets', { recursive:true, force:true });
await mkdir('public/assets', { recursive: true });
for (const kind of ['models', 'textures', 'fonts'])
    await cp(`assets/${kind}`, `public/assets/${kind}`, { recursive: true });
await rm('public/vendor/profiles', { recursive: true, force: true });
const profiles = ['meta-quest-touch-plus', 'meta-quest-touch-plus-v2', 'meta-quest-touch-pro', 'oculus-touch-v2', 'oculus-touch-v3'];
for (const profile of profiles) {
    const from = `node_modules/@webxr-input-profiles/assets/dist/profiles/${profile}`;
    await cp(from, `public/vendor/profiles/${profile}`, { recursive: true });
}
await cp('node_modules/@webxr-input-profiles/assets/LICENSE.md', 'public/licenses/controller-profiles-MIT.txt');
// Include all production dependency notices, including transitive packages.
const lock = JSON.parse(await readFile('package-lock.json', 'utf8')), notices = [], errors = [];
await mkdir('public/licenses/dependencies', { recursive: true });
for (const [path, entry] of Object.entries(lock.packages)) {
    if (!path || entry.dev)
        continue;
    const pkg = JSON.parse(await readFile(join(path, 'package.json'), 'utf8')), files = (await readdir(path)).filter(n => /^(licen[sc]e|copying|notice)([. -]|$)/i.test(n));
    let texts = [];
    for (const file of files) {
        try {
            texts.push(await readFile(join(path, file), 'utf8'));
        }
        catch { }
    }
    if (!texts.length && pkg.name === 'yoga-layout')
        texts.push(await readFile('public/licenses/yoga-layout-MIT.txt', 'utf8'));
    if (!texts.length && pkg.name === '@sentry/server-utils')
        texts.push(await readFile('public/licenses/sentry-server-utils-MIT.txt', 'utf8'));
    if (!texts.length && pkg.name === 'railroad-diagrams')
        texts.push((await readFile(join(path, 'README.md'), 'utf8')).split('License\n-------')[1]);
    const name = `${pkg.name}@${pkg.version}`, license = typeof pkg.license === 'string' ? pkg.license : JSON.stringify(pkg.license);
    if ((!license || !texts.length) && pkg.name !== '@drawcall/uikitml')
        errors.push(name);
    const out = name.replaceAll('/', '_').replaceAll('@', '');
    if (texts.length)
        await writeFile(`public/licenses/dependencies/${out}.txt`, texts.join('\n\n'));
    notices.push({ name: pkg.name, version: pkg.version, license: license || 'UNRESOLVED', notice: texts.length ? `${out}.txt` : null });
}
await writeFile('docs/dependency-licenses.json', JSON.stringify(notices, null, 2) + '\n');
await writeFile('public/licenses/dependencies/index.json', JSON.stringify(notices));
if (errors.length)
    throw new Error('License review required: ' + errors.join(', '));
console.log(`Prepared origin-local assets and ${notices.length} production dependency notices.`);
