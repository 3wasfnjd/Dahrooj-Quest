import {describe,it,expect,vi} from 'vitest';
import {readFileSync} from 'node:fs';
import {BufferGeometry,Float32BufferAttribute,Mesh,MeshBasicMaterial,Scene,Vector4,type World} from '@iwsdk/core';
import {AutoQualityPolicy} from '../../src/rendering/auto-quality-policy';
import {automaticLayerScale,automaticViews,automaticQualityEnabled,nativeQualityCeiling} from '../../src/rendering/auto-quality-bridge';
import {attachAutomaticQuality} from '../../src/rendering/automatic-quality';
import {createEnvironmentQuality,dispersedTriangleIndices} from '../../src/rendering/environment-quality';
import {injectQualityHooks} from '../../scripts/renderer-options-plugin';

function drive(policy:AutoQualityPolicy,start:number,duration:number,interval:number,rate=72){
 let time=start;for(;time<start+duration;time+=interval)policy.sample(time,rate);return time;
}

describe('automatic quality policy',()=>{
 it('keeps smooth 72/90/120Hz sessions at maximum quality',()=>{
  for(const rate of [72,90,120]){const policy=new AutoQualityPolicy();drive(policy,0,30000,1000/rate,rate);expect(policy.level).toBe(0);expect(policy.changes).toEqual([]);}
 });
 it('reduces sustained pressure, stays bounded, and recovers only after stability',()=>{
  const policy=new AutoQualityPolicy();let time=drive(policy,0,22000,1000/30);
  expect(policy.level).toBe(4);expect(policy.changes.every(c=>c.reason==='sustained-frame-pressure')).toBe(true);
  time=drive(policy,time,5000,1000/72);expect(policy.level).toBe(4);
  drive(policy,time,65000,1000/72);expect(policy.level).toBeLessThan(4);expect(policy.level).toBeGreaterThanOrEqual(0);
  const recovery=policy.changes.filter(c=>c.reason==='sustained-stable-frames');
  for(let i=1;i<recovery.length;i++)expect(recovery[i].time-recovery[i-1].time).toBeGreaterThanOrEqual(20000);
 });
 it('ignores one hitch, session gaps, mode warmup and refresh changes',()=>{
  const policy=new AutoQualityPolicy();let time=drive(policy,0,3000,1000/72);
  policy.sample(time+100,72);time=drive(policy,time+114,5000,1000/72);expect(policy.level).toBe(0);
  policy.pause(time,4000);time=drive(policy,time,3900,1000/30);expect(policy.level).toBe(0);
  time=drive(policy,time+5000,1000,1000/30);expect(policy.level).toBe(0);
  drive(policy,time,4000,1000/90,90);expect(policy.level).toBe(0);
 });
 it('uses native resolution with a bounded allocation ceiling and preserves manual links',()=>{
  expect(nativeQualityCeiling(1.4)).toBe(1.4);expect(nativeQualityCeiling(9)).toBe(2);
  for(const n of [NaN,Infinity,0,-1])expect(nativeQualityCeiling(n)).toBe(1);
  expect(automaticQualityEnabled('')).toBe(true);expect(automaticQualityEnabled('?xrdiag=1')).toBe(false);
  const native=vi.fn(()=>1.4);expect(automaticLayerScale(10,native)).toBe(10);expect(native).not.toHaveBeenCalled();
 });
 it('hooks actual Three before either eye viewport is read, and fails closed on drift',()=>{
  // The package export used by IWSDK is the built module, not the src copy.
  const source=readFileSync(new URL('../../node_modules/three/build/three.module.js',import.meta.url),'utf8');
  const output=injectQualityHooks(source,'/quality.ts');
  expect(output.indexOf('automaticViews(views, session, time)')).toBeLessThan(output.indexOf('glBaseLayer.getViewport( view )'));
  expect(output).toContain('() => this.getBinding().nativeProjectionScaleFactor');
  expect(()=>injectQualityHooks(source.replace('const views = pose.views;','const views = [];'),'/quality.ts')).toThrow('hook changed');
 });
});

