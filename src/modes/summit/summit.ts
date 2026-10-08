import * as T from '@iwsdk/core';
import type { GameContext } from '../../core/context';
import { ModeScope } from '../scope';
import core from '../../reference/summit-core.js';
import { createReferenceMountain } from '../../reference/summit-world.js';
export class SummitMode {
 readonly id='summit' as const;readonly scope:ModeScope;readonly mountain;score=0;private accumulator=0;private clipping:boolean;
 private options;
 constructor(readonly c:GameContext){this.scope=new ModeScope(c);this.clipping=c.world.renderer.localClippingEnabled;
  this.mountain=createReferenceMountain(T,{core,models:c.balls.factory.reference,BR:1,renderer:c.world.renderer,width:16.25,unit:.1,
   onBurst:(p,colors,count,speed)=>c.particles.burst(p,colors[0],Math.min(30,count),Math.min(2,speed))});
  this.scope.at(this.mountain.group,0,c.xr==='immersive-vr'?.7:0,-3);this.mountain.group.scale.setScalar(c.space.scale);this.mountain.setBase(c.xr==='immersive-vr'?.7:0);this.mountain.start();
  this.options={style:c.store.data.style,eye:c.input.head,onEvent:(e:{type:string})=>{if(e.type==='kill'||e.type==='stomp')c.store.progress('monsters15');if(e.type==='summit'){c.store.progress('summit1');c.events.emit('score',{mode:this.id,points:100,curved:false});}}};
  c.events.emit('notice',{ar:'القمة: العصا اليسرى للحركة، A للقفز، الزناد الأيسر للرمي، B للخروج',en:'Summit: left stick move · A jump · left trigger shoot · B menu'});
 }
 jump(){this.mountain.jump();}shoot(){this.mountain.throwBall();}
 update(dt:number){this.mountain.setDir(this.c.input.left.axisX);this.accumulator=Math.min(.1,this.accumulator+dt);while(this.accumulator>=1/60){core.step(this.mountain.state,1/60);this.accumulator-=1/60;}this.options.style=this.c.store.data.style;this.mountain.update(dt,this.options);this.score=Math.max(0,Math.floor(this.mountain.state.ball.y-1));}
 get detail(){const s=this.mountain.state;return `${'♥'.repeat(Math.max(0,s.ball.hearts))} · ${s.checkpoint}/4`;}
 dispose(){this.mountain.dispose();this.c.world.renderer.localClippingEnabled=this.clipping;this.scope.dispose();}
}
