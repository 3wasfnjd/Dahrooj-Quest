/* eslint-disable @typescript-eslint/no-explicit-any -- Runs the reference integration with Three geometry and platform stubs, not a browser. */
import {afterEach,expect,it,vi} from 'vitest';
import * as T from '@iwsdk/core';
import {createCompleteGame} from '../../src/reference/complete-game.js';
import {defaults} from '../../src/save/store';
afterEach(()=>vi.unstubAllGlobals());
it('routes the unified panel and scrolls with a real controller frame without firing or moving the world',async()=>{
 const context=new Proxy({},{get:(_t,k)=>k==='createLinearGradient'||k==='createRadialGradient'?()=>({addColorStop(){}}):k==='measureText'?()=>({width:80}):()=>{},set:()=>true});
 vi.stubGlobal('document',{createElement:()=>({width:0,height:0,getContext:()=>context}),getElementById:()=>({hidden:false})});
 vi.stubGlobal('localStorage',{getItem:()=>null,setItem:vi.fn()});vi.stubGlobal('window',{addEventListener(){},removeEventListener(){}});
 const scene=new T.Scene(),player=new T.Group();scene.add(player);const camera=new T.PerspectiveCamera();camera.position.set(0,1.6,0);scene.add(camera);scene.updateMatrixWorld(true);
 const controllers=[new T.Group(),new T.Group()],session={visibilityState:'visible',addEventListener(){}};
 const xr={getController:(i:number)=>controllers[i],getControllerGrip:()=>new T.Group(),getSession:()=>session,addEventListener(){},setReferenceSpaceType(){},setFoveation(){},getReferenceSpace:()=>({})};
 const renderer={xr,capabilities:{getMaxAnisotropy:()=>4},info:{render:{calls:0,triangles:0}}};
 const store={data:defaults(),touch:vi.fn(),flush:vi.fn()},world={scene,player,camera,renderer,onXRFrame(){}};
 const game:any=createCompleteGame(world as any,store as any),r=game.runtime;
 const click=(kind:string,id:string)=>{const i=r.menuLayout.buttons.findIndex((b:any)=>b.kind===kind&&b.id===id);expect(i).toBeGreaterThanOrEqual(0);r.action(i);};
 r.setPlaza(true);expect(r.menuPage).toBe('modes');const mesh=scene.getObjectByName('xr-menu')!;
 click('tab','appearance');click('style','jelly');click('jellyColor','purple');expect(store.data.jellyColor).toBe('purple');expect(store.data.style).toBe('jelly');
 for(const [style,color] of [['fur','blue'],['bubble','green']]){click('style',style);click('jellyColor',color);expect(store.data.style).toBe(style);expect(store.data.jellyColor).toBe(color);}
 click('tab','play');click('shot','firework');click('throw','hand');expect(r.shotStyle).toBe('firework');expect(r.throwStyle).toBe('hand');
 click('tab','challenges');click('scrollStep','down');expect(r.challengeScroll.offset).toBeGreaterThan(0);expect(r.challengesOpen).toBe(true);
 click('tab','about');expect(r.menuPage).toBe('about');expect(scene.getObjectByName('xr-menu')).toBe(mesh);expect(mesh.children).toHaveLength(0);
 click('tab','modes');click('mode','goal');expect(r.menuOpen).toBe(false);expect(game.g.mode()).toBe('goal');expect(store.touch).toHaveBeenCalled();
 vi.stubGlobal('navigator',{xr:{}});await r.enter('immersive-ar');
 for(let i=0;i<2;i++)controllers[i].dispatchEvent({type:'connected',data:{handedness:i?'right':'left',gamepad:{buttons:[],axes:[0,0,0,i?1:0]}}} as any);
 r.setMenu(true,'challenges');const offset=r.challengeScroll.offset,scale=player.scale.clone(),position=player.position.clone();
 r.frame(1000,{getViewerPose:()=>({}),detectedPlanes:new Set()});expect(r.challengeScroll.offset).toBeGreaterThan(offset);
 expect(player.scale.equals(scale)).toBe(true);expect(player.position.equals(position)).toBe(true);expect(game.S.shot).toBe(false);expect(r.blast.fired).toBe(0);
 const stopped=r.challengeScroll.offset;r.setMenu(true,'appearance');r.frame(1016,{getViewerPose:()=>({}),detectedPlanes:new Set()});expect(r.challengeScroll.offset).toBe(stopped);
});
