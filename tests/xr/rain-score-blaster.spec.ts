/* eslint-disable @typescript-eslint/no-explicit-any -- Observe the real reference runtime and IWER controllers. */
import {test,expect,type Page} from '@playwright/test';
import {writeFile} from 'node:fs/promises';

async function start(page:Page,kind:'vr'|'ar'){
 await page.goto('/');await page.waitForFunction(()=>!!(window as any).__DAHROOJ_REFERENCE__?.ready);
 await page.locator('#enter-'+kind).click();await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.presenting);
}
async function choose(page:Page,id:string){await page.evaluate(id=>{const r=(window as any).__DAHROOJ_REFERENCE__.game.runtime;r.choosePlaza(r.plaza.ids.indexOf(id));},id);await page.waitForTimeout(200);}

for(const kind of ['vr','ar'] as const)test(`Rain accessories stay instanced and bounded in ${kind}`,async({page},info)=>{
 const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));
 await start(page,kind);await choose(page,'rain');
 await page.waitForFunction(n=>{const r=(window as any).__DAHROOJ_REFERENCE__.game.runtime.rain;return r.balls===n&&r.drawn>=Math.floor(n/3);},kind==='vr'?100:72);
 const data=await page.evaluate(()=>{
  const g=(window as any).__DAHROOJ_REFERENCE__.game,children=g.world.scene.getObjectByName('xr-intro').children;
  const parts=children.filter((m:any)=>m.name.startsWith('xr-rain-accessory-'));
  return {drawn:g.runtime.rain.drawn,parts:parts.map((m:any)=>({name:m.name,count:m.count,instanced:m.isInstancedMesh})),wearing:g.runtime.wearing};
 });
 expect(data.drawn).toBeLessThanOrEqual(kind==='vr'?100:72);expect(data.wearing).toBe('');expect(data.parts.length).toBe(10);expect(data.parts.every((m:any)=>m.instanced)).toBe(true);
 expect(data.parts.filter((m:any)=>m.name.endsWith('-0')).reduce((n:number,m:any)=>n+m.count,0)).toBe(data.drawn);
 for(const id of ['party','glasses','cap','flower','crown']){
  const parts=data.parts.filter((m:any)=>m.name.includes(`-${id}-`));expect(parts[0].count).toBe(parts[1].count);
 }
 expect(errors).toEqual([]);
 if(kind==='vr')await page.screenshot({path:info.outputPath('rain-accessories.png')});
});

test('score is glossy digits that animate once per increase and then disappear',async({page},info)=>{
 await start(page,'vr');await choose(page,'goal');
 const score=()=>page.evaluate(()=>{const m=(window as any).__DAHROOJ_REFERENCE__.game.world.scene.getObjectByName('xr-score-popup');return {visible:m.visible,value:m.userData.value,version:m.children[0].material.map.version,plaque:m.parent.material.visible};});
 expect((await score()).visible).toBe(false);expect((await score()).plaque).toBe(false);
 await page.evaluate(()=>{const g=(window as any).__DAHROOJ_REFERENCE__.game;g.state.respawn();g.ctx.success();});
 await page.waitForFunction(()=>{const m=(window as any).__DAHROOJ_REFERENCE__.game.world.scene.getObjectByName('xr-score-popup');return m.visible&&m.children[0].material.opacity>.95;});
 expect((await score()).value).toBe(1);
 const version=(await score()).version;
 const image=await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.world.scene.getObjectByName('xr-score-popup').children[0].material.map.image.toDataURL());
 await writeFile(info.outputPath('jelly-digits.png'),Buffer.from(image.split(',')[1],'base64'));
 await page.evaluate(()=>(window as any).IWER_DEVICE.updateVisibilityState('visible-blurred'));
 await page.screenshot({path:info.outputPath('jelly-score-vr.png')});
 await page.evaluate(()=>(window as any).IWER_DEVICE.updateVisibilityState('visible'));
 await expect.poll(async()=>(await score()).visible,{timeout:20000}).toBe(false);
 expect((await score()).version).toBe(version);
 await page.evaluate(()=>{const g=(window as any).__DAHROOJ_REFERENCE__.game;g.state.respawn();g.ctx.success();});
 await expect.poll(async()=>(await score()).value).toBe(2);expect((await score()).visible).toBe(true);
 // Returning to a mode with an old score must not celebrate it again.
 await choose(page,'cans');await choose(page,'goal');await page.waitForTimeout(200);expect((await score()).visible).toBe(false);
 await choose(page,'climb');await page.waitForTimeout(200);expect((await score()).plaque).toBe(true);
});

test('holding the mini blaster keeps a steady cadence beyond the 16-shot budget',async({page})=>{
 await start(page,'ar');await choose(page,'goal');
 await page.evaluate(()=>{
  const w=window as any,g=w.__DAHROOJ_REFERENCE__.game,r=g.runtime,T=g.ctx.T;
  r.testPin([0,0,-2],[0,1,0]);r.action(r.menuLayout.buttons.findIndex((b:any)=>b.kind==='shot'&&b.id==='mini'));
  const c=w.IWER_DEVICE.controllers.left,q=new T.Quaternion().setFromAxisAngle(g.ctx.V(1,0,0),Math.PI/2);
  c.position.set(-.4,1.6,.2);c.quaternion.set(q.x,q.y,q.z,q.w);
  const frame=r.frame;let last=0,elapsed=0,fired=r.blast.fired;
  w.fireProbe={times:[],maxBodies:0};
  r.frame=(time:number,xr:unknown)=>{
   frame(time,xr);elapsed+=last?Math.min(.05,Math.max(0,(time-last)/1000)):1/72;last=time;
   const probe=w.fireProbe;probe.maxBodies=Math.max(probe.maxBodies,r.blast.shots.length);
   if(r.blast.fired!==fired){fired=r.blast.fired;if(probe.times.length<50)probe.times.push(elapsed);}
  };
  c.updateButtonValue('trigger',1);
 });
 await page.waitForFunction(()=>(window as any).fireProbe.times.length>=40,null,{timeout:60000});
 await page.evaluate(()=>(window as any).IWER_DEVICE.controllers.left.updateButtonValue('trigger',0));
 const probe=await page.evaluate(()=>(window as any).fireProbe);
 expect(probe.maxBodies).toBe(16);
 const gaps=probe.times.slice(1).map((t:number,i:number)=>t-probe.times[i]);expect(Math.max(...gaps)).toBeLessThan(.21);
 const fired=await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.blast.fired);await page.waitForTimeout(800);
 expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.blast.fired)).toBe(fired);
});
