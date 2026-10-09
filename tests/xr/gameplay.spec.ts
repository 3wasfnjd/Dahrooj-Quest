/* eslint-disable @typescript-eslint/no-explicit-any -- The legacy JS test boundary intentionally exposes original runtime objects. */
import {test,expect} from '@playwright/test';
import {mkdir,writeFile} from 'node:fs/promises';
// The test bridge is a development-only module; gameplay runs the production reference code.
test('original world, nine modes, five styles, throw controls, projectiles and focus',async({page},info)=>{
 const errors:string[]=[],external:string[]=[];page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text().slice(0,400));});page.on('request',r=>{if(/^https?:/.test(r.url())&&!r.url().startsWith('http://127.0.0.1:5173'))external.push(r.url());});
 await page.goto('/');await page.waitForFunction(()=>!!(window as any).__DAHROOJ_REFERENCE__?.ready);await page.locator('#enter-vr').click();await page.waitForFunction(()=>!!(window as any).__DAHROOJ_REFERENCE__.game.runtime.presenting);
 await page.waitForTimeout(1200);expect(errors).toEqual([]);

 const action=async(kind:string,id:string)=>page.evaluate(({kind,id})=>{const r=(window as any).__DAHROOJ_REFERENCE__.game.runtime;if(kind==='mode'){r.choosePlaza(r.plaza.ids.indexOf(id));return;}const i=r.menuLayout.buttons.findIndex((b:any)=>b.kind===kind&&b.id===id);if(i<0)throw Error('Missing menu item '+id);r.action(i);},{kind,id});
 for(const mode of ['goal','hoop','window','cans','bowling','bricks','fair','climb','rain']){await action('mode',mode);await page.waitForTimeout(350);expect(errors,mode).toEqual([]);}
 await action('mode','goal');
 for(const style of ['jelly','fabric','clay','fur','bubble']){await action('style',style);await page.waitForTimeout(120);}
 for(const method of ['trigger','hand','sling']){await action('throw',method);expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.throwStyle)).toBe(method);}
 await action('throw','trigger');
 await page.evaluate(()=>(window as any).IWER_DEVICE.controllers.right.updateButtonValue('trigger',1));await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.holding);await page.waitForTimeout(500);await page.evaluate(()=>(window as any).IWER_DEVICE.controllers.right.updateButtonValue('trigger',0));await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.S.shot);
 for(const id of ['bolt','mini','bubble','firework']){await action('shot',id);await page.evaluate(()=>(window as any).IWER_DEVICE.controllers.left.updateButtonValue('trigger',1));await page.waitForTimeout(500);await page.evaluate(()=>(window as any).IWER_DEVICE.controllers.left.updateButtonValue('trigger',0));}
 const streak=await page.evaluate(()=>{const g=(window as any).__DAHROOJ_REFERENCE__.game;g.setMode('hoop');g.state.respawn();g.ctx.success();g.state.respawn();g.state.miss();g.state.respawn();g.ctx.success();return g.store.data.challenges.hoop3;});expect(streak).toBe(1);
 await page.evaluate(()=>(window as any).IWER_DEVICE.updateVisibilityState('visible-blurred'));await page.waitForFunction(()=>!(window as any).__DAHROOJ_REFERENCE__.game.focused);const before=await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.state.time);await page.waitForTimeout(350);expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.state.time)).toBe(before);
 await page.evaluate(()=>(window as any).IWER_DEVICE.updateVisibilityState('visible'));await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.focused);
 await page.screenshot({path:info.outputPath('reference-world.png')});await mkdir('reports',{recursive:true});await writeFile('reports/simulator-performance.json',await page.evaluate(()=>JSON.stringify((window as any).__DAHROOJ_REFERENCE__.game.report(),null,2)));expect(errors).toEqual([]);expect(external).toEqual([]);
});
test('original mixed reality placement and session recovery',async({page})=>{
 const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));await page.goto('/');await page.waitForFunction(()=>!!(window as any).__DAHROOJ_REFERENCE__?.ready);await page.locator('#enter-ar').click();await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.placing);
 await page.evaluate(()=>{const r=(window as any).__DAHROOJ_REFERENCE__.game.runtime;r.testPin([0,0,-2],[0,1,0]);});expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.placing)).toBe(false);
 await page.waitForTimeout(500);await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.session.end());await expect(page.locator('#gate')).toBeVisible();await page.locator('#enter-ar').click();await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.placing);expect(errors).toEqual([]);
});
test('scrollable Arabic challenges and bounded world leftovers',async({page},info)=>{
 const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto('/');await page.waitForFunction(()=>!!(window as any).__DAHROOJ_REFERENCE__?.ready);await page.locator('#enter-vr').click();await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.presenting);
 await page.evaluate(()=>{const r=(window as any).__DAHROOJ_REFERENCE__.game.runtime;if(r.lang!=='ar')r.action(r.menuLayout.buttons.findIndex((b:any)=>b.kind==='lang'));(window as any).IWER_DEVICE.controllers.left.updateButtonValue('x-button',1);});
 await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.challengesOpen);await page.evaluate(()=>(window as any).IWER_DEVICE.controllers.left.updateButtonValue('x-button',0));await page.waitForTimeout(600);
 await page.screenshot({path:info.outputPath('challenges-ar-top.png')});
 const textureVersion=await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.world.scene.getObjectByName('xr-challenge-list').material.map.version);
 await page.evaluate(()=>(window as any).IWER_DEVICE.controllers.left.updateAxis('thumbstick','y-axis',1));await page.waitForFunction(()=>{const s=(window as any).__DAHROOJ_REFERENCE__.game.runtime.challengeScroll;return s.max>0&&s.offset===s.max;});await page.evaluate(()=>(window as any).IWER_DEVICE.controllers.left.updateAxis('thumbstick','y-axis',0));
 expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.world.scene.getObjectByName('xr-challenge-list').material.map.version)).toBe(textureVersion);await page.screenshot({path:info.outputPath('challenges-ar-bottom.png')});
 const ids=await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.challengeIds);expect(ids).toContain('skyPop5');expect(ids).not.toContain('pet5');
 const size=await page.evaluate(()=>{const g=(window as any).__DAHROOJ_REFERENCE__.game;g.setMode('goal');for(let i=0;i<20;i++){g.S.pos.set(100,.24,0);g.state.throwWith(g.ctx.V(0,0,-1));g.S.missT=.001;g.state.step(.02);}return g.runtime.rests.length;});expect(size).toBe(8);
 await page.waitForTimeout(13000);expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.rests.length)).toBe(0);expect(errors).toEqual([]);
});
