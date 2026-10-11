import {chromium} from '@playwright/test';
import {spawn} from 'node:child_process';
import {readFile, writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {once} from 'node:events';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const work = path.join(repo, 'quest-package/generated/local/work');
const java = process.env.JAVA_HOME ? path.join(process.env.JAVA_HOME, 'bin/java') : 'java';
const server = spawn(java, ['-cp',path.join(work,'tests'),'com.abodengames.dahrooj.localtest.DesktopServer',path.join(work,'assets'),'0'], {stdio:['ignore','pipe','pipe']});
const report = {runtime:'Packaged APK assets + production Java server + desktop Chromium; NOT Android/Quest', assertions:[], errors:[], externalRequests:[]};
const check = (value,reason) => { if (!value) throw new Error(reason); report.assertions.push(reason); };
let browser;
try {
  const origin = await new Promise((resolve,reject) => {
    const timer = setTimeout(() => reject(new Error('Local server did not start')),15000);
    let output = '';
    server.stdout.on('data',chunk => {
      output += chunk;
      const found = output.match(/http:\/\/127\.0\.0\.1:\d+/);
      if (found) { clearTimeout(timer); resolve(found[0]); }
    });
    server.stderr.on('data',chunk => { output += chunk; });
    server.once('exit',code => { clearTimeout(timer); reject(new Error(`Server exited ${code}: ${output}`)); });
  });
  const inventory = (await readFile(path.join(work,'assets/game-index.tsv'),'utf8')).trim().split('\n').map(line => line.split('\t'));
  for (const [name,size,hash] of inventory) {
    const response = await fetch(`${origin}/${name}`);
    const bytes = Buffer.from(await response.arrayBuffer());
    if (response.status !== 200 || bytes.length !== Number(size) || createHash('sha256').update(bytes).digest('hex') !== hash)
      throw new Error(`Packaged asset HTTP mismatch: ${name}`);
  }
  check(true,`All ${inventory.length} packaged assets served byte-for-byte over loopback`);
  browser = await chromium.launch({executablePath:process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE || undefined,args:['--no-sandbox','--disable-dev-shm-usage','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
  report.browser = browser.version();
  const context = await browser.newContext({viewport:{width:1280,height:900}});
  await context.route('**/*', async route => {
    const url = route.request().url();
    if (/^https?:/.test(url) && !url.startsWith(origin + '/')) {
      report.externalRequests.push(url); await route.abort();
    } else await route.continue();
  });
  const page = await context.newPage();
  page.on('pageerror',error => report.errors.push(error.message));
  page.on('response',response => { if (response.status() >= 400) report.errors.push(`${response.status()} ${response.url()}`); });
  page.on('requestfailed',request => report.errors.push(`${request.url()} ${request.failure()?.errorText}`));
  const response = await page.goto(origin + '/');
  check(response.ok(),'Fresh browser profile loads the bundled entry with external requests blocked');
  await page.waitForFunction(() => document.querySelector('#status')?.textContent.includes('Meta Quest Browser'),{},{timeout:45000});
  await page.waitForFunction(() => navigator.serviceWorker.controller,{},{timeout:15000});
  check(await page.evaluate(() => window.isSecureContext && !!navigator.xr),'Loopback is a secure context and WebXR API is exposed in desktop Chromium');
  check(await page.evaluate(() => !window.IWER_DEVICE && !window.__DAHROOJ_TEST__ && !window.__DAHROOJ_REFERENCE__),'No emulator or development game bridge in the payload');
  check(await page.locator('#enter-vr').isDisabled(),'Desktop without XR hardware does not falsely claim VR support');
  check(await page.evaluate(async () => !(await caches.keys()).some(k=>k.startsWith('dahrooj-'))),'Local service worker does not depend on first-visit precaching');
  await page.evaluate(() => localStorage.setItem('__local_wrapper_test__','saved'));
  await page.reload();
  await page.waitForFunction(() => document.querySelector('#status')?.textContent.includes('Meta Quest Browser'));
  check(await page.evaluate(() => localStorage.getItem('__local_wrapper_test__')==='saved'),'Local save origin survives reload without clearing player storage');
  await page.screenshot({path:path.join(work,'entry.png')});
  await page.goto(origin + '/?xrdiag=1');
  await page.waitForSelector('#render-diagnostics');
  check(true,'Optional diagnostics load from bundled files');
  await page.goto(origin + '/credits.html');
  check((await page.locator('body').innerText()).includes('Aboden Games'),'Bundled rights page remains accessible');
  check(report.errors.length===0,'No browser page or asset loading errors');
  check(report.externalRequests.length===0,'No external game requests during entry, reload, diagnostics or credits');
  report.status='passed';
} catch (error) {
  report.status='failed'; report.failure=String(error); process.exitCode=1;
} finally {
  await browser?.close();
  const stopped = once(server,'exit'); server.kill('SIGTERM');
  if (server.exitCode===null) await stopped;
  await writeFile(path.join(repo,'release/Dahrooj-local-test-v1-browser-report.json'),JSON.stringify(report,null,2));
  console.log(JSON.stringify(report,null,2));
}
