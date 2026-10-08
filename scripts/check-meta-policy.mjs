import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
const baseline = JSON.parse(await readFile('quest-package/meta-baseline.json', 'utf8')), age = (Date.now() - Date.parse(baseline.reviewedOn)) / 86400000;
if (age > 30 || age < -1)
    throw new Error('Meta baseline review is stale. Review current official docs and update the dated baseline before packaging.');
await mkdir('reports/meta-policy', { recursive: true });
const results = [];
for (let i = 0; i < baseline.sources.length; i++) {
    const url = baseline.sources[i], r = await fetch(url, { signal: AbortSignal.timeout(30000) });
    if (!r.ok)
        throw new Error(`Cannot retrieve current Meta policy: ${r.status} ${url}`);
    const text = await r.text();
    if (text.length < 1000 || /access denied|captcha|temporarily blocked/i.test(text))
        throw new Error('Meta policy response could not be verified; manual review is required.');
    await writeFile(`reports/meta-policy/source-${i}.html`, text);
    results.push({ url, status: r.status, retrievedAt: new Date().toISOString(), sha256: createHash('sha256').update(text).digest('hex') });
}
await writeFile('reports/meta-policy/sources.json', JSON.stringify({ baseline, results, interpretation: 'Retrieval evidence only. Does not automate semantic VRC approval; review docs/META-VRC-CHECKLIST-AR.md.' }, null, 2));
