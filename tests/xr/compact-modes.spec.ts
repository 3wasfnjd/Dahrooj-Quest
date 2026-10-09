/* eslint-disable @typescript-eslint/no-explicit-any -- Real controller events on the single world-space UI. */
import {test,expect} from '@playwright/test';
for(const kind of ['vr','ar'] as const)test(`one coloured menu remains anchored and selects by trigger in ${kind}`,async({page})=>{
 const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto('/');await page.waitForFunction(()=>!!(window as any).__DAHROOJ_REFERENCE__?.ready);
 await page.evaluate(kind=>(window as any).__DAHROOJ_REFERENCE__.game.g.setLang(kind==='vr'?'ar':'en'),kind);
 await page.locator('#enter-'+kind).click();await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.presenting);
 await page.evaluate(kind=>{const r=(window as any).__DAHROOJ_REFERENCE__.game.runtime;if(kind==='ar')r.testPin([0,0,-2],[0,1,0]);r.setPlaza(true);},kind);
 const read=()=>page.evaluate(()=>{const g=(window as any).__DAHROOJ_REFERENCE__.game,p=g.world.scene.getObjectByName('xr-plaza');return {children:p.children.length,position:p.position.toArray(),rotation:p.quaternion.toArray(),scale:p.children[0].scale.toArray()};});
 const initial=await read();expect(initial.children).toBe(1);expect(initial.scale).toEqual([1,1,1]);
 await page.evaluate(()=>(window as any).IWER_DEVICE.quaternion.set(0,Math.sin(.06),0,Math.cos(.06)));await page.waitForTimeout(200);expect(await read()).toEqual(initial);
 await page.evaluate(()=>{const g=(window as any).__DAHROOJ_REFERENCE__.game,c=(window as any).IWER_DEVICE.controllers.right;
  const p=g.ctx.V(...g.runtime.plazaCardAt(3)),dir=p.sub(g.ctx.V(c.position.x,c.position.y,c.position.z)).normalize(),q=new g.ctx.T.Quaternion().setFromUnitVectors(g.ctx.V(0,0,-1),dir);c.quaternion.set(q.x,q.y,q.z,q.w);
 });
 await page.waitForTimeout(250);expect(await read()).toEqual(initial);
 await page.evaluate(()=>(window as any).IWER_DEVICE.controllers.right.updateButtonValue('trigger',1));await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.g.mode()==='cans');
 await page.evaluate(()=>(window as any).IWER_DEVICE.controllers.right.updateButtonValue('trigger',0));expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.menuOpen)).toBe(false);expect(errors).toEqual([]);
});
