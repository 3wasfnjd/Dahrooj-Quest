/* eslint-disable @typescript-eslint/no-explicit-any -- Exercise the actual world-space picker with IWER input. */
import {test,expect} from '@playwright/test';
for(const kind of ['vr','ar'] as const)test(`compact mode arc stays below view, grows on hover and selects by trigger in ${kind}`,async({page},info)=>{
 const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text().slice(0,400));});
 await page.goto('/');await page.waitForFunction(()=>!!(window as any).__DAHROOJ_REFERENCE__?.ready);
 await page.evaluate(kind=>(window as any).__DAHROOJ_REFERENCE__.game.g.setLang(kind==='vr'?'ar':'en'),kind);
 await page.locator('#enter-'+kind).click();await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.presenting);
 await page.evaluate(kind=>{
  const g=(window as any).__DAHROOJ_REFERENCE__.game,r=g.runtime,controllers=(window as any).IWER_DEVICE.controllers;
  if(kind==='ar')r.testPin([0,0,-2],[0,1,0]);
  for(const hand of ['left','right'])controllers[hand].quaternion.set(Math.SQRT1_2,0,0,Math.SQRT1_2);
  if(kind==='vr')r.nature.set({time:'night',weather:'clear'});
 },kind);
 // Session entry picks up the saved language before drawing the cached labels.
 await page.waitForFunction(lang=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.lang===lang,kind==='vr'?'ar':'en');
 await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.setPlaza(true));
 await page.waitForFunction(()=>{const p=(window as any).__DAHROOJ_REFERENCE__.game.world.scene.getObjectByName('xr-plaza');return p.visible&&p.children.every((c:any)=>c.scale.x>.49&&c.scale.x<.51);});
 const read=()=>page.evaluate(()=>{
  const g=(window as any).__DAHROOJ_REFERENCE__.game,plaza=g.world.scene.getObjectByName('xr-plaza'),head=g.world.player.worldToLocal(g.ctx.V().setFromMatrixPosition(g.world.camera.matrixWorld));
  return {head:head.y,points:plaza.children.map((c:any)=>c.position.toArray()),scales:plaza.children.map((c:any)=>c.scale.x),world:plaza.getWorldPosition(g.ctx.V()).toArray(),rotation:plaza.quaternion.toArray(),flies:g.world.scene.getObjectByName('xr-pole-fireflies')?.geometry.attributes.position.count};
 });
 const initial=await read();expect(initial.points.length).toBe(9);
 for(const p of initial.points){expect(p[1]).toBeCloseTo(initial.head-.44);expect(Math.hypot(p[0],p[2])).toBeCloseTo(1.1);}
 expect(initial.points[0][0]*initial.points[8][0]).toBeLessThan(0);
 expect(initial.points[0][0]<initial.points[8][0]).toBe(kind==='ar');
 if(kind==='vr')expect(initial.flies).toBe(30);
 // A small head turn cannot drag the anchored cards down or sideways.
 await page.evaluate(()=>(window as any).IWER_DEVICE.quaternion.set(0,Math.sin(.06),0,Math.cos(.06)));await page.waitForTimeout(250);
 const turned=await read();expect(turned.points).toEqual(initial.points);expect(turned.world).toEqual(initial.world);expect(turned.rotation).toEqual(initial.rotation);
 await page.screenshot({path:info.outputPath('compact-arc-'+kind+'.png')});
 const target=3;
 await page.evaluate(target=>{
  const g=(window as any).__DAHROOJ_REFERENCE__.game,c=(window as any).IWER_DEVICE.controllers.right,card=g.world.scene.getObjectByName('xr-plaza').children[target];
  const p=g.world.player.worldToLocal(card.getWorldPosition(g.ctx.V())),dir=p.sub(g.ctx.V(c.position.x,c.position.y,c.position.z)).normalize(),q=new g.ctx.T.Quaternion().setFromUnitVectors(g.ctx.V(0,0,-1),dir);
  c.quaternion.set(q.x,q.y,q.z,q.w);
 },target);
 await page.waitForFunction(target=>{const g=(window as any).__DAHROOJ_REFERENCE__.game;return g.runtime.plaza.hot===target&&g.world.scene.getObjectByName('xr-plaza').children[target].scale.x>.87;},target);
 const hovered=await read();expect(hovered.scales[target]).toBeGreaterThan(initial.scales[target]*1.7);
 for(let i=0;i<9;i++)if(i!==target)expect(hovered.scales[i]).toBeLessThan(.52);
 await page.screenshot({path:info.outputPath('hovered-card-'+kind+'.png')});
 await page.evaluate(()=>(window as any).IWER_DEVICE.controllers.right.updateButtonValue('trigger',1));
 await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.g.mode()==='cans');
 await page.evaluate(()=>(window as any).IWER_DEVICE.controllers.right.updateButtonValue('trigger',0));
 await page.waitForFunction(()=>!(window as any).__DAHROOJ_REFERENCE__.game.runtime.plaza.shown);
 expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.S.shot)).toBe(false);expect(errors).toEqual([]);
});
