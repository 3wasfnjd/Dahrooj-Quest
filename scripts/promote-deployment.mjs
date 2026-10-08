import { readFile, writeFile } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { config } from './deployment-config.mjs';
const c = await config(), raw = (await readFile('reports/staged-deployment-url.txt', 'utf8')).trim(), url = new URL(raw);
if (url.protocol !== 'https:' || !url.hostname.endsWith('.vercel.app') || url.origin !== raw)
    throw new Error('Unexpected staged deployment URL');
const result = execFileSync('vercel', ['curl', '/manifest.webmanifest', '--deployment', raw], { encoding: 'utf8' });
const manifest = JSON.parse(result);
if (manifest.scope !== '/' || manifest.start_url !== '/' || !manifest.icons?.length)
    throw new Error('Staged PWA manifest invalid');
execFileSync('vercel', ['promote', raw, '--yes'], { stdio: 'inherit' });
const response = await fetch(c.origin + '/manifest.webmanifest', { signal: AbortSignal.timeout(20000) });
if (!response.ok)
    throw new Error('Permanent origin is not reachable');
await writeFile('reports/deployment.json', JSON.stringify({ origin: c.origin, deployment: raw, commit: process.env.GITHUB_SHA, status: 'DEPLOYED', checkedAt: new Date().toISOString() }, null, 2));
