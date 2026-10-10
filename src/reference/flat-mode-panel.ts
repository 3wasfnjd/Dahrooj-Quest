import {CanvasTexture,LinearFilter,LinearMipmapLinearFilter,Mesh,MeshBasicMaterial,Shape,ShapeGeometry,SRGBColorSpace,Vector3} from '@iwsdk/core';
import {menuDepth} from './menu-depth';
import {DAHROOJ_COLOR_CHOICES} from '../core/appearance';
import {drawMenuCard,drawMenuIcon,drawMenuPaper,drawMenuFooter,MENU_INK,MENU_LIGHT,MENU_CORNER} from './menu-art';
import {UNLOCKS,CHALLENGES,accessoryAvailable} from '../progression/challenges';
import {XR_MODE_CATALOG} from './mode-catalog';
import {questControls} from './quest-controls';

export const MENU_PAGES=[['modes','الأنماط','Modes'],['appearance','المظهر','Appearance'],['play','اللعب','Play'],['world','العالم','World'],['challenges','التحديات','Challenges'],['system','عام','General'],['about','عن اللعبة','About']] as const;
export type MenuPage=typeof MENU_PAGES[number][0];
export const MENU_STYLES=[['jelly','جلي','Jelly'],['fur','فرو','Fur'],['bubble','فقاعة','Bubble']] as const;
export const MENU_THROWS=[['trigger','زناد','Trigger'],['hand','يد','Hand'],['sling','نبيطة','Slingshot']] as const;
export const MENU_SHOTS=[['bolt','برق','Bolt'],['mini','دحروج','Dahrooj'],['bubble','فقاعة','Bubble'],['firework','ألعاب نارية','Firework']] as const;
export const MENU_ACCESSORIES=[['','بدون','None',0],['party','قبعة حفلة','Party hat',1],['glasses','نظارة شمسية','Sunglasses',3],['cap','كاب','Cap',5],['flower','وردة','Flower',7],['crown','تاج','Crown',10],['headphones','سماعات','Headphones',12],['scarf','وشاح','Scarf',14],['aviator','قبعة طيّار','Aviator cap',UNLOCKS.aviator],['woodhat','قبعة خشبية','Wooden hat',UNLOCKS.woodhat],['starGlasses','نظارة نجوم','Star glasses',UNLOCKS.starGlasses],['beanie','طاقية صوف','Wool hat',UNLOCKS.beanie]] as const;
// Names and descriptions taken from the shipped credits.html, not new ownership claims.
export const MENU_CREDITS=[
 ['Aboden Games','دحروج والتصميم والموسيقى والأصوات الأصلية','Dahrooj, design, original music and sounds'],
 ['Bruno Simon','أصول وأجزاء من العالم','Environment assets and adapted world work'],
 ['Amazon','نماذج وحدات التحكم','Controller models'],
 ['Meta · Three.js / super-three','أدوات الواقع الممتد ومكتبات الرسم','Immersive tools and rendering libraries'],
] as const;
export type MenuModel={english:boolean;kind:string|null;mode:string;style:string;jellyColor:string;throwStyle:string;shotStyle:string;time:string;weather:string;accessory:string;done:number;resetArmed:boolean;rewards?:Record<string,number>;challenges:{id:string;title:string;en:string;value:number;goal:number}[]};
export type MenuButton={kind:string;id:string;ar:string;en:string;x:number;y:number;w:number;h:number;selected?:boolean;disabled?:boolean;color?:string;fill?:string;icon?:string;sub?:string};
type Mode=readonly [string,string,string,...string[]];
const W=1200,H=1000,WIDTH=.765,HEIGHT=WIDTH*H/W;
const LIST_TOP=244,LIST_HEIGHT=552,ROW_HEIGHT=96,TRACK_TOP=300,TRACK_HEIGHT=440;
const contentX=(english:boolean)=>english?220:92;
const grid=(index:number,cols:number,y:number,h:number,english:boolean,gap=16)=>{const w=(888-gap*(cols-1))/cols,col=index%cols;return {x:contentX(english)+(english?col:cols-1-col)*(w+gap),y:y+Math.floor(index/cols)*(h+gap),w,h};};
export function modeCell(index:number,english:boolean){return grid(index,4,204,200,english,20);}
export function modeAtUV(u:number,v:number,english:boolean){
 if(!Number.isFinite(u)||!Number.isFinite(v))return -1;
 const x=u*W,y=(1-v)*H;for(let i=0;i<XR_MODE_CATALOG.length;i++){const b=modeCell(i,english);if(x>=b.x&&x<b.x+b.w&&y>=b.y&&y<b.y+b.h)return i;}return -1;
}
export function createFlatModePanel(modes:readonly Mode[]){
 const canvas=document.createElement('canvas');canvas.width=W;canvas.height=H;
 const ctx=canvas.getContext('2d')!,texture=new CanvasTexture(canvas);texture.colorSpace=SRGBColorSpace;
 // A world-sized menu is minified and viewed obliquely in both eyes. Average texels
 // across levels instead of undersampling thin strokes with a single linear lookup.
 texture.generateMipmaps=true;texture.minFilter=LinearMipmapLinearFilter;texture.magFilter=LinearFilter;texture.anisotropy=4;
 const material=menuDepth(new MeshBasicMaterial({map:texture,fog:false,toneMapped:false}),true);material.depthTest=false;material.depthWrite=false;
 // Cut the corners in the geometry itself: still one opaque, flat surface,
 // with no transparent mask or extra border layer competing between the eyes.
 const shape=new Shape(),r=MENU_CORNER/W*WIDTH,x=WIDTH/2,y=HEIGHT/2;
 shape.moveTo(-x+r,-y);shape.lineTo(x-r,-y);shape.absarc(x-r,-y+r,r,-Math.PI/2,0,false);
 shape.lineTo(x,y-r);shape.absarc(x-r,y-r,r,0,Math.PI/2,false);
 shape.lineTo(-x+r,y);shape.absarc(-x+r,y-r,r,Math.PI/2,Math.PI,false);
 shape.lineTo(-x,-y+r);shape.absarc(-x+r,-y+r,r,Math.PI,Math.PI*1.5,false);shape.closePath();
 const geometry=new ShapeGeometry(shape,12),positions=geometry.getAttribute('position'),uv=geometry.getAttribute('uv');
 for(let i=0;i<uv.count;i++)uv.setXY(i,positions.getX(i)/WIDTH+.5,positions.getY(i)/HEIGHT+.5);
 const mesh=new Mesh(geometry,material);mesh.name='xr-menu';mesh.renderOrder=50;
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
  MENU_PAGES.forEach(([id,ar,en],i)=>add('tab',id,ar,en,{x:english?58:1030,y:174+i*94,w:112,h:82},{selected:id===page,icon:id==='appearance'?'character':id}));
  add('close','close','إغلاق','Close',{x:english?58:1030,y:832,w:112,h:82});
  if(page==='modes')modes.forEach(([id,ar,en],i)=>add('mode',id,ar,en,modeCell(i,english),{selected:id===m.mode,icon:id}));
  if(page==='appearance'){
   [['character','دحروج','Dahrooj'],['accessories','الإكسسوارات','Accessories']].forEach(([id,ar,en],i)=>add('appearance',id,ar,en,grid(i,2,184,88,english),{selected:appearance===id}));
   if(appearance==='character'){
    MENU_STYLES.forEach(([id,ar,en],i)=>add('style',id,ar,en,grid(i,3,300,200,english),{selected:id===m.style,icon:id}));
    DAHROOJ_COLOR_CHOICES.forEach((c,i)=>add('jellyColor',c.id,c.ar,c.en,grid(i,4,575,102,english),{selected:c.id===m.jellyColor,color:c.hex===null?undefined:'#'+c.hex.toString(16).padStart(6,'0'),icon:c.id==='original'?'original':'palette'}));
   }else {
    const progress=m.rewards??Object.fromEntries(m.challenges.map(c=>[c.id,c.value]));
    MENU_ACCESSORIES.forEach(([id,ar,en,need],i)=>{const open=accessoryAvailable(id,m.done,progress),ch=CHALLENGES.find(c=>c[0]===need);
     add('acc',id,ar,en,grid(i,4,304,168,english),{selected:id===m.accessory,disabled:!open,sub:open?undefined:ch?tr(ch[2],ch[3]):tr(`يحتاج ${need} تحديات`,`Needs ${need} challenges`)});
    });
   }
  }
  if(page==='play'){
   MENU_THROWS.forEach(([id,ar,en],i)=>add('throw',id,ar,en,grid(i,3,218,100,english),{selected:id===m.throwStyle}));
   MENU_SHOTS.forEach(([id,ar,en],i)=>add('shot',id,ar,en,grid(i,4,385,100,english),{selected:id===m.shotStyle}));
  }
  if(page==='world'){
   if(m.kind==='immersive-vr'){
    [['auto','تلقائي','Auto'],['day','نهار','Day'],['dusk','غروب','Dusk'],['night','ليل','Night'],['dawn','فجر','Dawn']].forEach(([id,ar,en],i)=>add('time',id,ar,en,grid(i,5,244,112,english),{selected:id===m.time}));
    [['auto','تلقائي','Auto'],['clear','صافي','Clear'],['rain','مطر','Rain'],['snow','ثلج','Snow']].forEach(([id,ar,en],i)=>add('weather',id,ar,en,grid(i,4,466,112,english),{selected:id===m.weather}));
   }
   add('place','place',m.kind==='immersive-ar'?'إعادة تثبيت العالم':'توسيط العالم',m.kind==='immersive-ar'?'Re-pin world':'Recentre world',{x:base+314,y:660,w:260,h:156});
  }
  if(page==='challenges'){
   challengeOffset=Math.min(scrollMax(),challengeOffset);
   add('scroll','content','','',{x:base,y:LIST_TOP,w:824,h:LIST_HEIGHT});
   add('scroll','track','','',{x:base+838,y:TRACK_TOP,w:50,h:TRACK_HEIGHT});
   add('scrollStep','up','أعلى','Up',{x:base+838,y:LIST_TOP,w:50,h:48},{disabled:challengeOffset===0});
   add('scrollStep','down','أسفل','Down',{x:base+838,y:748,w:50,h:48},{disabled:challengeOffset===scrollMax()});
   add('reset','reset',m.resetArmed?'تأكيد التصفير؟':'تصفير التحديات',m.resetArmed?'Confirm reset?':'Reset challenges',{x:base+344,y:828,w:200,h:72},{color:m.resetArmed?'#c8442f':undefined});
  }
  if(page==='system'){
   add('lang','lang','English','العربية',{x:base+100,y:308,w:300,h:244},{color:'#5797b1',fill:'#a8d4df'});
   add('exit','exit','الخروج من اللعب','Exit session',{x:base+488,y:308,w:300,h:244},{color:'#b8734b',fill:'#e4b081'});
  }
  return out;
 }
 function button(b:MenuButton,index:number,hot:number){
  if(b.kind==='scroll')return;
  const on=b.selected,hover=index===hot&&!b.disabled,cx=b.x+b.w/2,cy=b.y+b.h/2,ink=b.disabled?'#9a9b97':on?MENU_LIGHT:MENU_INK;
  drawMenuCard(ctx,b.x,b.y,b.w,b.h,!!on,hover,!!b.disabled);
  // Only the colour selector uses colour; the remaining actions share black outline icons.
  if(b.kind==='jellyColor'&&b.id!=='original'){
   ctx.fillStyle=b.color!;ctx.beginPath();ctx.arc(cx,cy,29,0,Math.PI*2);ctx.fill();
   if(on)drawMenuIcon(ctx,'check',cx,cy,29,MENU_INK);
  }else{
   drawMenuIcon(ctx,b.icon!,cx,cy,b.kind==='scrollStep'?24:b.kind==='tab'||b.kind==='close'?45:Math.min(82,b.h-34,b.w-38),ink);
   if(b.disabled&&b.kind==='acc')drawMenuIcon(ctx,'lock',cx+43,cy+40,24,MENU_INK);
  }
 }
 function details(m:MenuModel){
  const base=contentX(m.english),cx=base+444;
  if(page==='appearance'&&appearance==='character')text(tr('لون دحروج','Dahrooj’s colour'),cx,540,30);
  if(page==='appearance'&&appearance==='accessories')text(tr(`مكافآت التحديات · مكتمل ${m.done}`,`Challenge rewards · ${m.done} complete`),cx,866,28);
  if(page==='play'){
   text(tr('طريقة الرمي','Throw style'),cx,195,29);text(tr('نوع الطلقة','Projectile'),cx,360,29);
   text(tr('أزرار Meta Quest','Meta Quest controls'),cx,539,30);
   const help=questControls(m.mode,m.throwStyle);
   const hands=[{title:tr('اليد اليسرى','Left hand'),rows:[['Y',tr('الأنماط','Modes')],['X',tr('التحديات','Challenges')],['trigger',tr(...help.leftTrigger)]]},
    {title:tr('اليد اليمنى','Right hand'),rows:[['B',tr('صفحة اللعب','Play settings')],['A',tr(...help.a)],['trigger',tr(...help.rightTrigger)]]}];
   hands.forEach((hand,i)=>{
    const x=base+i*456;ctx.fillStyle=MENU_LIGHT;round(x,561,432,202,24);ctx.fill();text(hand.title,x+216,592,26);
    hand.rows.forEach(([badge,label],j)=>{
     const y=632+j*46,bx=m.english?x+34:x+398;
     if(badge==='trigger')drawMenuIcon(ctx,'trigger',bx,y-9,28);
     else{ctx.strokeStyle=MENU_INK;ctx.lineWidth=2;ctx.beginPath();ctx.arc(bx,y-9,16,0,Math.PI*2);ctx.stroke();ctx.direction='ltr';text(badge,bx,y,25);ctx.direction=m.english?'ltr':'rtl';}
     ctx.textAlign=m.english?'left':'right';text(label,m.english?x+65:x+367,y,25,MENU_INK,334);ctx.textAlign='center';
    });
   });
   text(tr(...help.grip),cx,804,26,MENU_INK,870);
   text(tr('في القائمة: زناد اليمين للاختيار · قير اليمين لتمرير التحديات','In menus: right trigger selects · right stick scrolls challenges'),cx,846,25,MENU_INK,870);
   if(m.kind==='immersive-ar')text(tr('AR: وجّه إلى سطح واضغط الزناد لتثبيته','AR: aim at a surface and press a trigger to pin it'),cx,886,25,MENU_INK,870);
  }
  if(page==='world'){
   if(m.kind==='immersive-vr'){text(tr('وقت اليوم','Time of day'),cx,213,31);text(tr('الطقس','Weather'),cx,428,31);}
   else{text(tr('العالم في غرفتك','Your room is the world'),cx,315,42);text(tr('أعد التثبيت لاختيار سطح جديد','Re-pin to choose a new surface'),cx,400,31);}
  }
  if(page==='challenges'){
   text(tr(`إنجازاتك · ${m.challenges.filter(c=>c.value>=c.goal).length} من ${m.challenges.length}`,`Your progress · ${m.challenges.filter(c=>c.value>=c.goal).length} of ${m.challenges.length}`),cx,212,30);
   ctx.save();ctx.beginPath();ctx.rect(base,LIST_TOP,824,LIST_HEIGHT);ctx.clip();
   m.challenges.forEach((c,i)=>{const y=LIST_TOP+i*ROW_HEIGHT-challengeOffset,done=c.value>=c.goal;if(y+88<LIST_TOP||y>LIST_TOP+LIST_HEIGHT)return;
    ctx.fillStyle=MENU_LIGHT;round(base,y,824,88,12);ctx.fill();
    const iconX=m.english?base+34:base+790;drawMenuIcon(ctx,done?'check':'trophy',iconX,y+37,35);
    ctx.textAlign=m.english?'left':'right';text(tr(c.title,c.en),m.english?base+66:base+758,y+41,28,MENU_INK,610);
    ctx.textAlign=m.english?'right':'left';text(`\u2066${c.value} / ${c.goal}\u2069`,m.english?base+808:base+16,y+41,25,MENU_INK,124);
    ctx.fillStyle='#d8d8d1';round(base+24,y+64,776,8,4);ctx.fill();
    const progress=Math.max(0,Math.min(1,c.value/Math.max(1,c.goal)))*776;ctx.fillStyle=MENU_INK;round(m.english?base+24:base+800-progress,y+64,progress,8,4);ctx.fill();
   });ctx.restore();ctx.textAlign='center';
   ctx.fillStyle='#d8d8d1';round(base+856,TRACK_TOP,14,TRACK_HEIGHT,7);ctx.fill();
   const track=scrollTrack();ctx.fillStyle=MENU_INK;round(base+846,TRACK_TOP+(scrollMax()?challengeOffset/scrollMax()*track.travel:0),34,track.height,12);ctx.fill();
  }
  if(page==='about'){
   text(tr('دحروج','Dahrooj'),cx,209,42);text(tr('امسك دحروج والعب في ١٢ نمطًا مرحًا.','Play with Dahrooj across 12 playful modes.'),cx,265,29);
   text(tr('واقع افتراضي وواقع مختلط.','Virtual and mixed reality.'),cx,304,28,'#666a74');
   MENU_CREDITS.forEach(([name,ar,en],i)=>{const y=397+i*100;ctx.direction='ltr';text(name,cx,y,i===0?34:28);ctx.direction=m.english?'ltr':'rtl';text(tr(ar,en),cx,y+34,24,'#6c6d72');});
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
  hit(u:number,v:number,previous=-1){
   if(!Number.isFinite(u)||!Number.isFinite(v))return -1;const x=u*W,y=(1-v)*H,b=buttons[previous];
   // Six canvas pixels of hysteresis absorb controller tremor at an edge. It is
   // smaller than the gaps, so neighbouring buttons remain independently reachable.
   if(b&&x>=b.x-6&&x<b.x+b.w+6&&y>=b.y-6&&y<b.y+b.h+6)return previous;
   return buttons.findIndex(b=>x>=b.x&&x<b.x+b.w&&y>=b.y&&y<b.y+b.h);
  },
  draw(model:MenuModel,hot=-1){
   // Progress/weather changes on hidden pages must not upload a whole menu texture.
   const visible=page==='modes'?[model.mode]:page==='appearance'?[model.style,model.jellyColor,model.accessory,model.done,model.challenges,model.rewards]:page==='play'?[model.throwStyle,model.shotStyle,model.mode,model.kind]:page==='world'?[model.kind,model.time,model.weather]:page==='challenges'?[model.resetArmed,model.challenges]:[];
   const next=JSON.stringify([page,appearance,challengeOffset,hot,model.english,visible]);lastModel=model;if(key===next)return;key=next;buttons=layout(model);
   drawMenuPaper(ctx,model.english);ctx.textAlign='center';ctx.direction=model.english?'ltr':'rtl';
   const base=contentX(model.english);
   text(tr('دحروج','Dahrooj'),base+444,112,40);
   details(model);buttons.forEach((b,i)=>button(b,i,hot));
   drawMenuFooter(ctx,base+444);
   const target=buttons[hot];
   if(target&&target.kind!=='scroll'){const label=tr(target.ar,target.en)+(target.sub?' · '+target.sub:'');text(label,base+444,958,29,MENU_INK,780);}
   else if(page==='challenges'&&model.resetArmed)text(tr('تأكيد التصفير؟','Confirm reset?'),base+444,958,29,MENU_INK,780);
   texture.needsUpdate=true;
  }
 };
}
