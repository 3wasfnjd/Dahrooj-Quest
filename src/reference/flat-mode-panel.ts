import {CanvasTexture,LinearFilter,Mesh,MeshBasicMaterial,PlaneGeometry,SRGBColorSpace,Vector3} from '@iwsdk/core';
import {menuDepth} from './menu-depth';

type Mode=readonly [string,string,string,...string[]];
const W=1200,H=1000,WIDTH=.9,HEIGHT=WIDTH*H/W;
export function modeCell(index:number,english:boolean){
 const col=index%3,row=Math.floor(index/3);
 return {x:48+(english?col:2-col)*376,y:156+row*250,w:352,h:226};
}
export function modeAtUV(u:number,v:number,english:boolean){
 if(!Number.isFinite(u)||!Number.isFinite(v))return -1;
 const x=u*W,y=(1-v)*H;
 for(let i=0;i<9;i++){const b=modeCell(i,english);if(x>=b.x&&x<b.x+b.w&&y>=b.y&&y<b.y+b.h)return i;}
 return -1;
}
// All icons, labels and the selection outline are pixels in one opaque surface.
export function createFlatModePanel(modes:readonly Mode[]){
 const canvas=document.createElement('canvas');canvas.width=W;canvas.height=H;
 const ctx=canvas.getContext('2d')!;
 const texture=new CanvasTexture(canvas);texture.colorSpace=SRGBColorSpace;texture.generateMipmaps=false;texture.minFilter=texture.magFilter=LinearFilter;
 const material=menuDepth(new MeshBasicMaterial({map:texture,fog:false,toneMapped:false}),true);
 // This single late surface neither reads nor replaces world depth. No internal 3D layers.
 material.depthTest=false;material.depthWrite=false;
 const mesh=new Mesh(new PlaneGeometry(WIDTH,HEIGHT),material);mesh.name='xr-flat-mode-panel';mesh.renderOrder=50;
 let key='';
 function icon(id:string,x:number,y:number){
  ctx.save();ctx.translate(x,y);ctx.strokeStyle='#2c2d3d';ctx.fillStyle='#e2603f';ctx.lineWidth=6;ctx.lineCap='round';ctx.lineJoin='round';
  const line=(a:number,b:number,c:number,d:number)=>{ctx.beginPath();ctx.moveTo(a,b);ctx.lineTo(c,d);ctx.stroke();};
  const circle=(a:number,b:number,r:number)=>{ctx.beginPath();ctx.arc(a,b,r,0,Math.PI*2);ctx.stroke();};
  if(id==='goal'){ctx.strokeRect(-46,-28,92,62);for(const n of [-23,0,23])line(n,-28,n,34);line(-46,3,46,3);circle(25,29,15);}
  else if(id==='hoop'){ctx.strokeRect(-42,-37,84,44);ctx.beginPath();ctx.ellipse(0,15,33,10,0,0,Math.PI*2);ctx.stroke();for(const n of [-25,0,25])line(n,20,n*.6,47);line(-15,47,15,47);}
  else if(id==='window'){ctx.strokeRect(-37,-38,74,76);line(0,-38,0,38);line(-37,0,37,0);}
  else if(id==='cans'){for(const [a,b] of [[-29,8],[8,8],[-10,-28]]){ctx.strokeRect(a,b,23,31);line(a+3,b+8,a+20,b+8);}}
  else if(id==='bowling'){for(const a of [-30,0,30]){circle(a,-22,8);ctx.beginPath();ctx.roundRect(a-10,-11,20,44,9);ctx.stroke();}circle(33,39,15);}
  else if(id==='bricks'){for(let row=0;row<3;row++)for(let col=0;col<3;col++)ctx.strokeRect(-48+col*34+(row%2?8:0),-30+row*24,28,18);}
  else if(id==='fair'){ctx.beginPath();ctx.moveTo(-48,-3);ctx.lineTo(0,-42);ctx.lineTo(48,-3);ctx.closePath();ctx.stroke();ctx.strokeRect(-40,-3,80,43);for(const a of [-22,0,22])line(a,0,a,15);}
  else if(id==='climb'){ctx.beginPath();ctx.moveTo(-50,39);ctx.lineTo(-10,-38);ctx.lineTo(42,39);ctx.closePath();ctx.stroke();line(-10,-38,-10,-57);line(-10,-57,14,-49);line(14,-49,-10,-42);}
  else{for(const [a,b] of [[-30,-24],[25,-14],[-5,30]]){circle(a,b,19);ctx.fillRect(a-8,b-4,4,5);ctx.fillRect(a+4,b-4,4,5);}}
  ctx.restore();
 }
 return {mesh,
  point(index:number,english:boolean){const b=modeCell(index,english);return new Vector3(((b.x+b.w/2)/W-.5)*WIDTH,(.5-(b.y+b.h/2)/H)*HEIGHT,0);},
  hit(u:number,v:number,english:boolean){return modeAtUV(u,v,english);},
  draw(english:boolean,hot:number,active:string){
   const next=[english,hot,active].join('|');if(key===next)return;key=next;
   ctx.fillStyle='#ffffff';ctx.fillRect(0,0,W,H);ctx.textAlign='center';ctx.direction=english?'ltr':'rtl';ctx.fillStyle='#2c2d3d';
   ctx.font='800 56px "Dahrooj",Tahoma,sans-serif';ctx.fillText(english?'Choose a mode':'اختر النمط',W/2,90);
   modes.forEach(([id,ar,en],i)=>{const b=modeCell(i,english),selected=i===hot;
    ctx.strokeStyle=selected?'#e2603f':id===active?'#438868':'#dce1e5';ctx.lineWidth=selected?8:id===active?5:2;
    ctx.beginPath();ctx.roundRect(b.x+5,b.y+5,b.w-10,b.h-10,20);ctx.stroke();
    icon(id,b.x+b.w/2,b.y+83);ctx.fillStyle='#2c2d3d';ctx.font='800 38px "Dahrooj",Tahoma,sans-serif';ctx.fillText(english?en:ar,b.x+b.w/2,b.y+176,b.w-32);
   });
   ctx.fillStyle='#535665';ctx.font='600 29px "Dahrooj",Tahoma,sans-serif';ctx.fillText(english?'Point and press trigger · Y closes':'وجّه المؤشر واضغط الزناد · Y للإغلاق',W/2,963);texture.needsUpdate=true;
  }
 };
}
