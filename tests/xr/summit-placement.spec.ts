/* eslint-disable @typescript-eslint/no-explicit-any -- Test real controller events against the XR runtime. */
import {test,expect,type Page} from '@playwright/test';

async function start(page:Page,mode:'vr'|'ar'){
 await page.goto('/');await page.waitForFunction(()=>!!(window as any).__DAHROOJ_REFERENCE__?.ready);
 await page.locator('#enter-'+mode).click();await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.presenting);
}
async function choose(page:Page,id:string){
 await page.evaluate(id=>{const r=(window as any).__DAHROOJ_REFERENCE__.game.runtime;r.choosePlaza(r.plaza.ids.indexOf(id));},id);
 await page.waitForTimeout(200);
}
async function stick(page:Page,value:number){await page.evaluate(value=>(window as any).IWER_DEVICE.controllers.right.updateAxis('thumbstick','y-axis',value),value);}
async function size(page:Page){return page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.climb.unit as number);}

test('VR Summit keeps the goal court and distance while resizing',async({page},info)=>{
 await start(page,'vr');await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.nature.set({time:'day',weather:'clear'}));
 const court=()=>page.evaluate(()=>{const g=(window as any).__DAHROOJ_REFERENCE__.game,p=g.world.player;return {position:p.position.toArray(),scale:p.scale.toArray(),slabs:g.world.scene.getObjectByName('xr-grass').material.uniforms.uSlab.value.toArray(),target:p.worldToLocal(g.ctx.V(0,0,g.g.stage().aimZ)).toArray()};});
 const goal=await court();await choose(page,'climb');
 expect((await court()).position).toEqual(goal.position);expect((await court()).scale).toEqual(goal.scale);expect((await court()).slabs).toEqual(goal.slabs);
 const position=await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.climb.group.position.toArray());expect(position[2]).toBeCloseTo(goal.target[2],6);
 const initial=await size(page);await stick(page,-1);await expect.poll(()=>size(page)).toBeGreaterThan(initial*1.05);await stick(page,0);
 expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.climb.group.position.toArray())).toEqual(position);
 expect((await court()).slabs).toEqual(goal.slabs);expect((await court()).position).toEqual(goal.position);
 await stick(page,1);await expect.poll(()=>size(page)).toBeLessThan(initial);await stick(page,0);
 await page.screenshot({path:info.outputPath('summit-vr-court.png')});
 // A previous long bowling lane must not change Summit's paving or placement.
 await choose(page,'bowling');await choose(page,'climb');expect((await court()).position).toEqual(goal.position);expect((await court()).slabs).toEqual(goal.slabs);
});

test('AR Summit retains right-stick resize at its confirmed table anchor',async({page},info)=>{
 await start(page,'ar');await choose(page,'climb');
 await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.testPin([.4,.8,-1.6],[0,1,0]));await page.waitForTimeout(300);
 const initial=await size(page);const pose=()=>page.evaluate(()=>{const g=(window as any).__DAHROOJ_REFERENCE__.game;return {position:g.runtime.climb.group.position.toArray(),rig:g.world.player.position.toArray(),anchor:g.runtime.anchor.P.toArray()};});const placed=await pose();
 expect(placed.position).toEqual(placed.anchor);
 await stick(page,-1);await page.waitForTimeout(600);await stick(page,0);await page.waitForTimeout(200);
 const enlarged=await size(page);expect(enlarged).toBeGreaterThan(initial*1.05);await page.waitForTimeout(400);expect(await size(page)).toBeCloseTo(enlarged,8);expect(await pose()).toEqual(placed);
 await page.screenshot({path:info.outputPath('summit-ar-enlarged.png')});
 await stick(page,1);await expect.poll(()=>size(page)).toBeLessThan(initial);await stick(page,0);expect(await pose()).toEqual(placed);
 // Menus own the stick while open; gameplay scale must stay fixed.
 await page.evaluate(()=>(window as any).IWER_DEVICE.controllers.left.updateButtonValue('x-button',1));await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.challengesOpen);await page.evaluate(()=>(window as any).IWER_DEVICE.controllers.left.updateButtonValue('x-button',0));
 const frozen=await size(page);await stick(page,-1);await page.waitForTimeout(350);await stick(page,0);expect(await size(page)).toBe(frozen);
});
