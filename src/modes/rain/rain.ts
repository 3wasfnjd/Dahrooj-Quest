import * as T from '@iwsdk/core';
import type { GameContext } from '../../core/context';
import { LIMITS } from '../../core/config';
import { ModeScope } from '../scope';
import { segmentSphere } from '../../physics/sweep';
import { createReferenceRain } from '../../reference/rain-physics.js';
import type { Drop } from '../../reference/rain-physics.js';
export class RainMode {
 readonly id='rain' as const;readonly scope:ModeScope;score=0;
 private crowd;private simulation;private live:Drop[]=[];private head=new T.Vector3();private p=new T.Vector3();private squash=[1,1];private accumulator=0;
 constructor(readonly c:GameContext){this.scope=new ModeScope(c);this.crowd=c.balls.factory.reference.crowd(LIMITS.rain);this.scope.at(this.crowd.group,0,0,0);this.crowd.group.scale.setScalar(c.space.scale);this.simulation=createReferenceRain(T,LIMITS.rain);}
 update(dt:number){const count=this.c.quality.level===2?80:this.c.quality.level===1?100:LIMITS.rain;this.c.space.local(this.c.input.head,this.head);this.accumulator=Math.min(.1,this.accumulator+dt);while(this.accumulator>=1/60){this.live=this.simulation.step(1/60,this.head,count);this.accumulator-=1/60;}
 this.crowd.begin();for(const b of this.live){this.squash[0]=1-b.d*.5;this.squash[1]=1+b.d;this.crowd.add(b.style,b.p,b.R,this.head,this.squash,b.blink?'shut':b.hit?'wide':'open');}this.crowd.end();}
 hitProjectile(from:T.Vector3,to:T.Vector3,radius:number){for(const b of this.live){this.c.space.point(b.p.x,b.p.y,b.p.z,this.p);if(segmentSphere(from,to,this.p,radius+b.R*this.c.space.scale)){this.c.particles.burst(this.p,0xe2603f,12,this.c.space.scale);this.c.events.emit('impact',{position:this.p,power:.4,kind:'pop'});this.c.store.progress('pop20');this.score++;this.simulation.reset(b);return true;}}return false;}
 get detail(){return `${this.crowd.count} · Reference physics`;}
 dispose(){this.crowd.group.traverse(o=>{if(o instanceof T.InstancedMesh)o.dispose();});this.scope.dispose();}
}
