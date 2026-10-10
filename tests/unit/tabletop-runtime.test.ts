/* eslint-disable @typescript-eslint/no-explicit-any -- Exercises the JS runtime with real Three transforms, input events and platform stubs. */
import {afterEach,describe,expect,it,vi} from 'vitest';
import * as T from '@iwsdk/core';
import {createCompleteGame} from '../../src/reference/complete-game.js';
import {defaults,migrate} from '../../src/save/store';
// Asset fetching/audio are outside this controller-routing test. The real new stages and character render objects run.
vi.mock('../../src/reference/nature.js',()=>({createReferenceNature:()=>null}));
afterEach(()=>vi.unstubAllGlobals());
async function platform(kind:string,saved=defaults()){
 const context=new Proxy({},{get:(_t,k)=>k==='createLinearGradient'||k==='createRadialGradient'?()=>({addColorStop(){}}):k==='measureText'?()=>({width:80}):()=>{},set:()=>true});
 vi.stubGlobal('document',{createElement:()=>({width:0,height:0,getContext:()=>context}),getElementById:()=>({hidden:false})});
 vi.stubGlobal('localStorage',{getItem:(key:string)=>key==='dahrooj-acc'?saved.accessory:null,setItem:vi.fn()});vi.stubGlobal('window',{addEventListener(){},removeEventListener(){}});vi.stubGlobal('navigator',{xr:{}});
 const scene=new T.Scene(),player=new T.Group(),camera=new T.PerspectiveCamera();scene.add(player);player.add(camera);camera.position.set(0,1.6,0);
 const controllers=[new T.Group(),new T.Group()],grips=[new T.Group(),new T.Group()],session=new T.EventDispatcher() as any;session.visibilityState='visible';
 const xr={getController:(i:number)=>controllers[i],getControllerGrip:(i:number)=>grips[i],getSession:()=>session,addEventListener(){},setReferenceSpaceType(){},setFoveation(){},getReferenceSpace:()=>({})};
 const renderer={xr,capabilities:{getMaxAnisotropy:()=>4},info:{render:{calls:0,triangles:0}}},store={data:saved,touch:vi.fn(),flush:vi.fn()};
 const game:any=createCompleteGame({scene,player,camera,renderer,onXRFrame(){}} as any,store as any),r=game.runtime;
 game.setMode('goal');await r.enter(kind);
 controllers.forEach((h,i)=>{h.position.set(i?.25:-.25,1.1,-.3);grips[i].position.copy(h.position);h.dispatchEvent({type:'connected',data:{handedness:i?'right':'left',gamepad:{buttons:[],axes:[0,0,0,0]}}} as any);});
 let time=1000;const frame=(pose=true)=>{scene.updateMatrixWorld(true);r.frame(time+=1000/90,{getViewerPose:()=>pose?{}:null,detectedPlanes:new Set()});scene.updateMatrixWorld(true);};
 if(kind==='immersive-ar')r.testPin([0,.8,-.8],[0,1,0]);
 const choose=(id:string)=>{r.choosePlaza(r.plaza.ids.indexOf(id));frame();return game.g.stage();};
 const event=(type:string,index=1)=>controllers[index].dispatchEvent({type} as any);
 const pointAt=(point:T.Vector3,index=1)=>{const p=player.worldToLocal(point.clone());controllers[index].quaternion.setFromUnitVectors(new T.Vector3(0,0,-1),p.sub(controllers[index].position).normalize());};
 return {game,r,scene,player,grips,session,store,frame,choose,event,pointAt};
}
describe.each(['immersive-vr','immersive-ar'])('tabletop controller routing in %s',kind=>{
 it('carries an earned rings accessory into the maze and clears it on explicit reset',async()=>{
  const saved=migrate({version:2,accessory:'starGlasses',challenges:{rings5:5}});
  const {r,store,frame,choose}=await platform(kind,saved),stage=choose('maze');frame();
  expect(stage.grp.getObjectByName('dahrooj-accessory-starGlasses')).toBeDefined();expect(store.data.challenges.maze5).toBeUndefined();
  r.setMenu(true,'appearance');r.action(r.menuLayout.buttons.findIndex((b:any)=>b.kind==='appearance'&&b.id==='accessories'));
  expect(r.menuLayout.buttons.find((b:any)=>b.id==='starGlasses').disabled).toBe(false);
  r.setMenu(true,'challenges');for(let i=0;i<2;i++)r.action(r.menuLayout.buttons.findIndex((b:any)=>b.kind==='reset'));
  expect(store.data.challenges['reward:starGlasses']).toBeUndefined();r.setMenu(true,'appearance');
  expect(r.menuLayout.buttons.find((b:any)=>b.id==='starGlasses').disabled).toBe(true);
 });
 it('tilts the balance board, pauses on menus/tracking loss, restores style and exits cleanly',async()=>{
  const {game,r,scene,player,grips,frame,choose,event}=await platform(kind),stage=choose('balance');
  expect(stage.game.failures).toBe(0);
  const menu=scene.getObjectByName('xr-menu'),size=new T.Vector3();stage.grp.getWorldScale(size);expect(size.x/player.scale.x).toBeCloseTo(kind==='immersive-vr'?.32:.2);
  for(const side of [-1,1]){const handle=stage.grp.getObjectByName('balance-handle-'+side);expect(handle.position.y).toBeCloseTo(-.14);expect(handle.position.x).toBeCloseTo(side*1.64);}
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
  expect(paddle.material.name).toBe('tabletop-wood');expect(paddle.material.map).toBeDefined();expect(paddle.material.blending).toBe(T.NoBlending);
  const angle=stage.game.angles[0];event('squeezestart');grips[1].rotation.y=.25;frame();expect(stage.game.angles[0]).not.toBeCloseTo(angle);event('squeezeend');
  pointAt(target);event('selectstart');frame();expect(stage.game.phase).toBe('ready');event('selectend');expect(stage.game.phase).toBe('playing');expect(stage.game.attempts).toBe(1);
  event('selectend');expect(stage.game.attempts).toBe(1);expect(game.S.shot).toBe(false);expect(r.blast.fired).toBe(0);
  const saved={...stage.game.ball},transform=player.matrix.clone();r.setMenu(true);for(let i=0;i<10;i++)frame();expect(stage.game.ball).toEqual(saved);expect(player.matrix.equals(transform)).toBe(true);if(anchor)expect(r.anchor.P.equals(anchor)).toBe(true);
  r.setMenu(false);event('selectstart',0);event('selectend',0);expect(r.blast.fired).toBe(0);
  stage.game.retry();event('selectstart');frame(false);event('selectend');expect(stage.game.phase).toBe('ready');
  session.dispatchEvent({type:'end'});expect(stage.grp.visible).toBe(false);expect(r.presenting).toBe(false);
 });
 it('plays five mazes by controller tilt, pauses safely, equips the reward and resets progress',async()=>{
  const {r,game,grips,store,frame,choose,event}=await platform(kind),stage=choose('maze');
  expect(r.plaza.ids).toHaveLength(12);expect(r.plaza.ids).not.toContain('rings');expect(stage.game.failures).toBe(0);
  const menu=r.menuLayout.mesh,floor=stage.grp.getObjectByName('tabletop-floor');
  expect(floor.material.alphaTest).toBe(0);expect(floor.material.transparent).toBe(false);
  for(let level=0;level<5;level++){
   stage.game.reset(level);frame();grips[1].rotation.set(0,0,0);event('squeezestart');
   const route=stage.game.definition.route,walls=stage.grp.getObjectByName('maze-walls'),matrix=new T.Matrix4(),v=new T.Vector3(),q=new T.Quaternion(),scale=new T.Vector3();
   expect(walls.count).toBe(stage.game.definition.walls.length);
   stage.game.definition.walls.forEach((w:any,i:number)=>{walls.getMatrixAt(i,matrix);matrix.decompose(v,q,scale);expect(v.x).toBeCloseTo(w.x);expect(v.z).toBeCloseTo(w.z);expect(scale.x).toBeCloseTo(w.hx*2);expect(scale.z).toBeCloseTo(w.hz*2);});
   if(level===0){
    grips[1].rotation.z=-.2;for(let i=0;i<12;i++)frame();r.setMenu(true);const saved={...stage.game.ball};for(let i=0;i<20;i++)frame();expect(stage.game.ball).toEqual(saved);
    r.setMenu(false);for(let i=0;i<20;i++)frame();expect(stage.game.ball).toEqual(saved);grips[1].rotation.set(0,0,0);event('squeezestart');frame(false);const lost={...stage.game.ball};for(let i=0;i<10;i++)frame();expect(stage.game.ball).toEqual(lost);event('squeezestart');
   }
   let target=1;
   for(let i=0;i<90*150&&stage.game.phase!=='won';i++){
    const p=route[target],x=p.x-stage.game.ball.x,z=p.z-stage.game.ball.z;
    if(Math.hypot(x,z)<.07&&target<route.length-1)target++;
    const clamp=(v:number)=>Math.max(-.32,Math.min(.32,v)),tx=clamp((x*4-stage.game.velocity.x*3)/7),tz=clamp((z*4-stage.game.velocity.z*3)/7);
    // Generate the controller orientation that tilts its up vector by these angles.
    grips[1].quaternion.setFromUnitVectors(new T.Vector3(0,1,0),new T.Vector3(Math.tan(tx),1,Math.tan(tz)).normalize());frame();
   }
   event('squeezeend');expect(stage.game.phase,`maze ${level+1}`).toBe('won');expect(store.data.challenges.maze5).toBe(level+1);expect(stage.game.fall).toBe(0);
  }
  expect(store.data.best['tabletop:maze:cleared']).toBe(31);expect(store.data.challenges.mazeClean).toBe(1);expect(store.touch).toHaveBeenCalled();
  r.setMenu(true,'appearance');const click=(key:string,id:string)=>{const i=r.menuLayout.buttons.findIndex((b:any)=>b.kind===key&&b.id===id);expect(i).toBeGreaterThanOrEqual(0);r.action(i);};
  click('appearance','accessories');click('acc','starGlasses');r.setMenu(false);frame();
  expect(stage.grp.getObjectByName('dahrooj-accessory-starGlasses')).toBeDefined();expect(r.menuLayout.mesh).toBe(menu);expect(r.blast.fired).toBe(0);
  r.setMenu(true,'challenges');click('reset','reset');click('reset','reset');
  expect(store.data.challenges.maze5).toBeUndefined();expect(store.data.best['tabletop:maze:cleared']).toBeUndefined();
  r.setMenu(true,'appearance');click('appearance','accessories');expect(r.menuLayout.buttons.find((b:any)=>b.id==='starGlasses').disabled).toBe(true);
  choose('goal');expect(stage.grp.visible).toBe(false);expect(game.S.shot).toBe(false);
 },20000);
 it('solves round three using grip rotation and trigger input, keeping every rotating wooden part inside the tray',async()=>{
  const {grips,store,frame,choose,event,pointAt}=await platform(kind),stage=choose('ricochet'),board=stage.grp.children[0];
  // Check the rendered caps, inlays and pivot too, at every allowed angle in every round.
  for(let level=0;level<5;level++){
   stage.game.reset(level);frame();
   for(let degrees=0;degrees<360;degrees+=5){
    stage.game.angles.forEach((_:number,i:number)=>stage.game.turnMirror(i,degrees*Math.PI/180));frame();
    stage.game.angles.forEach((_:number,i:number)=>{
     stage.grp.getObjectByName('ricochet-paddle-'+i).traverse((o:any)=>{if(!o.isMesh)return;o.geometry.computeBoundingBox();const b=o.geometry.boundingBox;
      for(const x of [b.min.x,b.max.x])for(const y of [b.min.y,b.max.y])for(const z of [b.min.z,b.max.z]){const p=board.worldToLocal(o.localToWorld(new T.Vector3(x,y,z)));expect(Math.abs(p.x)).toBeLessThan(1.48);expect(Math.abs(p.z)).toBeLessThan(1.7);}
     });
    });
   }
  }
  stage.game.reset(2);frame();
  for(const [i,solution] of stage.game.definition.solution.entries()){
   grips[1].rotation.set(0,0,0);frame();pointAt(stage.grp.getObjectByName('ricochet-paddle-'+i).getWorldPosition(new T.Vector3()));frame();
   const initial=stage.game.angles[i];event('squeezestart');grips[1].rotation.y=-(solution-initial+.01);frame();event('squeezeend');expect(stage.game.angles[i]).toBeCloseTo(solution);
  }
  const start=stage.game.definition.start;pointAt(board.localToWorld(new T.Vector3(start.x,.14,-1.02)));frame();event('selectstart');event('selectend');
  for(let i=0;i<1000&&stage.game.phase==='playing';i++)frame();expect(stage.game.phase).toBe('won');expect(stage.game.bounces.size).toBe(3);expect(store.data.best['tabletop:ricochet:cleared']).toBe(4);
 });
});
