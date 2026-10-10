/* eslint-disable @typescript-eslint/no-explicit-any -- Exercise real XR controller events through IWER. */
import {test,expect} from '@playwright/test';
test('menus stop held blaster fire after playing',async({page})=>{
 await page.goto('/');await page.waitForFunction(()=>!!(window as any).__DAHROOJ_REFERENCE__?.ready);await page.locator('#enter-vr').click();await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.presenting);
 await page.evaluate(()=>(window as any).IWER_DEVICE.controllers.left.updateButtonValue('trigger',1));await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.blast.fired>0);
 await page.evaluate(()=>(window as any).IWER_DEVICE.controllers.left.updateButtonValue('x-button',1));await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.menuOpen);
 const before=await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.blast.fired);await page.waitForTimeout(650);
 expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.blast.fired)).toBe(before);
});
test('the unified menu ignores old throws and switches sections on one surface',async({page})=>{
 // Repeated menu cycles exceed 180s under software rendering on hosted CI; this is not a frame-rate gate.
 test.setTimeout(process.env.CI?300000:90000);
 await page.goto('/');await page.waitForFunction(()=>!!(window as any).__DAHROOJ_REFERENCE__?.ready);await page.locator('#enter-vr').click();await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.presenting);
 const button=async(hand:string,id:string)=>{await page.evaluate(({hand,id})=>(window as any).IWER_DEVICE.controllers[hand].updateButtonValue(id,1),{hand,id});await page.waitForTimeout(180);await page.evaluate(({hand,id})=>(window as any).IWER_DEVICE.controllers[hand].updateButtonValue(id,0),{hand,id});await page.waitForTimeout(120);};
 await button('left','y-button');await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.plaza.open);
 await page.evaluate(()=>{const g=(window as any).__DAHROOJ_REFERENCE__.game,p=g.runtime.plazaCardAt(3);g.S.pos.copy(g.world.player.localToWorld(g.ctx.V(...p)));g.state.throwWith(g.ctx.V(0,0,0));});await page.waitForTimeout(450);
 expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.g.mode())).toBe('goal');expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.plaza.open)).toBe(true);
 for(let i=0;i<3;i++){
  await button('left','x-button');await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.challengesOpen);expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.plaza.shown)).toBe(true);
  await button('right','b-button');await page.waitForFunction(()=>{const r=(window as any).__DAHROOJ_REFERENCE__.game.runtime;return r.menuOpen&&!r.challengesOpen;});expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.plaza.open)).toBe(false);
  await button('left','y-button');await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.plaza.open);expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.menuOpen)).toBe(true);
 }
});
test('challenge scrolling never throws a ball',async({page})=>{
 await page.goto('/');await page.waitForFunction(()=>!!(window as any).__DAHROOJ_REFERENCE__?.ready);await page.locator('#enter-vr').click();await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.presenting);
 await page.evaluate(()=>{const r=(window as any).__DAHROOJ_REFERENCE__.game.runtime;r.setMenu(true,'challenges');r.action(r.menuLayout.buttons.findIndex((b:any)=>b.kind==='scrollStep'&&b.id==='down'));});
 expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.challengeScroll.offset)).toBeGreaterThan(0);
 expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.S.shot)).toBe(false);expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.blast.fired)).toBe(0);
});
