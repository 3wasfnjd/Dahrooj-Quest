/* eslint-disable @typescript-eslint/no-explicit-any -- Exercise the real scene and cached display textures. */
import {test,expect,type Page} from '@playwright/test';
import {writeFile} from 'node:fs/promises';
async function start(page:Page,kind:'vr'|'ar'){
 await page.goto('/');await page.waitForFunction(()=>!!(window as any).__DAHROOJ_REFERENCE__?.ready);
 await page.locator('#enter-'+kind).click();await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.runtime.presenting);
 await page.evaluate(kind=>{const g=(window as any).__DAHROOJ_REFERENCE__.game;if(kind==='ar')g.runtime.testPin([0,0,-2],[0,1,0]);g.runtime.choosePlaza(g.runtime.plaza.ids.indexOf('fair'));},kind);
}
for(const kind of ['vr','ar'] as const)test(`fair cabinet blocks a full-speed throw in ${kind}`,async({page},info)=>{
 await start(page,kind);
 const state=await page.evaluate(()=>{
  const g=(window as any).__DAHROOJ_REFERENCE__.game,S=g.S;
  g.state.respawn();S.pos.set(0,.5,-7.5);g.state.throwWith(g.ctx.V(0,0,-80));g.state.step(.04);
  const m=g.world.scene.getObjectByName('xr-fair-screen');
  return {z:S.pos.z,vz:S.vel.z,score:g.g.stage().fair.score,screen:{opaque:!m.material.transparent,colorSpace:m.material.map.colorSpace,toneMapped:m.material.toneMapped,version:m.material.map.version,image:m.material.map.image.toDataURL()}};
 });
 expect(state.z).toBeGreaterThan(-8.57);expect(state.vz).toBeGreaterThan(0);expect(state.score).toBe(0);
 expect(state.screen.opaque).toBe(true);expect(state.screen.colorSpace).toBe('srgb');expect(state.screen.toneMapped).toBe(false);
 if(kind==='vr'){
  await writeFile(info.outputPath('fair-retro-screen.png'),Buffer.from(state.screen.image.split(',')[1],'base64'));
  await page.screenshot({path:info.outputPath('fair-vr.png')});
 }
});
test('mode picker keeps depth isolated after gameplay and snow has no animated glitter',async({page},info)=>{
 const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text().slice(0,500));});
 await start(page,'vr');
 await page.evaluate(()=>{
  const g=(window as any).__DAHROOJ_REFERENCE__.game;
  for(let i=0;i<8;i++){g.state.respawn();g.S.pos.set(i*.5,1,-6);g.state.throwWith(g.ctx.V());g.S.missT=.001;g.state.step(.02);}
  g.runtime.nature.set({time:'day',weather:'snow'});g.world.scene.getObjectByName('xr-snow-ground').material.uniforms.snowElevation.value=.35;
  g.runtime.setPlaza(true);
 });
 await page.waitForFunction(()=>(window as any).__DAHROOJ_REFERENCE__.game.world.scene.getObjectByName('xr-plaza').children[0].scale.x>.49);
 const data=await page.evaluate(()=>{
  const g=(window as any).__DAHROOJ_REFERENCE__.game,s=g.world.scene,plaza=s.getObjectByName('xr-plaza'),snow=s.getObjectByName('xr-snow-ground'),rain=s.getObjectByName('xr-weather-particles');
  const materials:any[]=[];plaza.traverse((o:any)=>{if(o.isMesh)materials.push(o.material);});
  return {cards:plaza.children.length,isolated:materials.every(m=>m.customProgramCacheKey()==='dahrooj-menu-depth-v1'),snowDepth:snow.material.depthWrite,particleDepth:rain.material.depthWrite,glitter:snow.material.fragmentShader.includes('pow(glitter'),visible:snow.visible};
 });
 expect(data).toEqual({cards:9,isolated:true,snowDepth:false,particleDepth:false,glitter:false,visible:true});
 await page.screenshot({path:info.outputPath('snow-and-mode-picker.png')});expect(errors).toEqual([]);
});
test('jelly score numerals cover the spectrum in one cached texture',async({page},info)=>{
 await start(page,'vr');
 const data=await page.evaluate(async()=>{
  const source='/src/reference/score-popup.ts';const {createScorePopup}=await import(source);
  const popup=createScorePopup();popup.observe('test',0);popup.observe('test',1234567890);
  const m=popup.root.children[0] as any,version=m.material.map.version,canvas=m.material.map.image as HTMLCanvasElement;
  const pixels=canvas.getContext('2d')!.getImageData(0,0,canvas.width,canvas.height).data,bins=new Set<number>();
  for(let i=0;i<pixels.length;i+=4){const r=pixels[i]/255,g=pixels[i+1]/255,b=pixels[i+2]/255,max=Math.max(r,g,b),min=Math.min(r,g,b),d=max-min;if(pixels[i+3]<200||d<.25)continue;let h=max===r?(g-b)/d:max===g?(b-r)/d+2:(r-g)/d+4;h=(h*60+360)%360;bins.add(Math.floor(h/45));}
  popup.step(.25);popup.observe('test',1234567890);
  return {bins:bins.size,cached:m.material.map.version===version,image:canvas.toDataURL()};
 });
 expect(data.bins).toBe(8);expect(data.cached).toBe(true);
 await writeFile(info.outputPath('rainbow-jelly-digits.png'),Buffer.from(data.image.split(',')[1],'base64'));
});
