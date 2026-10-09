import {CanvasTexture,Group,LinearFilter,Mesh,MeshBasicMaterial,PlaneGeometry,SRGBColorSpace} from '@iwsdk/core';

/** One reusable texture and quad. Only a new score redraws the digits. */
export function createScorePopup(){
 const canvas=document.createElement('canvas');canvas.width=768;canvas.height=384;
 const c=canvas.getContext('2d')!;
 const texture=new CanvasTexture(canvas);texture.colorSpace=SRGBColorSpace;
 texture.generateMipmaps=false;texture.minFilter=LinearFilter;
 const material=new MeshBasicMaterial({map:texture,transparent:true,depthTest:false,depthWrite:false,fog:false,toneMapped:false});
 const root=new Group();root.name='xr-score-popup';root.visible=false;
 const mesh=new Mesh(new PlaneGeometry(1,.5),material);mesh.renderOrder=4;root.add(mesh);
 const duration=1.65;
 let scope='',previous=0,age=duration;
 function paint(value:number){
  const text=String(value);let size=256;
  c.clearRect(0,0,canvas.width,canvas.height);c.textAlign='center';c.textBaseline='alphabetic';c.direction='ltr';
  c.font=`800 ${size}px Dahrooj, sans-serif`;
  size*=Math.min(1,640/Math.max(1,c.measureText(text).width));c.font=`800 ${size}px Dahrooj, sans-serif`;
  const m=c.measureText(text),y=(384+m.actualBoundingBoxAscent-m.actualBoundingBoxDescent)/2-9;
  // A dark rose edge, soft depth and a glossy pink face keep digits readable against sky and trees.
  c.lineJoin='round';c.lineWidth=14;c.strokeStyle='#65274e';c.fillStyle='#aa286d';
  c.strokeText(text,384,y+8);c.fillText(text,384,y+8);
  const jelly=c.createLinearGradient(0,y-m.actualBoundingBoxAscent,0,y+m.actualBoundingBoxDescent);
  jelly.addColorStop(0,'#fff5fc');jelly.addColorStop(.22,'#ffc4e5');jelly.addColorStop(.5,'#ff83c3');
  jelly.addColorStop(.56,'#ef5daf');jelly.addColorStop(1,'#c92f88');
  c.lineWidth=5;c.strokeStyle='#ffe0f4';c.strokeText(text,384,y);c.fillStyle=jelly;c.fillText(text,384,y);
  texture.needsUpdate=true;root.userData.value=value;
 }
 return {
  root,
  observe(nextScope:string,value:number){
   value=Number.isFinite(value)?Math.max(0,Math.floor(value)):0;
   if(nextScope!==scope){scope=nextScope;previous=value;age=duration;root.visible=false;return;}
   if(value>previous){paint(value);age=0;root.visible=true;}
   else if(value<previous){age=duration;root.visible=false;}
   previous=value;
  },
  step(dt:number){
   if(age>=duration){root.visible=false;return;}
   age=Math.min(duration,age+dt);
   const enter=Math.min(1,age/.22),pop=1-Math.pow(1-enter,3),t=Math.max(0,age-.14);
   const wobble=Math.sin(t*18)*Math.exp(-t*6)*.11,scale=.42+.58*pop;
   const fade=Math.min(1,Math.max(0,(age-1.05)/.6));
   root.scale.set(scale*(1+wobble),scale*(1-wobble),1);root.position.y=age*.045;
   root.rotation.z=Math.sin(t*12)*Math.exp(-t*6)*.025;
   material.opacity=Math.min(1,age/.07)*(1-fade*fade*(3-2*fade));root.visible=age<duration;
  }
 };
}
