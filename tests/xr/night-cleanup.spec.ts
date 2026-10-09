/* eslint-disable @typescript-eslint/no-explicit-any -- Exercise actual XR world physics and rendering. */
import {test,expect,type Page} from '@playwright/test';

async function start(page:Page,kind:'vr'|'ar'){
 await page.goto('/');await page.waitForFunction(()=>!!(window as any).__DAHROOJ_REFERENCE__?.ready);
 await page.locator('#enter-'+kind).click();await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.presenting);
 if(kind==='ar')await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.testPin([0,0,-2],[0,1,0]));
}

test('automatic four-minute cycle reaches a dark night and returns to day',async({page},info)=>{
 await start(page,'vr');await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.nature.set({time:'auto',weather:'clear'}));
 const sample=(phase:number,weather='clear')=>page.evaluate(({phase,weather})=>{
  const g=(window as any).__DAHROOJ_REFERENCE__.game,r=g.runtime,original=Date.now;
  try{Date.now=()=>240000*(Math.floor(original()/240000)+phase);r.nature.set({time:'auto',weather});r.nature.update(.016,g.ctx.V(0,1.6,0));}
  finally{Date.now=original;}
  const c=g.world.scene.getObjectByName('xr-grass').material.uniforms.uHorizon.value;
  return {night:r.nature.night,horizon:c.r*.2126+c.g*.7152+c.b*.0722,hemi:g.g.hemi.intensity,sun:g.g.sun.intensity};
 },{phase,weather});
 const day=await sample(.08),night=await sample(.47),rain=await sample(.47,'rain'),nextDay=await sample(1.08);
 expect(day.night).toBe(0);expect(night.night).toBe(1);expect(nextDay.night).toBe(0);
 expect(night.horizon).toBeLessThan(day.horizon*.15);expect(rain.horizon).toBeLessThan(day.horizon*.15);
 expect(night.hemi).toBeGreaterThanOrEqual(1.65);expect(night.sun).toBeGreaterThanOrEqual(1.15);
 await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.nature.set({time:'night',weather:'clear'}));
 await page.screenshot({path:info.outputPath('night-goal.png')});
});

for(const kind of ['vr','ar'] as const)test(`hard Dahrooj collisions clear bodies and gentle contact survives in ${kind}`,async({page})=>{
 await start(page,kind);
 async function pair(speed:number){await page.evaluate(speed=>{
  const g=(window as any).__DAHROOJ_REFERENCE__.game,r=g.runtime;
  for(const b of r.rests)b.m?.dispose();r.rests.length=0;g.state.clearVolley();
  // Let two real throws finish through the production rest hook, then arrange the contact fixture.
  for(let i=0;i<2;i++){g.state.respawn();g.S.pos.set(1+i,1,-6);g.state.throwWith(g.ctx.V());g.S.missT=.001;g.state.step(.02);}
  for(let i=0;i<2;i++){const b=r.rests[i];b.p.set(1+(i?1:-1)*.225,.24,-6);b.v.set(i?-speed:speed,0,0);b.wander=100;}
 },speed);}
 await pair(.15);await page.waitForTimeout(250);expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.rests.length)).toBe(2);
 await pair(12);await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.rests.length===0);
 expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.store.data.challenges.pop20||0)).toBe(0);
 expect(await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.blast.sparks.length)).toBeLessThanOrEqual(128);
});

test('crate explosions clear nearby Dahroojs while protecting held and out-of-range bodies',async({page})=>{
 await start(page,'vr');
 await page.evaluate(()=>{
  const g=(window as any).__DAHROOJ_REFERENCE__.game,r=g.runtime,P=r.nature.props,c=P.crates[0];P.reset();
  for(let i=0;i<2;i++){g.state.respawn();g.S.pos.set(1+i,1,-6);g.state.throwWith(g.ctx.V());g.S.missT=.001;g.state.step(.02);}
  r.rests[0].p.set(c.x+1,.5,c.z);r.rests[1].p.set(c.x,15,c.z);for(const b of r.rests){b.v.set(0,0,0);b.wander=100;}
  // A held Dahrooj cannot be consumed by the environment.
  g.S.pos.set(c.x+1,.5,c.z);g.S.shot=true;g.S.held=true;
  P.onExplode(g.S.pos.clone(),3.5,false);
  if(!g.S.held||!g.S.shot)throw Error('The explosion consumed a held ball');
  if(g.store.data.challenges.crates5)throw Error('Ambient explosion granted a player challenge');
  g.S.held=false;g.state.respawn();g.S.pos.set(c.x+1,.5,c.z);g.state.throwWith(g.ctx.V());g.S.missT=.001;g.state.step(.02);
  g.S.pos.set(c.x+1,.5,c.z);g.S.shot=true;g.S.held=true;
  P.explode(0);
 });
 await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.rests.length===1);
 const state=await page.evaluate(()=>{const g=(window as any).__DAHROOJ_REFERENCE__.game;return {height:g.runtime.rests[0].p.y,held:g.S.held,shot:g.S.shot,popped:g.store.data.challenges.pop20||0,crates:g.store.data.challenges.crates5||0};});
 expect(state.height).toBeGreaterThan(5);expect(state.held).toBe(true);expect(state.shot).toBe(true);expect(state.popped).toBe(0);expect(state.crates).toBeGreaterThan(0);
});
