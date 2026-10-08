import { mkdir, writeFile } from 'node:fs/promises';
import { config, fingerprint } from './deployment-config.mjs';
const c = await config(), sha = fingerprint(process.env.ANDROID_CERT_SHA256);
const links = [{ relation: ['delegate_permission/common.handle_all_urls'], target: { namespace: 'android_app', package_name: c.packageId, sha256_cert_fingerprints: [sha] } }];
if (process.argv.includes('--verify')) {
    const response = await fetch(c.origin + '/.well-known/assetlinks.json', { redirect: 'error', signal: AbortSignal.timeout(20000), cache: 'no-store' });
    if (!response.ok || !response.headers.get('content-type')?.includes('json'))
        throw new Error('Digital Asset Links is not public JSON with HTTP 200');
    const remote = await response.json();
    if (!Array.isArray(remote) || !remote.some(item => item.target?.namespace === 'android_app' && item.target.package_name === c.packageId && item.relation?.includes('delegate_permission/common.handle_all_urls') && item.target.sha256_cert_fingerprints?.some(f => fingerprint(f) === sha)))
        throw new Error('Digital Asset Links package or certificate does not match');
    await mkdir('reports', { recursive: true });
    await writeFile('reports/digital-asset-links.json', JSON.stringify({ status: 'PASS', origin: c.origin, packageId: c.packageId, fingerprint: sha, checkedAt: new Date().toISOString() }, null, 2));
    console.log('Digital Asset Links verified.');
}
else {
    await mkdir('public/.well-known', { recursive: true });
    await writeFile('public/.well-known/assetlinks.json', JSON.stringify(links, null, 2) + '\n');
    console.log('Generated Digital Asset Links for the configured certificate.');
}