describe('visual-only environmental quality',()=>{
 it('uses stable dispersed subsets of whole triangles',()=>{
  const indices=dispersedTriangleIndices(100);expect(new Set(indices).size).toBe(300);
  expect(indices).toEqual(dispersedTriangleIndices(100));
  for(let i=0;i<indices.length;i+=3){expect(indices[i]%3).toBe(0);expect(indices[i+1]).toBe(indices[i]+1);expect(indices[i+2]).toBe(indices[i]+2);}
  expect(new Set(Array.from(indices.slice(0,75)).map(n=>Math.floor(n/30))).size).toBeGreaterThan(5);
 });
 it('restores geometry and ranges even on render failure and never changes gameplay meshes',()=>{
  const scene=new Scene(),geometry=new BufferGeometry(),material=new MeshBasicMaterial();
  geometry.setAttribute('position',new Float32BufferAttribute(new Float32Array(90),3));
  const grass=new Mesh(geometry,material),weather=new Mesh(geometry.clone(),material),stage=new Mesh(geometry,material);grass.name='xr-grass';weather.name='xr-weather-particles';scene.add(grass,weather,stage);
  const quality=createEnvironmentQuality();
  expect(()=>quality.draw(scene,.4,()=>{
   expect(grass.geometry).not.toBe(geometry);expect(grass.geometry.drawRange.count).toBe(12);
   expect(weather.geometry.drawRange.count).toBe(12);expect(stage.geometry).toBe(geometry);expect(stage.visible).toBe(true);throw Error('draw');
  })).toThrow('draw');
  expect(grass.geometry).toBe(geometry);expect(weather.geometry.drawRange.count).toBe(Infinity);expect(geometry.drawRange.count).toBe(Infinity);
  quality.dispose();geometry.dispose();weather.geometry.dispose();material.dispose();
 });
});

describe('automatic XR integration without headset claims',()=>{
 it('applies the same scale to both views, keeps foveation off, reports dimensions after exit and cleans up',()=>{
  let foveation=.6,frameCallback:()=>void=()=>{};
  const events=new EventTarget(),scene=new Scene(),cameras=[{viewport:new Vector4(0,0,1000,1000)},{viewport:new Vector4(0,0,1000,1000)}];
  const original=vi.fn(),renderer={render:original,domElement:new EventTarget(),xr:{isPresenting:true,getFoveation:()=>foveation,setFoveation:(n:number)=>{foveation=n;},getCamera:()=>({cameras}),getBaseLayer:()=>({textureWidth:1000,textureHeight:1000}),getSession:()=>session,addEventListener:events.addEventListener.bind(events),removeEventListener:events.removeEventListener.bind(events)}};
  const session={visibilityState:'visible',frameRate:72} as XRSession;
  const stop=vi.fn();const world={renderer,scene,onXRFrame:(fn:()=>void)=>{frameCallback=fn;return stop;}} as unknown as World;
  const quality=attachAutomaticQuality(world,()=> 'goal');
  try{
   expect(automaticLayerScale(1,()=>1.5)).toBe(1.5);
   const scales:number[]=[];
   const views=cameras.map((c,index)=>({requestViewportScale:(scale:number)=>{scales[index]=scale;c.viewport.z=c.viewport.w=1000*scale;}})) as unknown as XRView[];
   for(let t=0;t<18000;t+=1000/30){automaticViews(views,session,t);frameCallback();renderer.render(scene,{} as never);}
   expect(scales[0]).toBe(scales[1]);expect(scales[0]).toBeLessThan(1);expect(foveation).toBe(0);
   expect(quality.report().viewportEffect).toBe('observed');expect(quality.report().layer).toEqual({width:1000,height:1000});
   const failingViews=[views[0],{requestViewportScale:(scale:number)=>{if(scale<1)throw Error('unsupported eye');scales[1]=scale;}}] as unknown as XRView[];
   automaticViews(failingViews,session,18001);expect(quality.report().viewportRequestFailed).toBe(true);expect(scales).toEqual([1,1]);
   events.dispatchEvent(new Event('sessionend'));expect(quality.report().layer).toEqual({width:1000,height:1000});
   // A new session resets sampling and handles a missing dynamic API honestly.
   automaticViews([{} as XRView],{...session} as XRSession,19000);renderer.render(scene,{} as never);
   expect(quality.report().dynamicViewportMethodAvailable).toBe(false);
   const unsupportedSession={...session} as XRSession;
   for(let t=20000;t<39000;t+=1000/30){automaticViews([{} as XRView],unsupportedSession,t);renderer.render(scene,{} as never);}
   events.dispatchEvent(new Event('sessionend'));
   expect(quality.report().nextEntryRatios['immersive-vr']).toBeLessThan(1);
   renderer.xr.isPresenting=false;quality.prepare('immersive-vr');
   expect(automaticLayerScale(1,()=>1.5)).toBeLessThan(1.5);
   quality.prepare('immersive-ar');expect(automaticLayerScale(1,()=>1.5)).toBe(1.5);
  }finally{quality.dispose();}
  expect(renderer.render).toBe(original);expect(stop).toHaveBeenCalledOnce();expect(automaticLayerScale(10,()=>1)).toBe(10);
 });
});
