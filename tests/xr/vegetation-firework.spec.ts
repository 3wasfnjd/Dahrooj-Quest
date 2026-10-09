/* eslint-disable @typescript-eslint/no-explicit-any -- Inspect rendered instancing and real Web Audio voices in IWER. */
import {test,expect} from '@playwright/test';

test('the audited trees and original grass are restored',async({page},info)=>{
 const errors:string[]=[],requests:string[]=[];
 page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});page.on('request',r=>requests.push(r.url()));
 await page.goto('/');await page.waitForFunction(()=>!!(window as any).__DAHROOJ_REFERENCE__?.ready);
 await page.locator('#enter-vr').click();await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.nature?.treesLoaded===3);
 await page.evaluate(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.nature.set({time:'day',weather:'clear'}));
 const data=await page.evaluate(()=>{
  const g=(window as any).__DAHROOJ_REFERENCE__.game,s=g.world.scene,trees:any[]=[];s.traverse((o:any)=>{if(o.name==='xr-trees')trees.push(o);});
  return {loaded:g.runtime.nature.treesLoaded,grass:!!s.getObjectByName('xr-grass'),foliage:!!s.getObjectByName('xr-foliage'),instanced:trees.length===3&&trees.every(t=>t.isInstancedMesh),temporary:!!s.getObjectByName('xr-procedural-trunks')};
 });
 expect(data).toEqual({loaded:3,grass:true,foliage:true,instanced:true,temporary:false});
 for(const file of ['birchTreesVisual.glb','oakTreesVisual.glb','cherryTreesVisual.glb','foliageSDF.png'])expect(requests.some(s=>s.endsWith(file))).toBe(true);
 await page.screenshot({path:info.outputPath('restored-park.png')});expect(errors).toEqual([]);
 await info.attach('restored-vegetation',{body:JSON.stringify(data,null,2),contentType:'application/json'});
});

test('recorded firework cues follow launch and explosion while water suppresses the burst',async({page},info)=>{
 const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 await page.goto('/');await page.waitForFunction(()=>!!(window as any).__DAHROOJ_REFERENCE__?.ready);
 await page.locator('#enter-vr').click();await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.presenting);
 await page.evaluate(()=>{
  const w=window as any,g=w.__DAHROOJ_REFERENCE__.game,r=g.runtime;
  r.action(r.menuLayout.buttons.findIndex((b:any)=>b.kind==='shot'&&b.id==='firework'));
  w.fireworkProbe={launch:0,burst:0,fallback:0,sources:0,voices:0,max:0};
  const context=g.g.audio(),make=context.createBufferSource.bind(context);
  context.createBufferSource=()=>{const source=make();if(!w.fireworkProbe.capturing)return source;
   const start=source.start.bind(source),stop=source.stop.bind(source);let active=false;
   const finish=()=>{if(active){active=false;w.fireworkProbe.voices--;}};
   source.start=(...args:any[])=>{active=true;w.fireworkProbe.sources++;w.fireworkProbe.voices++;w.fireworkProbe.max=Math.max(w.fireworkProbe.max,w.fireworkProbe.voices);start(...args);};
   source.stop=(...args:any[])=>{stop(...args);finish();};source.addEventListener('ended',finish);return source;
  };
  for(const [method,key] of [['fireworkLaunch','launch'],['fireworkBurst','burst']]){const original=g.g[method];g.g[method]=()=>{w.fireworkProbe[key]++;w.fireworkProbe.capturing=true;try{const played=original();if(!played)w.fireworkProbe.fallback++;return played;}finally{w.fireworkProbe.capturing=false;}};}
  w.IWER_DEVICE.controllers.left.quaternion.set(Math.SQRT1_2,0,0,Math.SQRT1_2);
 });
 await page.evaluate(()=>(window as any).IWER_DEVICE.controllers.left.updateButtonValue('trigger',1));
 await page.waitForFunction(()=>(window as any).fireworkProbe.launch>=3);
 await page.evaluate(()=>(window as any).IWER_DEVICE.controllers.left.updateButtonValue('trigger',0));
 await page.waitForFunction(()=>{const w=window as any;return w.fireworkProbe.burst===w.fireworkProbe.launch&&w.fireworkProbe.burst>=3;});
 const dry=await page.evaluate(()=>(window as any).fireworkProbe);expect(dry.fallback).toBe(0);expect(dry.sources).toBe(dry.launch+dry.burst);
 // A real firework shot crossing the pond must fizzle without scheduling an explosion sound.
 await page.evaluate(()=>{const g=(window as any).__DAHROOJ_REFERENCE__.game,r=g.runtime,p=r.nature.pond;
  r.blast.shots.push({kind:'firework',m:null,p:g.ctx.V(p.x,.1,p.z),v:g.ctx.V(0,-12,0),dir:g.ctx.V(0,-1,0),t:0,r:.025,wob:0,look:'jelly',fromIntro:false});
 });
 await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.blast.shots.length===0);
 expect(await page.evaluate(()=>(window as any).fireworkProbe.burst)).toBe(dry.burst);
 await page.waitForTimeout(1100);
 // Stress only the dedicated recorded voices, then verify focus immediately releases them.
 const bounded=await page.evaluate(()=>{const w=window as any,g=w.__DAHROOJ_REFERENCE__.game;w.fireworkProbe.max=0;for(let i=0;i<40;i++)g.g.playAt(g.ctx.V(0,1,0),()=>g.g.fireworkBurst());const max=w.fireworkProbe.max;g.g.focus(false);return {max,remaining:w.fireworkProbe.voices};});
 expect(bounded.max).toBeLessThanOrEqual(12);expect(bounded.remaining).toBe(0);expect(errors).toEqual([]);
 await info.attach('firework-cues',{body:JSON.stringify({dry,bounded},null,2),contentType:'application/json'});
});
