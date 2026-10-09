import {CanvasTexture,LinearFilter,Mesh,MeshBasicMaterial,PlaneGeometry,SRGBColorSpace,Vector3} from '@iwsdk/core';
import {menuDepth} from './menu-depth';
import {JELLY_COLORS} from '../core/appearance';

export const MENU_PAGES=[['modes','الأنماط','Modes'],['appearance','المظهر','Appearance'],['play','اللعب','Play'],['world','العالم','World'],['challenges','التحديات','Challenges'],['system','عام','General'],['about','عن اللعبة','About']] as const;
export type MenuPage=typeof MENU_PAGES[number][0];
export const MENU_STYLES=[['jelly','جلي','Jelly'],['fur','فرو','Fur'],['bubble','فقاعة','Bubble']] as const;
export const MENU_THROWS=[['trigger','زناد','Trigger'],['hand','يد','Hand'],['sling','نبيطة','Slingshot']] as const;
export const MENU_SHOTS=[['bolt','برق','Bolt'],['mini','دحروج','Dahrooj'],['bubble','فقاعة','Bubble'],['firework','ألعاب نارية','Firework']] as const;
export const MENU_ACCESSORIES=[['','بدون','None',0],['party','قبعة حفلة','Party hat',1],['glasses','نظارة شمسية','Sunglasses',3],['cap','كاب','Cap',5],['flower','وردة','Flower',7],['crown','تاج','Crown',10],['headphones','سماعات','Headphones',12],['scarf','وشاح','Scarf',14]] as const;
// Names and descriptions taken from the shipped credits.html, not new ownership claims.
export const MENU_CREDITS=[
 ['Aboden Games','الفكرة والشخصية والموسيقى الأصلية','Concept, character and original music'],
 ['Bruno Simon','أصول وأجزاء من العالم','Environment assets and adapted world work'],
 ['The Baloo 2 Project Authors / Ek Type','الخطوط','Fonts'],
 ['Amazon','نماذج وحدات التحكم','Controller models'],
 ['Rudmer_Rotteveel','صوت الألعاب النارية','Firework recording'],
 ['Meta Platforms & contributors','IWSDK — أدوات الواقع الممتد','IWSDK — immersive tools'],
 ['Three.js / super-three contributors','مكتبات الرسم','Rendering libraries'],
] as const;
export type MenuModel={english:boolean;kind:string|null;mode:string;style:string;jellyColor:string;throwStyle:string;shotStyle:string;time:string;weather:string;accessory:string;done:number;resetArmed:boolean;challenges:{id:string;title:string;en:string;value:number;goal:number}[]};
export type MenuButton={kind:string;id:string;ar:string;en:string;x:number;y:number;w:number;h:number;selected?:boolean;disabled?:boolean;color?:string;fill?:string;icon?:string;sub?:string};
type Mode=readonly [string,string,string,...string[]];
const W=1200,H=1000,WIDTH=.9,HEIGHT=WIDTH*H/W,ROWS=6;
const COLORS=[['#e2603f','#fff0e9'],['#ba7c15','#fff5d9'],['#52809e','#eaf4fb'],['#558365','#ecf6eb'],['#9367ae','#f3ecfa'],['#b56356','#faeee7'],['#b87426','#fff1da'],['#57827b','#eaf5f0'],['#7c73b3','#f1efff']];
const contentX=(english:boolean)=>english?288:24;
const grid=(index:number,cols:number,y:number,h:number,english:boolean,gap=16)=>{const w=(888-gap*(cols-1))/cols,col=index%cols;return {x:contentX(english)+(english?col:cols-1-col)*(w+gap),y:y+Math.floor(index/cols)*(h+gap),w,h};};
export function modeCell(index:number,english:boolean){return grid(index,3,184,216,english);}
export function modeAtUV(u:number,v:number,english:boolean){
 if(!Number.isFinite(u)||!Number.isFinite(v))return -1;
 const x=u*W,y=(1-v)*H;for(let i=0;i<9;i++){const b=modeCell(i,english);if(x>=b.x&&x<b.x+b.w&&y>=b.y&&y<b.y+b.h)return i;}return -1;
}
export function createFlatModePanel(modes:readonly Mode[],drawAccessory?:(ctx:CanvasRenderingContext2D,id:string,x:number,y:number,locked:boolean)=>void){
 const canvas=document.createElement('canvas');canvas.width=W;canvas.height=H;
 const ctx=canvas.getContext('2d')!,texture=new CanvasTexture(canvas);texture.colorSpace=SRGBColorSpace;texture.generateMipmaps=false;texture.minFilter=texture.magFilter=LinearFilter;
 const material=menuDepth(new MeshBasicMaterial({map:texture,fog:false,toneMapped:false}),true);material.depthTest=false;material.depthWrite=false;
 const mesh=new Mesh(new PlaneGeometry(WIDTH,HEIGHT),material);mesh.name='xr-menu';mesh.renderOrder=50;
 let key='',page:MenuPage='modes',appearance='character',challengePage=0,buttons:MenuButton[]=[],lastModel:MenuModel|null=null;
 const tr=(a:string,b:string)=>lastModel?.english?b:a;
 const text=(value:string,x:number,y:number,size=32,color='#2c2d3d',max=850)=>{ctx.fillStyle=color;ctx.font=`700 ${size}px "Dahrooj",Tahoma,sans-serif`;ctx.fillText(value,x,y,max);};
 function round(x:number,y:number,w:number,h:number,r=20){ctx.beginPath();ctx.roundRect(x,y,w,h,r);}
 function layout(m:MenuModel){
  const english=m.english,base=contentX(english),out:MenuButton[]=[];
  const add=(kind:string,id:string,ar:string,en:string,box:{x:number;y:number;w:number;h:number},rest:Partial<MenuButton>={})=>out.push({kind,id,ar,en,...box,...rest});
  MENU_PAGES.forEach(([id,ar,en],i)=>add('tab',id,ar,en,{x:english?24:948,y:184+i*91,w:228,h:73},{selected:id===page}));
  add('close','close','إغلاق ×','Close ×',{x:english?24:948,y:866,w:228,h:74});
  if(page==='modes')modes.forEach(([id,ar,en],i)=>add('mode',id,ar,en,modeCell(i,english),{selected:id===m.mode,color:COLORS[i][0],fill:COLORS[i][1],icon:id}));
  if(page==='appearance'){
   [['character','دحروج','Dahrooj'],['accessories','الإكسسوارات','Accessories']].forEach(([id,ar,en],i)=>add('appearance',id,ar,en,grid(i,2,184,66,english),{selected:appearance===id}));
   if(appearance==='character'){
    MENU_STYLES.forEach(([id,ar,en],i)=>add('style',id,ar,en,grid(i,3,282,200,english),{selected:id===m.style,icon:id}));
    if(m.style==='jelly')JELLY_COLORS.forEach((c,i)=>add('jellyColor',c.id,c.ar,c.en,grid(i,4,575,102,english),{selected:c.id===m.jellyColor,color:'#'+c.hex.toString(16).padStart(6,'0')}));
   }else MENU_ACCESSORIES.forEach(([id,ar,en,need],i)=>add('acc',id,ar,en,grid(i,4,304,228,english),{selected:id===m.accessory,disabled:m.done<need,sub:m.done<need?tr(`يحتاج ${need} تحديات`,`Needs ${need} challenges`):undefined}));
  }
  if(page==='play'){
   MENU_THROWS.forEach(([id,ar,en],i)=>add('throw',id,ar,en,grid(i,3,244,118,english),{selected:id===m.throwStyle}));
   MENU_SHOTS.forEach(([id,ar,en],i)=>add('shot',id,ar,en,grid(i,2,472,142,english),{selected:id===m.shotStyle}));
  }
  if(page==='world'){
   if(m.kind==='immersive-vr'){
    [['auto','تلقائي','Auto'],['day','نهار','Day'],['dusk','غروب','Dusk'],['night','ليل','Night'],['dawn','فجر','Dawn']].forEach(([id,ar,en],i)=>add('time',id,ar,en,grid(i,5,244,112,english),{selected:id===m.time}));
    [['auto','تلقائي','Auto'],['clear','صافي','Clear'],['rain','مطر','Rain'],['snow','ثلج','Snow']].forEach(([id,ar,en],i)=>add('weather',id,ar,en,grid(i,4,466,112,english),{selected:id===m.weather}));
   }
   add('place','place',m.kind==='immersive-ar'?'إعادة تثبيت العالم':'توسيط العالم',m.kind==='immersive-ar'?'Re-pin world':'Recentre world',{x:base,y:710,w:888,h:106});
  }
  if(page==='challenges'){
   const max=Math.max(0,Math.ceil(m.challenges.length/ROWS)-1);challengePage=Math.min(max,challengePage);
   add('page','prev','السابق','Previous',grid(0,3,808,74,english),{disabled:challengePage===0});
   add('reset','reset',m.resetArmed?'تأكيد التصفير؟':'تصفير التحديات',m.resetArmed?'Confirm reset?':'Reset challenges',grid(1,3,808,74,english),{color:m.resetArmed?'#c8442f':undefined});
   add('page','next','التالي','Next',grid(2,3,808,74,english),{disabled:challengePage===max});
  }
  if(page==='system'){
   add('lang','lang','English','العربية',{x:base,y:280,w:888,h:112});
   add('exit','exit','الخروج من اللعب','Exit session',{x:base,y:550,w:888,h:112});
  }
  return out;
 }
 function icon(id:string,x:number,y:number,color:string){
  ctx.save();ctx.translate(x,y);ctx.strokeStyle=color;ctx.fillStyle=color;ctx.lineWidth=6;ctx.lineCap='round';ctx.lineJoin='round';
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
 function button(b:MenuButton,index:number,hot:number){
  const on=b.selected,hover=index===hot&&!b.disabled,cx=b.x+b.w/2,ink=b.color||'#e2603f';
  ctx.fillStyle=b.fill||(on?'#fff0e9':'#ffffff');round(b.x,b.y,b.w,b.h);ctx.fill();
  ctx.strokeStyle=b.disabled?'#e6e8eb':hover?ink:on?ink:'#dce1e5';ctx.lineWidth=hover?6:on?4:2;round(b.x+3,b.y+3,b.w-6,b.h-6);ctx.stroke();
  if(b.kind==='mode'){icon(b.id,cx,b.y+77,ink);text(tr(b.ar,b.en),cx,b.y+167,34,'#2c2d3d',b.w-24);}
  else if(b.kind==='style'){
   const color=b.id==='jelly'?JELLY_COLORS.find(c=>c.id===lastModel?.jellyColor)?.hex??0xff69b4:b.id==='fur'?0xdcccb7:0xb9dfef;
   ctx.fillStyle='#'+color.toString(16).padStart(6,'0');ctx.beginPath();ctx.arc(cx,b.y+74,42,0,Math.PI*2);ctx.fill();
   for(const dx of [-14,14]){ctx.fillStyle='#ffffff';ctx.beginPath();ctx.arc(cx+dx,b.y+69,10,0,Math.PI*2);ctx.fill();ctx.fillStyle='#2c2d3d';ctx.beginPath();ctx.arc(cx+dx,b.y+69,4,0,Math.PI*2);ctx.fill();}
   text(tr(b.ar,b.en),cx,b.y+161,34);
  }else if(b.kind==='acc'){
   if(b.id){ctx.save();ctx.translate(cx,b.y+81);ctx.scale(1.35,1.35);drawAccessory?.(ctx,b.id,0,0,!!b.disabled);ctx.restore();}
   else text('—',cx,b.y+92,46);
   text(tr(b.ar,b.en),cx,b.y+159,27,b.disabled?'#85878e':'#2c2d3d',b.w-18);if(b.sub)text(b.sub,cx,b.y+200,21,'#85878e',b.w-18);
  }else if(b.kind==='jellyColor'){
   ctx.fillStyle=b.color!;round(b.x+12,b.y+12,b.w-24,30,10);ctx.fill();text((on?'✓ ':'')+tr(b.ar,b.en),cx,b.y+77,27,'#2c2d3d',b.w-24);
  }else text(tr(b.ar,b.en),cx,b.y+b.h/2+11,b.kind==='tab'?29:30,b.disabled?'#aaaeb5':'#2c2d3d',b.w-22);
 }
 function details(m:MenuModel){
  const base=contentX(m.english),cx=base+444;
  if(page==='appearance'&&appearance==='character')text(m.style==='jelly'?tr('لون الجلي','Jelly colour'):tr('اختر مظهر دحروج','Choose Dahrooj’s look'),cx,540,30);
  if(page==='appearance'&&appearance==='accessories')text(tr(`مكافآت التحديات · مكتمل ${m.done}`,`Challenge rewards · ${m.done} complete`),cx,866,28);
  if(page==='play'){text(tr('طريقة الرمي','Throw style'),cx,213,31);text(tr('نوع الطلقة','Projectile'),cx,428,31);}
  if(page==='world'){
   if(m.kind==='immersive-vr'){text(tr('وقت اليوم','Time of day'),cx,213,31);text(tr('الطقس','Weather'),cx,428,31);}
   else{text(tr('العالم في غرفتك','Your room is the world'),cx,315,42);text(tr('أعد التثبيت لاختيار سطح جديد','Re-pin to choose a new surface'),cx,400,31);}
  }
  if(page==='challenges'){
   const total=Math.max(1,Math.ceil(m.challenges.length/ROWS));text(tr(`إنجازاتك · ${m.challenges.filter(c=>c.value>=c.goal).length} من ${m.challenges.length}`,`Your progress · ${m.challenges.filter(c=>c.value>=c.goal).length} of ${m.challenges.length}`),cx,212,30);
   m.challenges.slice(challengePage*ROWS,(challengePage+1)*ROWS).forEach((c,i)=>{const y=242+i*88,done=c.value>=c.goal;
    ctx.fillStyle=done?'#edf7ed':'#f7f6f3';round(base,y,888,76,14);ctx.fill();ctx.textAlign=m.english?'left':'right';
    text((done?'✓ ':'')+tr(c.title,c.en),m.english?base+20:base+868,y+46,28,'#2c2d3d',716);
    ctx.textAlign=m.english?'right':'left';text(`${c.value} / ${c.goal}`,m.english?base+868:base+20,y+46,26,'#528369',120);ctx.textAlign='center';
   });text(`${challengePage+1} / ${total}`,cx,931,27);
  }
  if(page==='system'){text(tr('اللغة','Language'),cx,238,32);text(tr('جلسة اللعب','Play session'),cx,504,32);}
  if(page==='about'){
   text('Dahrooj Quest',cx,209,42);text(tr('امسك دحروج وارمه في تسعة أنماط مرحة.','Grab and throw Dahrooj across nine playful modes.'),cx,265,29);
   text(tr('واقع افتراضي وواقع مختلط.','Virtual and mixed reality.'),cx,304,28,'#666a74');
   MENU_CREDITS.forEach(([name,ar,en],i)=>{const y=374+i*78;ctx.direction='ltr';text(name,cx,y,28);ctx.direction=m.english?'ltr':'rtl';text(tr(ar,en),cx,y+31,23,'#666a74');});
  }
 }
 return {mesh,
  get page(){return page;},get challengePage(){return challengePage;},get buttons(){return buttons;},get size(){return {w:W,h:H};},
  point(index:number,english:boolean){const b=modeCell(index,english);return new Vector3(((b.x+b.w/2)/W-.5)*WIDTH,(.5-(b.y+b.h/2)/H)*HEIGHT,0);},
  show(next:MenuPage){if(!MENU_PAGES.some(p=>p[0]===next))return;page=next;key='';},
  action(index:number){const b=buttons[index];return b&&!b.disabled?b:null;},
  navigate(b:MenuButton){
   if(b.kind==='tab'){page=b.id as MenuPage;key='';return true;}
   if(b.kind==='appearance'){appearance=b.id;key='';return true;}
   if(b.kind==='page'){const max=Math.max(0,Math.ceil((lastModel?.challenges.length??0)/ROWS)-1);challengePage=Math.max(0,Math.min(max,challengePage+(b.id==='next'?1:-1)));key='';return true;}return false;
  },
  hit(u:number,v:number){if(!Number.isFinite(u)||!Number.isFinite(v))return -1;const x=u*W,y=(1-v)*H;return buttons.findIndex(b=>!b.disabled&&x>=b.x&&x<b.x+b.w&&y>=b.y&&y<b.y+b.h);},
  draw(model:MenuModel,hot=-1){
   const next=JSON.stringify([page,appearance,challengePage,hot,model]);if(key===next)return;key=next;lastModel=model;buttons=layout(model);
   ctx.fillStyle='#ffffff';ctx.fillRect(0,0,W,H);ctx.textAlign='center';ctx.direction=model.english?'ltr':'rtl';
   const base=contentX(model.english),entry=MENU_PAGES.find(p=>p[0]===page)!;
   text(tr(entry[1],entry[2]),base+444,94,48);text(tr('دحروج','Dahrooj'),model.english?138:1062,91,36);
   ctx.strokeStyle='#ece7df';ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(24,136);ctx.lineTo(1176,136);ctx.stroke();
   details(model);buttons.forEach((b,i)=>button(b,i,hot));
   if(page==='modes')text(tr('اختر نمطك وابدأ اللعب','Choose a mode and play'),base+444,942,28,'#666a74');
   texture.needsUpdate=true;
  }
 };
}
