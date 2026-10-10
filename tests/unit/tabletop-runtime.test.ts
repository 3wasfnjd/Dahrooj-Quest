/* eslint-disable @typescript-eslint/no-explicit-any -- Exercises the JS runtime with real Three transforms, input events and platform stubs. */
import {afterEach,describe,expect,it,vi} from 'vitest';
import * as T from '@iwsdk/core';
import {createCompleteGame} from '../../src/reference/complete-game.js';
import {defaults} from '../../src/save/store';
// Asset fetching/audio are outside this controller-routing test. The real new stages and character render objects run.
vi.mock('../../src/reference/nature.js',()=>({createReferenceNature:()=>null}));
afterEach(()=>vi.unstubAllGlobals());
async function platform(kind:string){
 const context=new Proxy({},{get:(_t,k)=>k==='createLinearGradient'||k==='createRadialGradient'?()=>({addColorStop(){}}):k==='measureText'?()=>({width:80}):()=>{},set:()=>true});
 vi.stubGlobal('document',{createElement:()=>({width:0,height:0,getContext:()=>context}),getElementById:()=>({hidden:false})});
 vi.stubGlobal('localStorage',{getItem:()=>null,setItem:vi.fn()});vi.stubGlobal('window',{addEventListener(){},removeEventListener(){}});vi.stubGlobal('navigator',{xr:{}});
 const scene=new T.Scene(),player=new T.Group(),camera=new T.PerspectiveCamera();scene.add(player);player.add(camera);camera.position.set(0,1.6,0);
 const controllers=[new T.Group(),new T.Group()],grips=[new T.Group(),new T.Group()],session=new T.EventDispatcher() as any;session.visibilityState='visible';
 const xr={getController:(i:number)=>controllers[i],getControllerGrip:(i:number)=>grips[i],getSession:()=>session,addEventListener(){},setReferenceSpaceType(){},setFoveation(){},getReferenceSpace:()=>({})};
 const renderer={xr,capabilities:{getMaxAnisotropy:()=>4},info:{render:{calls:0,triangles:0}}},store={data:defaults(),touch:vi.fn(),flush:vi.fn()};
 const game:any=createCompleteGame({scene,player,camera,renderer,onXRFrame(){}} as any,store as any),r=game.runtime;
 game.setMode('goal');await r.enter(kind);
 controllers.forEach((h,i)=>{h.position.set(i?.25:-.25,1.1,-.3);grips[i].position.copy(h.position);h.dispatchEvent({type:'connected',data:{handedness:i?'right':'left',gamepad:{buttons:[],axes:[0,0,0,0]}}} as any);});
 let time=1000;const frame=(pose=true)=>{scene.updateMatrixWorld(true);r.frame(time+=1000/90,{getViewerPose:()=>pose?{}:null,detectedPlanes:new Set()});scene.updateMatrixWorld(true);};
 if(kind==='immersive-ar')r.testPin([0,.8,-.8],[0,1,0]);
 const choose=(id:string)=>{r.choosePlaza(r.plaza.ids.indexOf(id));frame();return game.g.stage();};
 const event=(type:string,index=1)=>controllers[index].dispatchEvent({type} as any);
 const pointAt=(point:T.Vector3,index=1)=>{const p=player.worldToLocal(point.clone());controllers[index].quaternion.setFromUnitVectors(new T.Vector3(0,0,-1),p.sub(controllers[index].position).normalize());};
 return {game,r,scene,player,grips,session,frame,choose,event,pointAt};
}
describe.each(['immersive-vr','immersive-ar'])('tabletop controller routing in %s',kind=>{
 it('tilts the balance board, pauses on menus/tracking loss, restores style and exits cleanly',async()=>{
  const {game,r,scene,player,grips,frame,choose,event}=await platform(kind),stage=choose('balance');
  const menu=scene.getObjectByName('xr-menu'),size=new T.Vector3();stage.grp.getWorldScale(size);expect(size.x/player.scale.x).toBeCloseTo(kind==='immersive-vr'?.32:.2);
  if(kind==='immersive-vr'){const room=player.worldToLocal(stage.grp.position.clone());expect(room.z).toBeCloseTo(-.82);expect(room.y).toBeCloseTo(.98);}
  const before={...stage.game.ball};event('squeezestart');grips[1].rotation.x=-.2;for(let i=0;i<45;i++)frame();
  expect(stage.game.ball.z).toBeLessThan(before.z);expect(game.S.shot).toBe(false);expect(r.blast.fired).toBe(0);expect(r.holding).toBe(false);
  r.setMenu(true);const paused={...stage.game.ball};for(let i=0;i<20;i++)frame();expect(stage.game.ball).toEqual(paused);expect(scene.getObjectByName('xr-menu')).toBe(menu);
  r.setMenu(false);for(let i=0;i<20;i++)frame();expect(stage.game.ball).toEqual(paused); // reopening never leaves a stale grip
  event('squeezestart');grips[1].rotation.x=-.25;frame();frame(false);const lost={...stage.game.ball};for(let i=0;i<10;i++)frame();expect(stage.game.ball).toEqual(lost);
  event('squeezestart');grips[1].visible=false;frame();const handLost={...stage.game.ball};grips[1].visible=true;for(let i=0;i<10;i++)frame();expect(stage.game.ball).toEqual(handLost);
  game.setStyle('fur');frame();let fur=0;stage.grp.traverse((o:any)=>{if(o.name==='dahrooj-fur')fur++;});expect(fur).toBe(1);
  choose('goal');expect(stage.grp.visible).toBe(false);event('selectstart');expect(r.holding).toBe(true);event('selectend');expect(game.S.shot).toBe(true);
 });
 it('turns a paddle by grip, launches once by trigger, cancels holds and preserves the AR anchor',async()=>{
  const {r,game,player,grips,session,frame,choose,event,pointAt}=await platform(kind),stage=choose('ricochet'),anchor=r.anchor&&r.anchor.P.clone();
  const paddle=stage.grp.getObjectByName('ricochet-paddle-0'),target=paddle.getWorldPosition(new T.Vector3());pointAt(target);frame();
  const angle=stage.game.angles[0];event('squeezestart');grips[1].rotation.y=.25;frame();expect(stage.game.angles[0]).not.toBeCloseTo(angle);event('squeezeend');
  pointAt(target);event('selectstart');frame();expect(stage.game.phase).toBe('ready');event('selectend');expect(stage.game.phase).toBe('playing');expect(stage.game.attempts).toBe(1);
  event('selectend');expect(stage.game.attempts).toBe(1);expect(game.S.shot).toBe(false);expect(r.blast.fired).toBe(0);
  const saved={...stage.game.ball},transform=player.matrix.clone();r.setMenu(true);for(let i=0;i<10;i++)frame();expect(stage.game.ball).toEqual(saved);expect(player.matrix.equals(transform)).toBe(true);if(anchor)expect(r.anchor.P.equals(anchor)).toBe(true);
  r.setMenu(false);event('selectstart',0);event('selectend',0);expect(r.blast.fired).toBe(0);
  stage.game.retry();event('selectstart');frame(false);event('selectend');expect(stage.game.phase).toBe('ready');
  session.dispatchEvent({type:'end'});expect(stage.grp.visible).toBe(false);expect(r.presenting).toBe(false);
 });
});
