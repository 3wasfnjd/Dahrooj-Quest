/* eslint-disable @typescript-eslint/no-explicit-any -- Inspect actual XR surfaces after controller input. */
import {test,expect} from '@playwright/test';
for(const kind of ['vr','ar'] as const)test(`all unified menu sections remain opaque after playing in ${kind}`,async({page},info)=>{
 const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 await page.goto('/');await page.waitForFunction(()=>!!(window as any).__DAHROOJ_REFERENCE__?.ready);
 await page.evaluate(()=>(window as any).IWER_DEVICE.stereoEnabled=true);
 await page.locator('#enter-'+kind).click();await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.presenting);
 expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.world.renderer.xr.getCamera().cameras.length)).toBe(2);
 await page.evaluate(kind=>{const r=(window as any).__DAHROOJ_REFERENCE__.game.runtime;if(kind==='ar')r.testPin([0,0,-2],[0,1,0]);else r.nature.set({time:'day',weather:'snow'});},kind);
 await page.evaluate(()=>(window as any).IWER_DEVICE.controllers.left.updateButtonValue('trigger',1));
 await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.blast.fired>=3);
 await page.evaluate(()=>(window as any).IWER_DEVICE.controllers.left.updateButtonValue('trigger',0));
 const press=async(hand:string,id:string)=>{
  await page.evaluate(({hand,id})=>(window as any).IWER_DEVICE.controllers[hand].updateButtonValue(id,1),{hand,id});
  await page.waitForTimeout(120);
  await page.evaluate(({hand,id})=>(window as any).IWER_DEVICE.controllers[hand].updateButtonValue(id,0),{hand,id});
 };
 const surfaces=async(name:string)=>page.evaluate(name=>{
  const s=(window as any).__DAHROOJ_REFERENCE__.game.world.scene,root=s.getObjectByName(name),out:any[]=[];
  root.traverse((o:any)=>{if(!o.isMesh||!o.visible)return;const m=o.material,canvas=m.map?.image;
   let interiorAlpha=255;
   if(o.name==='xr-menu'||o.name==='xr-challenge-list'){
    const h=o.name==='xr-menu'?Math.round(canvas.height*m.map.repeat.y):canvas.height;
    const pixels=canvas.getContext('2d').getImageData(80,80,canvas.width-160,h-160).data;
    for(let i=3;i<pixels.length;i+=4)interiorAlpha=Math.min(interiorAlpha,pixels[i]);
   }
   let group=o.parent;while(group&&!group.isGroup)group=group.parent;
   out.push({name:o.name,opaque:m.blending===0&&m.opacity===1,lateQueue:m.transparent,groupOrder:group?.renderOrder,opacity:m.opacity,depthWrite:m.depthWrite,depthTest:m.depthTest,isolated:m.customProgramCacheKey()==='dahrooj-menu-opaque-layer-v2',interiorAlpha});
  });return out;
 },name);
 const solid=(items:any[])=>{expect(items.length).toBeGreaterThan(0);for(const m of items){expect(m.opaque).toBe(true);expect(m.lateQueue).toBe(true);expect(m.groupOrder).toBe(1000);expect(m.opacity).toBe(1);expect(m.depthWrite).toBe(false);expect(m.depthTest).toBe(false);expect(m.isolated).toBe(true);expect(m.interiorAlpha).toBe(255);}};
 await press('right','b-button');
 await page.waitForFunction(()=>{const g=(window as any).__DAHROOJ_REFERENCE__.game;return g.runtime.menuOpen&&!g.runtime.challengesOpen&&g.world.scene.getObjectByName('xr-menu').scale.x>=.99;});
 const settings=await surfaces('xr-menu');solid(settings);
 await page.screenshot({path:info.outputPath('opaque-settings-'+kind+'.png')});
 await press('left','x-button');
 await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.challengesOpen);
 const challenges=await surfaces('xr-menu');solid(challenges);
 const initial=await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.challengeScroll.offset);
 await page.evaluate(()=>{const r=(window as any).__DAHROOJ_REFERENCE__.game.runtime;r.action(r.menuLayout.buttons.findIndex((b:any)=>b.kind==='page'&&b.id==='next'));});
 expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.challengeScroll.offset)).toBe(initial+1);
 solid(await surfaces('xr-menu'));
 await page.screenshot({path:info.outputPath('opaque-challenges-'+kind+'.png')});
 await press('left','y-button');
 await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.plaza.open);
 // All sections retain the same plane, with no alpha fade.
 const opening=await surfaces('xr-plaza');solid(opening);
 await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.world.scene.getObjectByName('xr-plaza').children.every((c:any)=>c.scale.x>=.49));
 const cards=await surfaces('xr-plaza');solid(cards);
 await page.screenshot({path:info.outputPath('opaque-modes-'+kind+'.png')});
 expect(errors).toEqual([]);
 await info.attach('opaque-surfaces',{body:JSON.stringify({settings,challenges,cards:cards.length},null,2),contentType:'application/json'});
});
