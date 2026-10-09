interface Vec3 {x:number;y:number;z:number}

/** Closing speed at the first contact during this step, including fast pass-throughs.
 * Positions are at the end of the step; all inputs share the same units/time scale.
 * Scalar arithmetic avoids allocating vectors in the bounded crowd/contact loops.
 */
export function ballImpactSpeed(a:Vec3,av:Vec3,b:Vec3,bv:Vec3,radius:number,dt:number):number{
 const vx=bv.x-av.x,vy=bv.y-av.y,vz=bv.z-av.z;
 const speed2=vx*vx+vy*vy+vz*vz;if(speed2<1e-8)return 0;
 const x=b.x-a.x-vx*dt,y=b.y-a.y-vy*dt,z=b.z-a.z-vz*dt;
 const approach=x*vx+y*vy+z*vz;if(approach>=0)return 0;
 const gap=x*x+y*y+z*z-radius*radius;
 let t=0;
 if(gap>0){
  const disc=approach*approach-speed2*gap;if(disc<0)return 0;
  t=(-approach-Math.sqrt(disc))/speed2;if(t<0||t>dt)return 0;
 }
 const nx=x+vx*t,ny=y+vy*t,nz=z+vz*t,length=Math.hypot(nx,ny,nz);
 return length>1e-6?Math.max(0,-(nx*vx+ny*vy+nz*vz)/length):0;
}
