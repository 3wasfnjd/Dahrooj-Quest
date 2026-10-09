/* eslint-disable @typescript-eslint/no-explicit-any -- Exercise real XR controller events through IWER. */
import {test,expect} from '@playwright/test';
test('menus stop held blaster fire after playing',async({page})=>{
 await page.goto('/');await page.waitForFunction(()=>!!(window as any).__DAHROOJ_REFERENCE__?.ready);await page.locator('#enter-vr').click();await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.presenting);
 await page.evaluate(()=>(window as any).IWER_DEVICE.controllers.left.updateButtonValue('trigger',1));await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.blast.fired>0);
 await page.evaluate(()=>(window as any).IWER_DEVICE.controllers.left.updateButtonValue('x-button',1));await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.menuOpen);
 const before=await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.blast.fired);await page.waitForTimeout(650);
 expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.blast.fired)).toBe(before);
});
test('mode cards ignore old throws and menus stay mutually exclusive',async({page})=>{
 await page.goto('/');await page.waitForFunction(()=>!!(window as any).__DAHROOJ_REFERENCE__?.ready);await page.locator('#enter-vr').click();await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.presenting);
 const button=async(hand:string,id:string)=>{await page.evaluate(({hand,id})=>(window as any).IWER_DEVICE.controllers[hand].updateButtonValue(id,1),{hand,id});await page.waitForTimeout(180);await page.evaluate(({hand,id})=>(window as any).IWER_DEVICE.controllers[hand].updateButtonValue(id,0),{hand,id});await page.waitForTimeout(120);};
 await button('left','y-button');await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.plaza.open);
 await page.evaluate(()=>{const g=(window as any).__DAHROOJ_REFERENCE__.game,p=g.runtime.plazaCardAt(3);g.S.pos.copy(g.world.player.localToWorld(g.ctx.V(...p)));g.state.throwWith(g.ctx.V(0,0,0));});await page.waitForTimeout(450);
 expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.g.mode())).toBe('goal');expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.plaza.open)).toBe(true);
 for(let i=0;i<3;i++){
  await button('left','x-button');await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.challengesOpen);expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.plaza.shown)).toBe(false);
  await button('right','b-button');await page.waitForFunction(()=>{const r=(window as any).__DAHROOJ_REFERENCE__.game.runtime;return r.menuOpen&&!r.challengesOpen;});expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.plaza.open)).toBe(false);
  await button('left','y-button');await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.plaza.open);expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.menuOpen)).toBe(false);
 }
});
test('dragging the challenge list scrolls without throwing',async({page})=>{
 await page.goto('/');await page.waitForFunction(()=>!!(window as any).__DAHROOJ_REFERENCE__?.ready);await page.locator('#enter-vr').click();await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.presenting);
 await page.evaluate(()=>(window as any).IWER_DEVICE.controllers.left.updateButtonValue('x-button',1));await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.world.scene.getObjectByName('xr-menu').scale.x>=.99);await page.evaluate(()=>(window as any).IWER_DEVICE.controllers.left.updateButtonValue('x-button',0));
 const aim=async(y:number,place=false)=>page.evaluate(({y,place})=>{const g=(window as any).__DAHROOJ_REFERENCE__.game,T=g.ctx.T,c=(window as any).IWER_DEVICE.controllers.right,m=g.world.scene.getObjectByName('xr-menu');const target=g.world.player.worldToLocal(m.localToWorld(g.ctx.V(0,y,0)));if(place)c.position.set(target.x+.1,target.y-.15,target.z+.3);const dir=target.sub(g.ctx.V(c.position.x,c.position.y,c.position.z)).normalize(),q=new T.Quaternion().setFromUnitVectors(g.ctx.V(0,0,-1),dir);c.quaternion.set(q.x,q.y,q.z,q.w);},{y,place});
 await aim(.02,true);await page.waitForTimeout(350);await page.evaluate(()=>(window as any).IWER_DEVICE.controllers.right.updateButtonValue('trigger',1));await page.waitForTimeout(200);await aim(.09);await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.challengeScroll.offset>100);
 await page.evaluate(()=>(window as any).IWER_DEVICE.controllers.right.updateButtonValue('trigger',0));await page.waitForTimeout(200);expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.S.shot)).toBe(false);expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.blast.fired)).toBe(0);
});
