import {CanvasTexture,LinearFilter,Mesh,MeshBasicMaterial,PlaneGeometry,SRGBColorSpace,Vector3} from '@iwsdk/core';
import {menuDepth} from './menu-depth';
import {JELLY_COLORS} from '../core/appearance';
import {drawMenuCard,drawMenuIcon,drawMenuPaper,MENU_INK} from './menu-art';
import {XR_MODE_CATALOG} from './mode-catalog';

export const MENU_PAGES=[['modes','الأنماط','Modes'],['appearance','المظهر','Appearance'],['play','اللعب','Play'],['world','العالم','World'],['challenges','التحديات','Challenges'],['system','عام','General'],['about','عن اللعبة','About']] as const;
export type MenuPage=typeof MENU_PAGES[number][0];
export const MENU_STYLES=[['jelly','جلي','Jelly'],['fur','فرو','Fur'],['bubble','فقاعة','Bubble']] as const;
export const MENU_THROWS=[['trigger','زناد','Trigger'],['hand','يد','Hand'],['sling','نبيطة','Slingshot']] as const;
export const MENU_SHOTS=[['bolt','برق','Bolt'],['mini','دحروج','Dahrooj'],['bubble','فقاعة','Bubble'],['firework','ألعاب نارية','Firework']] as const;
export const MENU_ACCESSORIES=[['','بدون','None',0],['party','قبعة حفلة','Party hat',1],['glasses','نظارة شمسية','Sunglasses',3],['cap','كاب','Cap',5],['flower','وردة','Flower',7],['crown','تاج','Crown',10],['headphones','سماعات','Headphones',12],['scarf','وشاح','Scarf',14]] as const;
// Names and descriptions taken from the shipped credits.html, not new ownership claims.
export const MENU_CREDITS=[
 ['Aboden Games','دحروج والتصميم والموسيقى والأصوات الأصلية','Dahrooj, design, original music and sounds'],
 ['Bruno Simon','أصول وأجزاء من العالم','Environment assets and adapted world work'],
 ['Amazon','نماذج وحدات التحكم','Controller models'],
 ['Meta · Three.js / super-three','أدوات الواقع الممتد ومكتبات الرسم','Immersive tools and rendering libraries'],
] as const;
export type MenuModel={english:boolean;kind:string|null;mode:string;style:string;jellyColor:string;throwStyle:string;shotStyle:string;time:string;weather:string;accessory:string;done:number;resetArmed:boolean;challenges:{id:string;title:string;en:string;value:number;goal:number}[]};
export type MenuButton={kind:string;id:string;ar:string;en:string;x:number;y:number;w:number;h:number;selected?:boolean;disabled?:boolean;color?:string;fill?:string;icon?:string;sub?:string};
type Mode=readonly [string,string,string,...string[]];
const W=1200,H=1000,WIDTH=.765,HEIGHT=WIDTH*H/W;
const LIST_TOP=244,LIST_HEIGHT=552,ROW_HEIGHT=96,TRACK_TOP=300,TRACK_HEIGHT=440;
const COLORS=[['#e2603f','#fff0e9'],['#ba7c15','#fff5d9'],['#52809e','#eaf4fb'],['#558365','#ecf6eb'],['#9367ae','#f3ecfa'],['#b56356','#faeee7'],['#b87426','#fff1da'],['#57827b','#eaf5f0'],['#7c73b3','#f1efff'],['#558d85','#e9f5df'],['#ae7290','#fff0f4']];
const contentX=(english:boolean)=>english?288:24;
const grid=(index:number,cols:number,y:number,h:number,english:boolean,gap=16)=>{const w=(888-gap*(cols-1))/cols,col=index%cols;return {x:contentX(english)+(english?col:cols-1-col)*(w+gap),y:y+Math.floor(index/cols)*(h+gap),w,h};};
export function modeCell(index:number,english:boolean){return grid(index,3,184,164,english);}
export function modeAtUV(u:number,v:number,english:boolean){
 if(!Number.isFinite(u)||!Number.isFinite(v))return -1;
 const x=u*W,y=(1-v)*H;for(let i=0;i<XR_MODE_CATALOG.length;i++){const b=modeCell(i,english);if(x>=b.x&&x<b.x+b.w&&y>=b.y&&y<b.y+b.h)return i;}return -1;
}
export function createFlatModePanel(modes:readonly Mode[],drawAccessory?:(ctx:CanvasRenderingContext2D,id:string,x:number,y:number,locked:boolean)=>void){
 const canvas=document.createElement('canvas');canvas.width=W;canvas.height=H;
 const ctx=canvas.getContext('2d')!,texture=new CanvasTexture(canvas);texture.colorSpace=SRGBColorSpace;texture.generateMipmaps=false;texture.minFilter=texture.magFilter=LinearFilter;
 const material=menuDepth(new MeshBasicMaterial({map:texture,fog:false,toneMapped:false}),true);material.depthTest=false;material.depthWrite=false;
 const mesh=new Mesh(new PlaneGeometry(WIDTH,HEIGHT),material);mesh.name='xr-menu';mesh.renderOrder=50;
 let key='',page:MenuPage='modes',appearance='character',challengeOffset=0,buttons:MenuButton[]=[],lastModel:MenuModel|null=null;
 const tr=(a:string,b:string)=>lastModel?.english?b:a;
 const text=(value:string,x:number,y:number,size=32,color=MENU_INK,max=850)=>{ctx.fillStyle=color;ctx.font=`500 ${size}px "Dahrooj",Tahoma,sans-serif`;ctx.fillText(value,x,y,max);};
 function round(x:number,y:number,w:number,h:number,r=20){ctx.beginPath();ctx.roundRect(x,y,w,h,r);}
 const scrollMax=()=>Math.max(0,(lastModel?.challenges.length??0)*ROW_HEIGHT-LIST_HEIGHT);
 function scrollBy(delta:number){if(page!=='challenges'||!Number.isFinite(delta))return false;const next=Math.max(0,Math.min(scrollMax(),challengeOffset+delta));if(next===challengeOffset)return false;challengeOffset=next;key='';return true;}
 function scrollTrack(){const height=Math.min(TRACK_HEIGHT,Math.max(54,TRACK_HEIGHT*LIST_HEIGHT/Math.max(LIST_HEIGHT,(lastModel?.challenges.length??0)*ROW_HEIGHT)));return {height,travel:TRACK_HEIGHT-height};}
 function layout(m:MenuModel){
  const english=m.english,base=contentX(english),out:MenuButton[]=[];
  const add=(kind:string,id:string,ar:string,en:string,box:{x:number;y:number;w:number;h:number},rest:Partial<MenuButton>={})=>out.push({kind,id,ar,en,...box,icon:kind==='weather'&&id==='rain'?'weather-rain':kind==='jellyColor'?'palette':id||'none',...rest});
  MENU_PAGES.forEach(([id,ar,en],i)=>add('tab',id,ar,en,{x:english?24:948,y:184+i*91,w:228,h:73},{selected:id===page}));
  add('close','close','إغلاق','Close',{x:english?24:948,y:866,w:228,h:74});
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
   challengeOffset=Math.min(scrollMax(),challengeOffset);
   add('scroll','content','','',{x:base,y:LIST_TOP,w:824,h:LIST_HEIGHT});
   add('scroll','track','','',{x:base+838,y:TRACK_TOP,w:50,h:TRACK_HEIGHT});
   add('scrollStep','up','أعلى','Up',{x:base+838,y:LIST_TOP,w:50,h:48},{disabled:challengeOffset===0});
   add('scrollStep','down','أسفل','Down',{x:base+838,y:748,w:50,h:48},{disabled:challengeOffset===scrollMax()});
   add('reset','reset',m.resetArmed?'تأكيد التصفير؟':'تصفير التحديات',m.resetArmed?'Confirm reset?':'Reset challenges',{x:base+224,y:864,w:440,h:74},{color:m.resetArmed?'#c8442f':undefined});
  }
  if(page==='system'){
   add('lang','lang','English','العربية',{x:base,y:280,w:888,h:112});
   add('exit','exit','الخروج من اللعب','Exit session',{x:base,y:550,w:888,h:112});
  }
  return out;
 }
 function button(b:MenuButton,index:number,hot:number){
  if(b.kind==='scroll')return;
  const on=b.selected,hover=index===hot&&!b.disabled,cx=b.x+b.w/2,ink=b.color||'#e2603f';
  drawMenuCard(ctx,b.x,b.y,b.w,b.h,b.fill||(on?'#fae6c0':'#fffdf4'),ink,!!on,hover,!!b.disabled);
  if(b.kind==='mode'){drawMenuIcon(ctx,b.id,cx,b.y+62,85,ink);text(tr(b.ar,b.en),cx,b.y+139,30,MENU_INK,b.w-26);}
  else if(b.kind==='style'){
   const color=b.id==='jelly'?JELLY_COLORS.find(c=>c.id===lastModel?.jellyColor)?.hex??0xff69b4:b.id==='fur'?0xdcccb7:0xb9dfef;
   drawMenuIcon(ctx,b.id,cx,b.y+76,100,'#'+color.toString(16).padStart(6,'0'));
   text(tr(b.ar,b.en),cx,b.y+165,31);
  }else if(b.kind==='acc'){
   if(b.id){ctx.save();ctx.translate(cx,b.y+89);ctx.scale(1.35,1.35);drawAccessory?.(ctx,b.id,0,0,!!b.disabled);ctx.restore();}
   else drawMenuIcon(ctx,'none',cx,b.y+83,58);
   text(tr(b.ar,b.en),cx,b.y+159,27,b.disabled?'#93836e':MENU_INK,b.w-18);if(b.sub)text(b.sub,cx,b.y+200,21,'#93836e',b.w-18);
   if(b.disabled)drawMenuIcon(ctx,'lock',b.x+23,b.y+24,27);
  }else if(b.kind==='jellyColor'){
   drawMenuIcon(ctx,'jelly',cx,b.y+30,47,b.color);text(tr(b.ar,b.en),cx,b.y+80,26,MENU_INK,b.w-24);
  }else if(b.kind==='scrollStep'){drawMenuIcon(ctx,b.id,cx,b.y+22,27);}
  else if(['time','weather','throw','shot'].includes(b.kind)){
   drawMenuIcon(ctx,b.icon!,cx,b.y+38,b.kind==='shot'?53:43);text(tr(b.ar,b.en),cx,b.y+b.h-23,28,b.disabled?'#93836e':MENU_INK,b.w-24);
  }else{
   const english=lastModel?.english,iconX=english?b.x+32:b.x+b.w-32;
   drawMenuIcon(ctx,b.icon!,iconX,b.y+b.h/2-2,b.kind==='tab'?38:36);
   text(tr(b.ar,b.en),cx+(english?20:-20),b.y+b.h/2+9,b.kind==='tab'?27:29,b.disabled?'#93836e':MENU_INK,b.w-78);
  }
  if(on&&b.kind!=='tab')drawMenuIcon(ctx,'check',b.x+b.w-22,b.y+22,25);
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
   text(tr(`إنجازاتك · ${m.challenges.filter(c=>c.value>=c.goal).length} من ${m.challenges.length}`,`Your progress · ${m.challenges.filter(c=>c.value>=c.goal).length} of ${m.challenges.length}`),cx,212,30);
   ctx.save();ctx.beginPath();ctx.rect(base,LIST_TOP,824,LIST_HEIGHT);ctx.clip();
   m.challenges.forEach((c,i)=>{const y=LIST_TOP+i*ROW_HEIGHT-challengeOffset,done=c.value>=c.goal;if(y+88<LIST_TOP||y>LIST_TOP+LIST_HEIGHT)return;
    ctx.fillStyle=done?'#eaf1d9':'#fffdf5';round(base,y,824,88,12);ctx.fill();
    const iconX=m.english?base+34:base+790;drawMenuIcon(ctx,done?'check':'trophy',iconX,y+37,35);
    ctx.textAlign=m.english?'left':'right';text(tr(c.title,c.en),m.english?base+66:base+758,y+41,28,MENU_INK,610);
    ctx.textAlign=m.english?'right':'left';text(`${c.value} / ${c.goal}`,m.english?base+808:base+16,y+41,25,'#648155',124);
    ctx.fillStyle='#e5dcc6';round(base+24,y+64,776,8,4);ctx.fill();
    const progress=Math.max(0,Math.min(1,c.value/Math.max(1,c.goal)))*776;ctx.fillStyle=done?'#8cb772':'#e7b767';round(m.english?base+24:base+800-progress,y+64,progress,8,4);ctx.fill();
   });ctx.restore();ctx.textAlign='center';
   ctx.fillStyle='#e1cfaf';round(base+856,TRACK_TOP,14,TRACK_HEIGHT,7);ctx.fill();
   const track=scrollTrack();ctx.fillStyle='#a97e4e';round(base+846,TRACK_TOP+(scrollMax()?challengeOffset/scrollMax()*track.travel:0),34,track.height,12);ctx.fill();
   text(tr('اسحب القائمة أو حرّك العصا لأسفل','Drag the list or move the stick down'),cx,834,25,'#927657');
  }
  if(page==='system'){text(tr('اللغة','Language'),cx,238,32);text(tr('جلسة اللعب','Play session'),cx,504,32);}
  if(page==='about'){
   text('Dahrooj Quest',cx,209,42);text(tr('امسك دحروج والعب في ١١ نمطًا مرحًا.','Play with Dahrooj across 11 playful modes.'),cx,265,29);
   text(tr('واقع افتراضي وواقع مختلط.','Virtual and mixed reality.'),cx,304,28,'#666a74');
   MENU_CREDITS.forEach(([name,ar,en],i)=>{const y=397+i*100;ctx.direction='ltr';text(name,cx,y,i===0?34:28);ctx.direction=m.english?'ltr':'rtl';text(tr(ar,en),cx,y+34,24,'#88745d');});
  }
 }
 return {mesh,
  get page(){return page;},get challengeScroll(){return {offset:challengeOffset,max:scrollMax()};},get buttons(){return buttons;},get size(){return {w:W,h:H};},
  scrollBy,
  scrollAxis(axis:number,dt:number){if(!Number.isFinite(axis)||!Number.isFinite(dt)||Math.abs(axis)<.22||dt<=0)return false;return scrollBy(Math.sign(axis)*(Math.min(1,Math.abs(axis))-.22)/.78*Math.min(dt,.05)*700);},
  dragScroll(fromV:number,toV:number,track=false){if(!Number.isFinite(fromV)||!Number.isFinite(toV))return false;return scrollBy((track?-1:1)*(toV-fromV)*H*(track?scrollMax()/scrollTrack().travel:1));},
  point(index:number,english:boolean){const b=modeCell(index,english);return new Vector3(((b.x+b.w/2)/W-.5)*WIDTH,(.5-(b.y+b.h/2)/H)*HEIGHT,0);},
  show(next:MenuPage){if(!MENU_PAGES.some(p=>p[0]===next))return;page=next;key='';},
  action(index:number){const b=buttons[index];return b&&!b.disabled?b:null;},
  navigate(b:MenuButton){
   if(b.kind==='tab'){page=b.id as MenuPage;key='';return true;}
   if(b.kind==='appearance'){appearance=b.id;key='';return true;}
   if(b.kind==='scrollStep'){scrollBy(b.id==='down'?ROW_HEIGHT*2:-ROW_HEIGHT*2);return true;}return false;
  },
  hit(u:number,v:number){if(!Number.isFinite(u)||!Number.isFinite(v))return -1;const x=u*W,y=(1-v)*H;return buttons.findIndex(b=>!b.disabled&&x>=b.x&&x<b.x+b.w&&y>=b.y&&y<b.y+b.h);},
  draw(model:MenuModel,hot=-1){
   const next=JSON.stringify([page,appearance,challengeOffset,hot,model]);if(key===next)return;key=next;lastModel=model;buttons=layout(model);
   drawMenuPaper(ctx,model.english);ctx.textAlign='center';ctx.direction=model.english?'ltr':'rtl';
   const base=contentX(model.english),entry=MENU_PAGES.find(p=>p[0]===page)!;
   drawMenuIcon(ctx,page,base+444+(model.english?-155:155),79,49);
   text(tr(entry[1],entry[2]),base+444,94,42);text(tr('دحروج','Dahrooj'),model.english?138:1062,91,34);
   details(model);buttons.forEach((b,i)=>button(b,i,hot));
   if(page==='modes')text(tr('اختر نمطك وابدأ اللعب','Choose a mode and play'),base+444,942,28,'#666a74');
   texture.needsUpdate=true;
  }
 };
}
