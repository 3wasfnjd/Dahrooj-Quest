interface Vec {x:number;y:number;z:number}
interface Wander {gx:number;gz:number}

/** Sample an even-area, 128-degree fan in front of the current horizontal headset pose. */
export function rainSpawn(out:Vec,head:Vec,forward:Vec,radius:number,angleSample:number,distanceSample:number):void{
 const angle=(angleSample-.5)*2.24,near=1;
 const distance=Math.sqrt(near*near+distanceSample*(radius*radius-near*near));
 const ahead=Math.cos(angle)*distance,side=Math.sin(angle)*distance;
 out.x=head.x+forward.x*ahead-forward.z*side;
 out.z=head.z+forward.z*ahead+forward.x*side;
}

/** A soft return: change the wandering target velocity, never teleport a visible ball. */
export function guideRain(p:Vec,wander:Wander,head:Vec,forward:Vec,radius:number):void{
 const x=p.x-head.x,z=p.z-head.z,ahead=x*forward.x+z*forward.z,side=-x*forward.z+z*forward.x;
 if(ahead>=.6&&ahead<=radius+.3&&Math.abs(side)<=radius+.25)return;
 const targetAhead=Math.max(1.15,Math.min(radius-.15,ahead));
 const targetSide=Math.max(-radius*.85,Math.min(radius*.85,side));
 const da=targetAhead-ahead,ds=targetSide-side,length=Math.hypot(da,ds);
 if(length<1e-6)return;
 const speed=.65/length;
 wander.gx=(forward.x*da-forward.z*ds)*speed;
 wander.gz=(forward.z*da+forward.x*ds)*speed;
}
