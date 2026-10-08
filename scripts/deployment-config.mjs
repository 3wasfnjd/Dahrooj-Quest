import { readFile } from 'node:fs/promises';
export async function config({ signing = false } = {}) { const app = JSON.parse(await readFile('quest-package/app-config.json', 'utf8')); app.origin = process.env.APP_ORIGIN || app.origin; app.metaApplicationId = process.env.META_APP_ID || app.metaApplicationId; if (!app.origin)
    throw new Error('APP_ORIGIN is missing. Configure the permanent HTTPS origin in GitHub repository variables.'); const url = new URL(app.origin); if (url.protocol !== 'https:' || url.origin !== app.origin || url.hostname === 'localhost' || url.pathname !== '/')
    throw new Error('APP_ORIGIN must be an exact permanent HTTPS origin without a path or trailing slash.'); if (app.packageId !== 'com.abodengames.dahrooj')
    throw new Error('Unexpected package identity. Review the permanent app identity before changing it.'); if (signing && !/^[1-9]\d{4,}$/.test(app.metaApplicationId || ''))
    throw new Error('META_APP_ID must identify the new Meta application. A placeholder is forbidden.'); return app; }
export function fingerprint(value) { const v = String(value || '').replaceAll(':', '').trim().toUpperCase(); if (!/^[A-F0-9]{64}$/.test(v))
    throw new Error('Expected a real SHA-256 signing certificate fingerprint'); return v.match(/.{2}/g).join(':'); }
