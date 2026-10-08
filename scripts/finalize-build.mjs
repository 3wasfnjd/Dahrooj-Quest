import { readdir, readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { join } from 'node:path';
async function walk(dir) { const out = []; for (const d of await readdir(dir, { withFileTypes: true })) {
    const p = join(dir, d.name);
    if (d.isDirectory())
        out.push(...await walk(p));
    else
        out.push(p);
} return out; }
const files = (await walk('dist')).filter(p => !p.endsWith('sw.js') && !p.includes('.well-known/')).sort();
const hash = createHash('sha256');
for (const file of files)
    hash.update(await readFile(file));
const version = hash.digest('hex').slice(0, 14);
const urls = files.map(p => '/' + p.slice(5));
const worker = `const CACHE='dahrooj-${version}';const CORE=${JSON.stringify(urls)};self.addEventListener('install',e=>e.waitUntil(caches.open(CACHE).then(c=>c.addAll(CORE))));self.addEventListener('activate',e=>e.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k.startsWith('dahrooj-')&&k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim())));self.addEventListener('fetch',e=>{const u=new URL(e.request.url);if(u.origin!==self.location.origin||e.request.method!=='GET'||u.pathname.startsWith('/.well-known/'))return;e.respondWith(caches.open(CACHE).then(async c=>{if(e.request.mode==='navigate'){try{return await fetch(e.request)}catch{return await c.match(e.request,{ignoreSearch:true,ignoreVary:true})||await c.match('/index.html')||new Response('دحروج غير متاح دون اتصال بعد. Reconnect once to prepare offline play.',{status:503,headers:{'Content-Type':'text/plain;charset=utf-8'}})}}const cached=await c.match(e.request,{ignoreVary:true});if(cached)return cached;try{return await fetch(e.request)}catch{return new Response('Offline asset unavailable',{status:503})}}))});`;
await writeFile('dist/sw.js', worker);
await writeFile('dist/build.json', JSON.stringify({ version, builtAt: new Date().toISOString(), source: process.env.GITHUB_SHA || 'working-tree', iwsdk: '1.0.1', three: 'super-three@0.181.0', physicsHz: 60 }, null, 2));
console.log('Service worker release:', version);
