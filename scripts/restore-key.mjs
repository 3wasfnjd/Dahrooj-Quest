import { writeFile, mkdir } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { fingerprint } from './deployment-config.mjs';
for (const key of ['ANDROID_KEYSTORE_BASE64', 'ANDROID_KEYSTORE_PASSWORD', 'ANDROID_KEY_ALIAS'])
    if (!process.env[key])
        throw new Error(`GitHub secret ${key} is missing. A temporary key must not replace the release certificate.`);
const path = process.env.RUNNER_TEMP + '/dahrooj-release.keystore';
await writeFile(path, Buffer.from(process.env.ANDROID_KEYSTORE_BASE64, 'base64'), { mode: 0o600 });
const output = execFileSync('keytool', ['-list', '-v', '-keystore', path, '-alias', process.env.ANDROID_KEY_ALIAS, '-storepass:env', 'ANDROID_KEYSTORE_PASSWORD'], { encoding: 'utf8', env: { ...process.env, LANG: 'C.UTF-8' } });
const found = output.match(/SHA256:\s*([A-Fa-f0-9:]+)/);
if (!found || fingerprint(found[1]) !== fingerprint(process.env.ANDROID_CERT_SHA256))
    throw new Error('Signing certificate differs from configured Digital Asset Links fingerprint');
await mkdir('reports', { recursive: true });
await writeFile('reports/signing-certificate.json', JSON.stringify({ certificateSHA256: fingerprint(found[1]), verified: true, privateKeyIncluded: false }, null, 2));
console.log('Permanent certificate restored and matched.');
