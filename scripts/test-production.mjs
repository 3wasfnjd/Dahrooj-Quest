import { chromium } from '@playwright/test';
import { preview } from 'vite';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
const headers = Object.fromEntries(JSON.parse(await readFile('vercel.json', 'utf8')).headers[0].headers.map(h => [h.key, h.value]));
const server = await preview({ configFile: false, build: { outDir: 'dist' }, preview: { host: '127.0.0.1', port: 4173, strictPort: true, headers } });
await mkdir('reports/production', { recursive: true });
const result = { runtime: 'Chromium production WebGL2 entry/offline test; not Quest hardware', browser: '', assertions: [], errors: [], externalRequests: [] };
let browser;
function check(value, description) { if (!value)
    throw new Error(description); result.assertions.push(description); }
try {
    browser = await chromium.launch({ executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE || undefined, args: ['--no-sandbox', '--disable-dev-shm-usage', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
    result.browser = browser.version();
    const context = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    const page = await context.newPage();
    page.on('pageerror', e => result.errors.push(e.message));
    page.on('console', m => { if (m.type() === 'error')
        result.errors.push(m.text().slice(0, 500)); });
    page.on('request', r => { if (/^https?:/.test(r.url()) && !r.url().startsWith('http://127.0.0.1:4173'))
        result.externalRequests.push(r.url()); });
    page.on('response', r => { if (r.status() >= 400)
        result.errors.push(r.status() + ' ' + r.url()); });
    page.on('requestfailed', r => result.errors.push(r.url() + ' ' + r.failure()?.errorText));
    const response = await page.goto('http://127.0.0.1:4173/');
    check(response.headers()['content-security-policy'] === headers['Content-Security-Policy'], 'Production CSP is served');
    await page.waitForFunction(() => navigator.serviceWorker.controller, { timeout: 30000 });
    check(await page.evaluate(() => !window.IWER_DEVICE && !window.__DAHROOJ_TEST__ && !window.__DAHROOJ_REFERENCE__), 'No IWER runtime or development bridge');
    check(await page.locator('#enter-vr').isDisabled(), 'No desktop gameplay fallback');
    await page.screenshot({ path: 'reports/production/entry.png' });
    await context.setOffline(true);
    await page.reload({ waitUntil: 'networkidle' });
    await page.waitForFunction(() => !document.querySelector('#status').textContent.includes('جارٍ تجهيز'));
    check(await page.locator('#gate').isVisible(), 'Offline reload renders the entry page');
    const cached = await page.evaluate(async () => { const names = await caches.keys(); const c = await caches.open(names.find(n => n.startsWith('dahrooj-'))); return (await c.keys()).length; });
    check(cached > 25, 'Core application assets were precached');
    result.cachedFiles = cached;
    await page.goto('http://127.0.0.1:4173/privacy.html');
    check((await page.locator('h1').first().textContent()).includes('سياسة الخصوصية'), 'Privacy policy remains accessible offline');
    await page.screenshot({ path: 'reports/production/offline-privacy.png' });
    check(result.errors.length === 0, 'No browser errors under production CSP');
    check(result.externalRequests.length === 0, 'No external runtime requests');
    result.status = 'passed';
}
catch (error) {
    result.status = 'failed';
    result.failure = String(error);
    process.exitCode = 1;
}
finally {
    await browser?.close();
    server.httpServer.close();
    await writeFile('reports/production-tests.json', JSON.stringify(result, null, 2));
    console.log(JSON.stringify(result, null, 2));
}
