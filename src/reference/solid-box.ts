type Vec={x:number;y:number;z:number};

/** Swept sphere against a simple solid box. Inputs and contact normal are reused. */
export function collideSolidBox(p:Vec,v:Vec,r:number,previous:Vec,c:Vec,h:Vec,n:Vec):boolean{
 const minX=c.x-h.x-r,maxX=c.x+h.x+r,minY=c.y-h.y-r,maxY=c.y+h.y+r,minZ=c.z-h.z-r,maxZ=c.z+h.z+r;
 const dx=p.x-previous.x,dy=p.y-previous.y,dz=p.z-previous.z;
 let enter=0,leave=1,axis=-1,sign=0;
 // Scalar slab sweep; no per-contact vector or array allocation.
 for(let a=0;a<3;a++){
  const start=a===0?previous.x:a===1?previous.y:previous.z,delta=a===0?dx:a===1?dy:dz;
  const lo=a===0?minX:a===1?minY:minZ,hi=a===0?maxX:a===1?maxY:maxZ;
  if(Math.abs(delta)<1e-9){if(start<lo||start>hi)return false;continue;}
  let near=(lo-start)/delta,far=(hi-start)/delta;
  if(near>far){const swap=near;near=far;far=swap;}
  if(near>enter){enter=near;axis=a;sign=delta>0?-1:1;}
  leave=Math.min(leave,far);if(enter>leave)return false;
 }
 if(axis>=0){p.x=previous.x+dx*enter;p.y=previous.y+dy*enter;p.z=previous.z+dz*enter;}
 else{
  if(p.x<=minX||p.x>=maxX||p.y<=minY||p.y>=maxY||p.z<=minZ||p.z>=maxZ)return false;
  const x=p.x-c.x,y=p.y-c.y,z=p.z-c.z,ox=h.x+r-Math.abs(x),oy=h.y+r-Math.abs(y),oz=h.z+r-Math.abs(z);
  axis=ox<oy&&ox<oz?0:oy<oz?1:2;sign=(axis===0?x:axis===1?y:z)>=0?1:-1;
  if(axis===0)p.x=c.x+sign*(h.x+r);else if(axis===1)p.y=c.y+sign*(h.y+r);else p.z=c.z+sign*(h.z+r);
 }
 n.x=axis===0?sign:0;n.y=axis===1?sign:0;n.z=axis===2?sign:0;
 p.x+=n.x*.001;p.y+=n.y*.001;p.z+=n.z*.001;
 const speed=v.x*n.x+v.y*n.y+v.z*n.z;
 if(speed<0){v.x-=n.x*speed*1.5;v.y-=n.y*speed*1.5;v.z-=n.z*speed*1.5;}
 return true;
}
