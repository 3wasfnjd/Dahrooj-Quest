/* eslint-disable @typescript-eslint/no-explicit-any -- Verify spawned positions against the actual IWER headset pose. */
import {test,expect} from '@playwright/test';
for(const kind of ['vr','ar'] as const)test(`Rain falls ahead across both sides and follows later headset turns in ${kind}`,async({page},info)=>{
 const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto('/');await page.waitForFunction(()=>!!(window as any).__DAHROOJ_REFERENCE__?.ready);
 await page.locator('#enter-'+kind).click();await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.presenting);
 await page.evaluate(kind=>{
  const w=window as any,g=w.__DAHROOJ_REFERENCE__.game,r=g.runtime;
  if(kind==='ar')r.testPin([0,0,-2],[0,1,0]);
  const original=r.frame;const seen=new Set<number>();
  w.rainProbe={births:[],turned:false};
  r.frame=(time:number,frame:unknown)=>{
   original(time,frame);
   const player=g.world.player,eye=g.ctx.V().setFromMatrixPosition(g.world.camera.matrixWorld),head=player.worldToLocal(eye.clone());
   const dir=player.worldToLocal(eye.clone().add(g.ctx.V(0,0,-1).transformDirection(g.world.camera.matrixWorld))).sub(head);dir.y=0;dir.normalize();
   for(const b of r.rainSnapshot())if(!seen.has(b.id)){
    seen.add(b.id);const dx=b.p[0]-head.x,dz=b.p[2]-head.z;
    w.rainProbe.births.push({ahead:dx*dir.x+dz*dir.z,side:-dx*dir.z+dz*dir.x,turned:w.rainProbe.turned});
   }
   // Turn while some initial balls are still queued: visible births must use the new heading.
   if(!w.rainProbe.turned&&w.rainProbe.births.length>=12){w.IWER_DEVICE.quaternion.set(0,1,0,0);w.rainProbe.turned=true;}
  };
  r.choosePlaza(r.plaza.ids.indexOf('rain'));
 },kind);
 await page.waitForFunction(()=>(window as any).rainProbe.births.filter((b:any)=>b.turned).length>=25);
 const result=await page.evaluate(()=>({births:(window as any).rainProbe.births,budget:(window as any).__DAHROOJ_REFERENCE__.game.runtime.rain.balls}));
 expect(result.budget).toBe(kind==='vr'?100:72);
 expect(Math.min(...result.births.map((b:any)=>b.ahead))).toBeGreaterThan(.4);
 const later=result.births.filter((b:any)=>b.turned);expect(later.filter((b:any)=>b.side<-.4).length).toBeGreaterThan(1);expect(later.filter((b:any)=>b.side>.4).length).toBeGreaterThan(1);
 expect(errors).toEqual([]);
 if(kind==='vr')await page.screenshot({path:info.outputPath('front-rain.png')});
});
