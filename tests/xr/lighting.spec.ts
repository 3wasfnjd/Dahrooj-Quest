/* eslint-disable @typescript-eslint/no-explicit-any -- Production scene exposed only by the development bridge. */
import {test,expect} from '@playwright/test';
// Keep visual captures separate from gameplay checks on software-rendered CI runners.
for(const mode of ['goal','hoop','cans'])test(mode+' target lighting',async({page},info)=>{
 const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text().slice(0,400));});
 await page.goto('/');await page.waitForFunction(()=>!!(window as any).__DAHROOJ_REFERENCE__?.ready);await page.locator('#enter-vr').click();await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.presenting);
 await page.evaluate(mode=>{const r=(window as any).__DAHROOJ_REFERENCE__.game.runtime;r.choosePlaza(r.plaza.ids.indexOf(mode));},mode);
 for(const time of mode==='goal'?['day','dusk','night','dawn']:['day','night']){
  await page.evaluate(time=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.nature.set({time,weather:'clear'}),time);await page.waitForTimeout(300);
  await page.screenshot({path:info.outputPath(mode+'-'+time+'.png')});expect(errors).toEqual([]);
 }
});
