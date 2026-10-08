import * as T from '@iwsdk/core';
import type { GameContext } from '../core/context';
import { CHALLENGES } from '../progression/challenges';
import type { Ball } from '../character/ball-pool';
import type { GameMode, Hit, Target } from './types';
import type { RefStage, RefBrick } from '../reference/stage-types';
import { ModeScope } from './scope';
import { stageArt } from '../reference/stage-art.js';
import { referenceBallPhysics } from '../reference/ball-physics.js';
import goal from '../reference/stages/goal.js';
import hoop from '../reference/stages/hoop.js';
import windowStage from '../reference/stages/window.js';
import cans from '../reference/stages/cans.js';
import bowling from '../reference/stages/bowling.js';
import bricks from '../reference/stages/bricks.js';
import fair from '../reference/stages/fair.js';
const builders={goal,hoop,window:windowStage,cans,bowling,bricks,fair};
export const REFERENCE_UNIT=.13/.24;
type StageId=keyof typeof builders;
type Flight={id:number;shot:boolean;shotT:number;scoredT:number;missT:number;grounded:boolean;restT:number;wet:boolean;side:T.Vector3};
export class ReferenceMode implements GameMode {
 readonly referencePhysics=true;
 readonly scope:ModeScope;readonly stage:RefStage;readonly root=new T.Group();score=0;detail='';
 private flights=new Map<number,Flight>();private active?:Ball;private accumulator=0;private pending=true;private disposed=false;
 private p=new T.Vector3();private velocity=new T.Vector3();private direction=new T.Vector3();private inverse=new T.Quaternion();
 private targets:{source:T.Object3D;target:Target}[]=[];private counts:Record<string,number>={};private lastShot=false;
 private S={pos:new T.Vector3(),vel:new T.Vector3(),side:new T.Vector3(),axis:new T.Vector3(0,1,0),prevY:0,prevZ:0,shot:false,shotT:0,scoredT:0,missT:0,grounded:false,restT:0,wet:false,xMax:50,zMax:15};
 private ctx;private step:(dt:number)=>boolean;
 constructor(readonly c:GameContext,readonly id:StageId){
  this.scope=new ModeScope(c);this.scope.at(this.root,0,0,0);this.root.scale.setScalar(REFERENCE_UNIT*c.space.scale);this.root.updateMatrixWorld(true);this.inverse.copy(c.space.rotation).invert();
  const sound=(kind:'impact'|'pop'|'bell'='impact')=>c.events.emit('impact',{position:this.active?.root.position??this.root.position,kind,power:.5});
  this.ctx={T,scene:this.root,V:(x=0,y=0,z=0)=>new T.Vector3(x,y,z),UP:new T.Vector3(0,1,0),INK:0x2c2d3d,COL:{ink:'#2c2d3d',coral:'#e2603f'},S:this.S,BR:.24,GRAV:13,time:0,xrLang:c.store.data.language,audio:null,sfxOut:()=>null,
   stage:undefined as RefStage|undefined,xrOnNow:()=>true,ar:(n:number)=>n.toLocaleString('ar'),counts:this.counts,chState:c.store.data.challenges,
   chProgress:(key:string,n:number)=>{const found=CHALLENGES.find(([id])=>id===key);if(found)c.store.progress(found[0],n,true);},
   success:()=>this.success(),miss:()=>{if(this.S.missT<=0&&this.S.scoredT<=0)this.S.missT=1.7;},react:(kind:string)=>{if(this.active)this.active.visual.expression=kind==='joy'?'joy':'wide';},
   addCount:(key:string)=>{this.counts[key]=(this.counts[key]??0)+1;this.score++;},toast:(message:string)=>c.events.emit('notice',{ar:message,en:message}),
   ooh:()=>sound(),swish:()=>sound(),thump:()=>sound(),squeak:()=>sound(),chime:()=>sound('bell'),startPopSound:()=>sound('pop'),
   hit:(_n:T.Vector3,speed:number)=>{this.active?.visual.impact(Math.min(1,speed/14));sound();},splash:()=>sound(),
   waterHook:{depth:(x:number,z:number)=>{this.root.localToWorld(this.p.set(x,0,z));return c.environment.water?.contains(this.p)?1:0;},splash:(p:T.Vector3,power:number)=>{this.root.localToWorld(this.p.copy(p));c.environment.water?.splash(this.p,power);}},
   confetti:{celebrate:(p:T.Vector3)=>{this.root.localToWorld(this.p.copy(p));c.particles.burst(this.p,0xf2c14e,18,c.space.scale);}},
   changed:()=>{this.pending=true;},pushBody:()=>{},breakBrick:(brick:RefBrick)=>{brick.mesh.visible=false;brick.mesh.getWorldPosition(this.p);c.particles.burst(this.p,0xb89870,12,c.space.scale);},
   best:(value?:number)=>{if(value!==undefined){c.store.data.best.fair=Math.max(value,c.store.data.best.fair??0);c.store.touch();}return c.store.data.best.fair??0;},
   loadPin:(callback:(gltf:{scene:T.Group})=>void)=>{T.AssetManager.loadGLTF(new URL('assets/models/bowlingPin.glb',document.baseURI).href).then(gltf=>{if(!this.disposed){const clone=gltf.scene.clone(true);clone.traverse(o=>{if(o instanceof T.Mesh)o.material=Array.isArray(o.material)?o.material.map(m=>m.clone()):o.material.clone();});callback({scene:clone});}}).catch(()=>c.events.emit('notice',{ar:'تعذر تحميل نموذج الدبوس؛ النموذج المؤقت يعمل.',en:'Pin asset unavailable; fallback active.'}));}
  };
  Object.assign(this.ctx,stageArt(this.ctx));this.stage=builders[id](this.ctx);this.ctx.stage=this.stage;this.step=referenceBallPhysics(this.ctx);this.rebuild();
 }
 private load(ball?:Ball){this.active=ball;const s=this.S;if(!ball){s.shot=false;s.pos.set(0,1,0);s.vel.set(0,0,0);return;}
  let flight=this.flights.get(ball.id);if(!flight){flight={id:ball.id,shot:true,shotT:0,scoredT:0,missT:0,grounded:false,restT:0,wet:false,side:new T.Vector3()};if(ball.curved){flight.side.set(-ball.velocity.z,0,ball.velocity.x).normalize().multiplyScalar(Math.min(9,Math.abs(ball.spin.y)*.25)*Math.sign(ball.spin.y));}this.flights.set(ball.id,flight);}
  Object.assign(s,{shot:flight.shot,shotT:flight.shotT,scoredT:flight.scoredT,missT:flight.missT,grounded:flight.grounded,restT:flight.restT,wet:flight.wet});s.side.copy(flight.side);
  this.root.worldToLocal(s.pos.copy(ball.root.position));s.vel.copy(ball.velocity).applyQuaternion(this.inverse).divideScalar(this.root.scale.x);
 }
 private save(ball:Ball){const s=this.S,flight=this.flights.get(ball.id)!;Object.assign(flight,{shot:s.shot,shotT:s.shotT,scoredT:s.scoredT,missT:s.missT,grounded:s.grounded,restT:s.restT,wet:s.wet});flight.side.copy(s.side);
  ball.root.position.copy(s.pos);this.root.localToWorld(ball.root.position);ball.velocity.copy(s.vel).multiplyScalar(this.root.scale.x).applyQuaternion(this.root.quaternion);ball.water=s.wet;
 }
 private success(){if(this.active?.scored||this.S.scoredT>0||this.S.missT>0)return;this.S.scoredT=1.7;if(this.active)this.active.scored=true;this.score++;this.c.events.emit('score',{mode:this.id,points:1,curved:!!this.active?.curved});if(this.id==='goal')this.c.store.progress('keeper3');if(this.id==='hoop')this.c.store.progress('hoop3');if(this.active?.curved)this.c.store.progress('curve3');}
 private rebuild(){this.pending=false;for(const t of this.targets){t.target.object.removeFromParent();const i=this.scope.objects.indexOf(t.target.object);if(i>=0)this.scope.objects.splice(i,1);}this.scope.targets.length=0;this.targets.length=0;
  const add=(source:T.Object3D,r:number)=>{const proxy=this.scope.add(new T.Group());source.getWorldPosition(proxy.position);const target=this.scope.target(proxy,r*REFERENCE_UNIT,(hit:Hit)=>{if(!hit.projectile)return;this.S.side.set(0,hit.curved?2:0,0);this.root.worldToLocal(this.p.copy(hit.point));this.direction.copy(hit.direction).applyQuaternion(this.inverse);if(this.id==='fair')this.stage.onThrow?.();this.stage.shoot?.(source,this.p,this.direction);});this.targets.push({source,target});};
  const b=this.stage.bridge;for(const body of b?.bodies??[])add(body.mesh,b!.radius!);for(const brick of b?.bricks??[])if(brick.alive)add(brick.mesh,.32);for(const duck of b?.ducks??[])add(duck.g,duck.r);for(const balloon of b?.balloons??[])add(balloon.m,balloon.r);if(b?.bell)add(b.bell,.3);
 }
 onThrow(id:number){const ball=this.c.balls.slots.find(b=>b.id===id&&b.active);this.load(ball);this.stage.onThrow?.();}
 update(dt:number){this.ctx.time=this.c.elapsed;this.ctx.xrLang=this.c.store.data.language;this.root.updateMatrixWorld(true);if(this.pending)this.rebuild();
  // Both the ball integrator and original contact solver run at a fixed rate.
  this.accumulator=Math.min(this.accumulator+dt,.1);while(this.accumulator>=1/120){
   let primary:Ball|undefined;for(const ball of this.c.balls.slots){if(!ball.active||ball.held)continue;this.load(ball);this.step(1/120);this.save(ball);if(this.S.shot)primary=ball;}
   this.load(primary);this.stage.update(1/120);if(primary)this.save(primary);if(this.lastShot&&!primary)this.stage.onRespawn?.();this.lastShot=!!primary;this.accumulator-=1/120;
  }
  for(const id of this.flights.keys())if(!this.c.balls.slots.some(b=>b.active&&b.id===id))this.flights.delete(id);
  this.root.updateMatrixWorld(true);for(const t of this.targets){t.source.getWorldPosition(t.target.object.position);t.target.object.visible=t.source.visible;}
  if(this.stage.fair){this.score=this.stage.fair.score;this.detail=String(Math.ceil(this.stage.fair.time));}
 }
 dispose(){this.disposed=true;const geos=new Set<T.BufferGeometry>(),mats=new Set<T.Material>(),textures=new Set<T.Texture>();this.root.traverse(o=>{if(o instanceof T.Mesh||o instanceof T.LineSegments){geos.add(o.geometry);for(const m of Array.isArray(o.material)?o.material:[o.material]){mats.add(m);for(const v of Object.values(m))if(v instanceof T.Texture)textures.add(v);}}});this.scope.dispose();for(const g of geos)g.dispose();for(const m of mats)m.dispose();for(const t of textures)t.dispose();}
}
