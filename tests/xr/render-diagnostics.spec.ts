/* eslint-disable @typescript-eslint/no-explicit-any -- Inspect actual render calls and controller input in IWER, not hardware evidence. */
import {test,expect} from '@playwright/test';
import {readFile} from 'node:fs/promises';

test('normal play never loads or displays the optional diagnostic UI',async({page})=>{
 const requests:string[]=[];page.on('request',r=>requests.push(r.url()));
 await page.goto('/?xrdiagStereo=separate&xrdiagAA=0');await page.waitForFunction(()=>!!(window as any).__DAHROOJ_REFERENCE__?.ready);
 expect(await page.locator('#render-diagnostics').count()).toBe(0);
 expect(requests.some(url=>url.includes('/render-diagnostics.ts'))).toBe(false);
 expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.world.renderer.getContext().getContextAttributes().antialias)).toBe(true);
});

for(const kind of ['vr','ar'])test(`${kind}: isolate goal, hoop and window while retaining menus, two views and state`,async({page},info)=>{
 test.setTimeout(180000);const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 await page.goto('/?xrdiag=1&xrdiagStereo=separate&xrdiagAA=0');await page.waitForFunction(()=>!!(window as any).__DAHROOJ_REFERENCE__?.ready);
 await expect(page.locator('#render-diagnostics')).toBeVisible();
 await page.evaluate(()=>{(window as any).IWER_DEVICE.stereoEnabled=true;});
 await page.locator('#enter-'+kind).click();await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.presenting);
 await page.evaluate(kind=>{const g=(window as any).__DAHROOJ_REFERENCE__.game;if(kind==='ar')g.runtime.testPin([0,0,-2],[0,1,0]);else g.runtime.nature.set({time:'day',weather:'snow'});
  const scene=g.world.scene;scene.onBeforeRender=()=>{const state=g.inspectRendering();(window as any).__RENDER_MASK__={stage:state.stage?.visible,menu:scene.getObjectByName('xr-menu-layer').visible,nature:state.nature?.visible,particles:scene.getObjectByName('xr-weather-particles')?.visible,depth:scene.getObjectByName('xr-menu').material.depthTest};};
 },kind);
 const choose=async(id:string)=>{await page.evaluate(id=>{const s=document.querySelector<HTMLSelectElement>('#diag-preset')!;s.value=id;s.dispatchEvent(new Event('change'));},id);};
 const button=async(side:string,id:string)=>{await page.evaluate(({side,id})=>(window as any).IWER_DEVICE.controllers[side].updateButtonValue(id,1),{side,id});await page.waitForTimeout(180);await page.evaluate(({side,id})=>(window as any).IWER_DEVICE.controllers[side].updateButtonValue(id,0),{side,id});await page.waitForTimeout(120);};
 for(const mode of ['goal','hoop','window']){
  await choose('baseline');await page.evaluate(mode=>(window as any).__DAHROOJ_REFERENCE__.game.setMode(mode),mode);
  await button('right','b-button');await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.menuOpen);
  await choose('no-stage');await page.waitForFunction(()=>(window as any).__RENDER_MASK__?.stage===false);
  expect(await page.evaluate(()=>(window as any).__RENDER_MASK__.menu)).toBe(true);
  // The mask must already have been restored when the game is observed between frames.
  expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.g.stage().grp.visible)).toBe(true);
  await choose('baseline');await page.waitForFunction(()=>(window as any).__RENDER_MASK__.stage===true);
  await button('left','x-button');await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.challengesOpen);
  await choose('no-menu-depth');await page.waitForFunction(()=>(window as any).__RENDER_MASK__.depth===false);
  expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.world.scene.getObjectByName('xr-menu').material.depthTest)).toBe(true);
  await choose('baseline');await button('left','y-button');await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.plaza.open);
  await choose('no-menus');await page.waitForFunction(()=>(window as any).__RENDER_MASK__.menu===false);
  await choose('baseline');await button('left','y-button');
 }
 if(kind==='vr'){
  await choose('no-particles');await page.waitForFunction(()=>(window as any).__RENDER_MASK__.particles===false);
  expect(await page.evaluate(()=>(window as any).__RENDER_MASK__.nature)).toBe(true);
  await choose('no-nature');await page.waitForFunction(()=>(window as any).__RENDER_MASK__.nature===false);
 }
 await choose('no-foveation');await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.world.renderer.xr.getFoveation()===0);
 await choose('baseline');await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.world.renderer.xr.getFoveation()===.6);
 await button('left','thumbstick');expect(await page.locator('#diag-preset').inputValue()).toBe('no-world');
 // Holding a stick click cannot keep advancing the comparison.
 await page.evaluate(()=>(window as any).IWER_DEVICE.controllers.left.updateButtonValue('thumbstick',1));await page.waitForTimeout(600);
 expect(await page.locator('#diag-preset').inputValue()).toBe('no-particles');
 await page.evaluate(()=>(window as any).IWER_DEVICE.controllers.left.updateButtonValue('thumbstick',0));
 await button('right','thumbstick');
 await page.screenshot({path:info.outputPath('diagnostics-'+kind+'.png')});
 await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.world.renderer.xr.getSession().end());await expect(page.locator('#gate')).toBeVisible();
 const downloaded=page.waitForEvent('download');await page.locator('#diag-export').click();const download=await downloaded;
 const report=JSON.parse(await readFile((await download.path())!,'utf8'));
 expect(report.options).toEqual({enabled:true,stereo:'separate',antialias:false});expect(report.hardwareConfirmation).toBeNull();
 expect(report.lastXR.viewCount).toBe(2);expect(report.lastXR.actualMultiview).toBe(false);expect(report.lastXR.context.antialias).toBe(false);
 expect(report.lastXR.views[0].position).not.toEqual(report.lastXR.views[1].position);
 expect(report.observations).toHaveLength(1);expect(report.observations[0].state.kind).toBe('immersive-'+kind);
 for(const mode of ['goal','hoop','window'])expect(report.runs.some((run:any)=>run.mode===mode&&run.preset==='no-stage'&&run.frames>0)).toBe(true);
 expect(errors).toEqual([]);await info.attach('diagnostic-report',{body:JSON.stringify(report,null,2),contentType:'application/json'});
 // Re-entering must neither duplicate the panel nor retain render masks.
 await page.locator('#diag-preset').selectOption('baseline');await page.locator('#enter-'+kind).click();await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.presenting);
 expect(await page.locator('#render-diagnostics').count()).toBe(1);await page.waitForFunction(()=>(window as any).__RENDER_MASK__.stage===true);
});
