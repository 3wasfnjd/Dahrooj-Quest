/* eslint-disable @typescript-eslint/no-explicit-any -- Exercise the actual reference meshes with a drawing-only canvas stub. */
import {afterEach,describe,expect,it,vi} from 'vitest';
import * as T from '@iwsdk/core';
import {createReferenceCharacter} from '../../src/reference/character.js';
import {JELLY_COLORS} from '../../src/core/appearance';
afterEach(()=>vi.unstubAllGlobals());
function character(){
 const context=new Proxy({},{get:(_target,key)=>key==='createLinearGradient'||key==='createRadialGradient'?()=>({addColorStop(){}}):()=>{},set:()=>true});
 vi.stubGlobal('document',{createElement:()=>({width:0,height:0,getContext:()=>context})});
 return createReferenceCharacter(T,{radius:.24,drawFace(){}});
}
describe('character appearance on real Three geometry',()=>{
 it('updates existing main and instanced jelly uniforms for every saved colour',()=>{
  const models=character(),main=models.make('jelly'),crowd=models.crowd(8,true);
  for(const color of JELLY_COLORS){
   models.setJellyColor(color.id);expect(models.mats.jelly.uniforms.uTint.value.getHex()).toBe(color.hex);
   crowd.begin();crowd.add('jelly',new T.Vector3(),.24,null,[1,1],'open','headphones');crowd.end();
   const body=crowd.group.children.find((m:any)=>m.material.uniforms?.uTint) as T.Mesh<T.BufferGeometry,T.ShaderMaterial>;
   expect(body.material.uniforms.uTint).toBe(models.mats.jelly.uniforms.uTint);
  }
  expect(main.group.children.length).toBeGreaterThan(0);
 });
 it('switches every accessory on all three styles without deleting shared geometry',()=>{
  const models=character();
  for(const style of ['jelly','fur','bubble'] as const){
   const main=models.make(style);let maximum=0;
   for(const id of ['party','glasses','cap','flower','crown','headphones','scarf','laurel','woodhat','starGlasses','']){
    main.setAccessory(id);main.group.updateMatrixWorld(true);
    main.group.traverse((o:any)=>{if(o.isMesh){expect(o.geometry.attributes.position.count).toBeGreaterThan(0);maximum++;}});
    if(id){const acc=main.group.getObjectByName('dahrooj-accessory-'+id)!;expect(acc).toBeDefined();expect(acc.children.length).toBeGreaterThan(0);}
    const bounds=new T.Box3().setFromObject(main.group);expect(Number.isFinite(bounds.max.x)).toBe(true);
   }
   expect(maximum).toBeGreaterThan(20);main.dispose();
  }
 });
 it('keeps all seven rain colours in one draw per style without changing the player or later crowds',()=>{
  const models=character(),rain=models.crowd(21),shots=models.crowd(2),tint=new T.Color();models.setJellyColor('purple');
  rain.begin();for(const style of ['jelly','fur','bubble'] as const)for(const c of JELLY_COLORS)rain.add(style,new T.Vector3(),.12,null,[1,1],null,'',c.hex);rain.end();
  expect(rain.count).toBe(21);expect(models.mats.jelly.uniforms.uTint.value.getHex()).toBe(0xb878ff);
  for(const style of ['jelly','fur','bubble']){const body=rain.group.getObjectByName('dahrooj-crowd-'+style) as T.InstancedMesh;
   expect(body.count).toBe(7);for(let i=0;i<7;i++){body.getColorAt(i,tint);expect(tint.getHex()).toBe(JELLY_COLORS[i].hex);}
   expect(body.instanceColor!.version).toBeGreaterThan(0);
  }
  shots.begin();shots.add('jelly',new T.Vector3(),.12,null,[1,1],null);shots.end();
  (shots.group.getObjectByName('dahrooj-crowd-jelly') as T.InstancedMesh).getColorAt(0,tint);expect(tint.getHex()).toBe(0xb878ff);
  rain.begin();rain.add('fur',new T.Vector3(),.12,null,[1,1],null);rain.end();
  (rain.group.getObjectByName('dahrooj-crowd-fur') as T.InstancedMesh).getColorAt(0,tint);expect(tint.getHex()).toBe(0xffffff);
 });
 it('retains all material groups of the new rewards when batching indexed and extruded geometry',()=>{
  const models=character(),crowd=models.crowd(1,true);
  for(const [id,count] of [['laurel',2],['woodhat',3],['starGlasses',2]] as const){
   crowd.begin();crowd.add('jelly',new T.Vector3(),.24,null,[1,1],'open',id);crowd.end();
   const parts=crowd.group.children.filter(o=>o.name.startsWith('xr-rain-accessory-'+id+'-')) as T.InstancedMesh[];
   expect(parts).toHaveLength(count);for(const part of parts){expect(part.count).toBe(1);expect(part.geometry.attributes.position.count).toBeGreaterThanOrEqual(20);}
  }
 });
});
