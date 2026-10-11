import {chromium} from '@playwright/test';
import {spawn} from 'node:child_process';
import {readFile, writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {once} from 'node:events';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {build} from 'esbuild';

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const work = process.env.APK_TEST_WORK || path.join(repo, 'quest-package/generated/local/work');
const packageInfo = JSON.parse(await readFile(path.join(work,'assets/package-info.json'),'utf8'));
const reportPath = process.env.APK_BROWSER_REPORT || path.join(repo,`release/Dahrooj-local-test-v${packageInfo.versionCode}-browser-report.json`);
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
  const {outputFiles} = await build({entryPoints:[path.join(repo,'quest-package/local/test/embedded-materials.mjs')],
    bundle:true, write:false, format:'esm', platform:'browser', logLevel:'silent'});
  browser = await chromium.launch({executablePath:process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE || undefined,args:['--no-sandbox','--disable-dev-shm-usage','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
  report.browser = browser.version();
  const context = await browser.newContext({viewport:{width:1280,height:900}});
  await context.route('**/*', async route => {
    const url = route.request().url();
    if (/^https?:/.test(url) && !url.startsWith(origin + '/')) {
      report.externalRequests.push(url); await route.abort();
    } else await route.continue();
  });
  await context.route(origin + '/__test/embedded-materials.js',route => route.fulfill({
    status:200,contentType:'text/javascript',body:outputFiles[0].text}));
  const page = await context.newPage();
  await page.addInitScript(() => {
    window.__cspViolations = [];
    document.addEventListener('securitypolicyviolation',event => window.__cspViolations.push({
      directive:event.effectiveDirective, blockedURI:event.blockedURI}));
  });
  page.on('pageerror',error => report.errors.push(error.message));
  page.on('response',response => { if (response.status() >= 400) report.errors.push(`${response.status()} ${response.url()}`); });
  page.on('requestfailed',request => report.errors.push(`${request.url()} ${request.failure()?.errorText}`));
  const response = await page.goto(origin + '/');
  const csp = response.headers()['content-security-policy'];
  const hostedConfig = JSON.parse(await readFile(path.join(repo,'vercel.json'),'utf8'));
  const hostedCsp = hostedConfig.headers.find(rule => rule.source==='/(.*)').headers.find(header => header.key==='Content-Security-Policy').value;
  check(csp === hostedCsp,'Packaged and hosted content policies match');
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
  const modelNames = inventory.map(([name])=>name).filter(name=>/^assets\/models\/[^/]+\.glb$/.test(name)).map(name=>path.basename(name));
  check(['poleLight.glb','lantern.glb','bench.glb'].every(name=>modelNames.includes(name)),'All three reported models are exercised');
  report.materials = await page.evaluate(async names => {
    const fixture = await import('/__test/embedded-materials.js');
    return fixture.inspectBundledMaterials(names);
  },modelNames);
  report.materialPolicyViolations = await page.evaluate(() => window.__cspViolations);
  for (const model of report.materials) {
    check(model.materials.length>0,`${model.name}: tests actual embedded base-color textures`);
    for (const material of model.materials) {
      check(material.hasMap && material.imageBitmap && material.srgb && material.width>0 && material.height>0
        && material.nonBlackPixels>0 && material.uniqueColors>1,
      `${model.name}/${material.name}: GLTFLoader decodes a colored sRGB ImageBitmap under the production CSP`);
    }
  }
  check(report.materialPolicyViolations.length===0,'No CSP violations while decoding embedded GLB palettes');
  check(report.errors.length===0,'No browser page or asset loading errors');
  check(report.externalRequests.length===0,'No external game requests during entry, reload, diagnostics, credits or model decoding');
  // A separate negative control: permitting local blob images must not permit remote fetches.
  const policyPage = await context.newPage();
  await policyPage.goto(origin + '/credits.html');
  report.externalFetchControl = await policyPage.evaluate(async () => {
    const violation = new Promise((resolve,reject) => {
      const timer = setTimeout(()=>reject(new Error('Remote fetch was not blocked by CSP')),5000);
      document.addEventListener('securitypolicyviolation',event => {
        clearTimeout(timer); resolve({directive:event.effectiveDirective,blockedURI:event.blockedURI});
      },{once:true});
    });
    let rejected = false;
    try { await fetch('https://example.invalid/offline-probe'); } catch { rejected = true; }
    return {rejected,...await violation};
  });
  check(report.externalFetchControl.rejected && report.externalFetchControl.directive==='connect-src'
    && report.externalFetchControl.blockedURI.startsWith('https://example.invalid') && report.externalRequests.length===0,
  'External fetch remains blocked by CSP before any network request');
  await policyPage.close();
  report.status='passed';
} catch (error) {
  report.status='failed'; report.failure=String(error); process.exitCode=1;
} finally {
  await browser?.close();
  const stopped = once(server,'exit'); server.kill('SIGTERM');
  if (server.exitCode===null) await stopped;
  await writeFile(reportPath,JSON.stringify(report,null,2));
  console.log(JSON.stringify(report,null,2));
}
