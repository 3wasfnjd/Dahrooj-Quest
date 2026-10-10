/** Original Dahrooj menu artwork. All ink is baked into the existing opaque canvas. */
export const MENU_INK='#58361f';
export const SPECTRUM=['#f66b83','#f58b49','#f3ca4f','#78b777','#69bad1','#718ccd','#b184c6'];
type C=CanvasRenderingContext2D;
type Paint=string|CanvasGradient;
function tone(hex:string,amount:number){
 const value=hex.replace('#',''),s=value.length===3?value.split('').map(x=>x+x).join(''):value;
 if(!/^[0-9a-f]{6}$/i.test(s))return hex;
 return '#'+[0,2,4].map(i=>{const v=parseInt(s.slice(i,i+2),16);return Math.round(amount<0?v*(1+amount):v+(255-v)*amount).toString(16).padStart(2,'0');}).join('');
}
function gradient(c:C,x:number,y:number,w:number,h:number,stops:string[]){const g=c.createLinearGradient(x,y,x+w,y+h);stops.forEach((s,i)=>g.addColorStop(i/(stops.length-1),s));return g;}
function rounded(c:C,x:number,y:number,w:number,h:number,r:number,fill:Paint,stroke?:string){c.beginPath();c.roundRect(x,y,w,h,r);c.fillStyle=fill;c.fill();if(stroke){c.strokeStyle=stroke;c.stroke();}}
function path(c:C,points:number[][],fill?:string,stroke=MENU_INK){
 c.beginPath();points.forEach(([x,y],i)=>i?c.lineTo(x,y):c.moveTo(x,y));if(fill)c.closePath();
 if(fill){const ys=points.map(p=>p[1]),lo=Math.min(...ys),hi=Math.max(...ys);c.fillStyle=gradient(c,0,lo,0,Math.max(1,hi-lo),[tone(fill,.28),fill,tone(fill,-.20)]);c.fill();}if(stroke){c.strokeStyle=stroke;c.stroke();}
}
function oval(c:C,x:number,y:number,rx:number,ry:number,fill:string,stroke=MENU_INK){
 c.beginPath();c.ellipse(x,y,rx,ry,0,0,Math.PI*2);
 const g=c.createRadialGradient(x-rx*.36,y-ry*.4,0,x,y,Math.max(rx,ry));g.addColorStop(0,tone(fill,.48));g.addColorStop(.48,fill);g.addColorStop(1,tone(fill,-.27));c.fillStyle=g;c.fill();if(stroke){c.strokeStyle=stroke;c.stroke();}
}
function box(c:C,x:number,y:number,w:number,h:number,fill:string,r=8,stroke=MENU_INK){rounded(c,x,y,w,h,r,gradient(c,x,y,w*.15,h,[tone(fill,.3),fill,tone(fill,-.22)]),stroke);}
function star(c:C,x:number,y:number,r:number,fill='#f3ca4f'){
 const p=Array.from({length:10},(_,i)=>{const a=i*Math.PI/5-Math.PI/2,s=i%2?r*.46:r;return [x+Math.cos(a)*s,y+Math.sin(a)*s];});path(c,p,fill);
}
function face(c:C,x:number,y:number,r:number,color='#f58aad',fur=false){
 c.save();c.lineWidth=1.6;c.shadowColor='rgba(51,30,27,.28)';c.shadowBlur=r*.32;c.shadowOffsetY=r*.18;
 if(fur){const p=Array.from({length:48},(_,i)=>{const a=i*Math.PI/24,s=r*(i%2?1:1.08);return [x+Math.cos(a)*s,y+Math.sin(a)*s];});path(c,p,color);}
 else oval(c,x,y,r,r,color);
 c.shadowColor='transparent';c.lineWidth=1;
 oval(c,x-r*.3,y-r*.52,r*.28,r*.15,tone(color,.8),'');
 for(const s of [-1,1]){
  oval(c,x+s*r*.32,y-r*.03,r*.25,r*.3,'#fffefa',tone(color,-.38));
  oval(c,x+s*r*.32+r*.025,y,r*.155,r*.205,'#382831','');
  oval(c,x+s*r*.32-r*.032,y-r*.09,r*.065,r*.075,'#ffffff','');
  oval(c,x+s*r*.32+r*.075,y+r*.075,r*.032,r*.035,'#ffffff','');
 }
 c.lineWidth=1.6;c.beginPath();c.arc(x,y+r*.20,r*.18,.1,Math.PI-.1);c.strokeStyle='#6d3940';c.stroke();
 c.globalAlpha=.28;oval(c,x-r*.6,y+r*.28,r*.16,r*.09,'#fb8098','');oval(c,x+r*.6,y+r*.28,r*.16,r*.09,'#fb8098','');c.restore();
}
/** Wooden nameplate, inset lettering area and metal fixings are pixels, never XR layers. */
function plaque(c:C,cx:number,y:number,w:number,h:number,ornate=false){
 const x=cx-w/2;c.save();c.lineWidth=3;c.shadowColor='rgba(64,31,13,.45)';c.shadowBlur=9;c.shadowOffsetY=6;
 const outline=[[x+22,y],[x+w-22,y],[x+w,y+h/2],[x+w-22,y+h],[x+22,y+h],[x,y+h/2]];
 path(c,outline,'#d99a3c','#63371d');c.shadowColor='transparent';
 path(c,[[x+25,y+7],[x+w-25,y+7],[x+w-9,y+h/2],[x+w-25,y+h-7],[x+25,y+h-7],[x+9,y+h/2]],'#ffe7a4','#b77c2e');
 path(c,[[x+33,y+16],[x+w-33,y+16],[x+w-21,y+h/2],[x+w-33,y+h-16],[x+33,y+h-16],[x+21,y+h/2]],'#96532c','#60331b');
 c.lineWidth=2;c.strokeStyle='#b57b45';for(let i=0;i<2;i++){c.beginPath();c.moveTo(x+42,y+23+i*17);c.bezierCurveTo(cx-80,y+17+i*17,cx+80,y+35+i*17,x+w-42,y+24+i*17);c.stroke();}
 if(ornate){
  for(const s of [-1,1]){c.save();c.translate(cx+s*(w/2-4),y+14);c.scale(s,1);c.lineWidth=11;c.strokeStyle='#7f461e';c.beginPath();c.moveTo(-12,29);c.bezierCurveTo(42,26,53,-21,20,-29);c.bezierCurveTo(-6,-35,-13,-10,5,-8);c.stroke();c.lineWidth=6;c.strokeStyle='#ffdb75';c.stroke();c.restore();}
  c.lineWidth=3;path(c,[[cx,y-52],[cx+33,y-18],[cx,y+14],[cx-33,y-18]],'#f5d371','#83582c');path(c,[[cx,y-41],[cx+22,y-18],[cx,y+3],[cx-22,y-18]],'#2ed7f4','#267aa0');path(c,[[cx,y-37],[cx-17,y-18],[cx,y-1]],'#a5f7ff','');
 }c.restore();
}
export function drawMenuFooter(c:C,cx:number){plaque(c,cx,916,610,66);}
export function drawMenuPaper(c:C,english:boolean){
 c.save();c.fillStyle=gradient(c,0,0,0,1000,['#b88042','#704023','#9a5b2d','#63331d']);c.fillRect(0,0,1200,1000);
 // Broad, deterministic grain stays readable in a small headset menu.
 for(let i=0;i<34;i++){const y=i*31;c.lineWidth=i%3?4:7;c.strokeStyle=i%2?'#7b4327':'#c38a48';c.beginPath();c.moveTo(0,y);c.bezierCurveTo(360,y+26,790,y-23,1200,y+3);c.stroke();}
 for(const side of [0,1]){c.save();c.translate(side?1200:0,0);if(side)c.scale(-1,1);for(let i=0;i<4;i++){c.strokeStyle=i%2?'#c18a4f':'#61351f';c.lineWidth=4;c.beginPath();c.moveTo(8+i*10,0);c.bezierCurveTo(37+i*7,370,-6+i*14,600,14+i*9,1000);c.stroke();}c.restore();}
 c.lineWidth=5;rounded(c,40,43,1120,914,22,'#512c1c','#e0ad6b');
 const paper=c.createRadialGradient(547,394,70,590,460,700);paper.addColorStop(0,'#ffedc1');paper.addColorStop(.68,'#f4d497');paper.addColorStop(1,'#d39c5c');
 c.shadowColor='#452718';c.shadowBlur=15;rounded(c,55,60,1090,880,15,paper);c.shadowColor='transparent';
 let seed=417;for(let i=0;i<230;i++){seed=(seed*1664525+1013904223)>>>0;const x=72+seed%1060;seed=(seed*1664525+1013904223)>>>0;const y=80+seed%838;c.fillStyle=i%2?'rgba(164,99,46,.06)':'rgba(255,249,214,.25)';c.beginPath();c.ellipse(x,y,2+i%4,1+i%3,0,0,Math.PI*2);c.fill();}
 c.lineWidth=3;rounded(c,english?49:1021,165,130,760,18,gradient(c,0,165,0,760,['#c6945a','#80502d','#ba7b41']),'#734424');
 plaque(c,english?664:536,65,612,93,true);
 // Four silver corner brackets and recessed screw heads.
 for(const [x,y,sx,sy] of [[0,0,1,1],[1200,0,-1,1],[0,1000,1,-1],[1200,1000,-1,-1]]){
  c.save();c.translate(x,y);c.scale(sx,sy);c.lineWidth=4;
  path(c,[[0,0],[88,0],[78,27],[35,34],[28,76],[0,91]],'#9695a3','#463e48');
  c.lineWidth=2;path(c,[[5,5],[78,5],[71,20],[27,27],[21,70],[5,77]],'#c8c4c4','#eae2d1');
  for(const [a,b] of [[18,17],[62,13],[13,63]]){c.lineWidth=2;oval(c,a,b,9,9,'#8c8998','#4e4753');c.beginPath();c.moveTo(a-5,b+5);c.lineTo(a+5,b-5);c.strokeStyle='#34333e';c.lineWidth=3;c.stroke();}
  c.restore();
 }
 c.restore();
}
export function drawMenuCard(c:C,x:number,y:number,w:number,h:number,fill:string,accent:string,selected:boolean,hover:boolean,disabled:boolean){
 c.save();c.lineWidth=3;const rim=disabled?'#aaa28f':accent,body=disabled?'#d4c4a8':fill,r=Math.min(22,h*.2),v=Math.min(1,w/112,h/100);
 c.shadowColor='rgba(81,41,25,.40)';c.shadowBlur=9;c.shadowOffsetY=5;
 rounded(c,x,y+3,w,h-3,r,gradient(c,x,y,w*.15,h,[tone(rim,.37),rim,tone(rim,-.4)]),tone(rim,-.53));c.shadowColor='transparent';
 c.lineWidth=2;rounded(c,x+5*v,y+5*v,w-10*v,h-13*v,r-3*v,gradient(c,x,y,0,h,[tone(rim,.58),rim,tone(rim,-.18)]),tone(rim,.58));
 rounded(c,x+13*v,y+14*v,w-26*v,h-30*v,r-8*v,gradient(c,x,y,0,h,[tone(rim,-.4),tone(rim,-.1)]),tone(rim,-.28));
 rounded(c,x+17*v,y+19*v,w-34*v,h-40*v,r-10*v,gradient(c,x,y,0,h,[tone(body,.24),body,tone(body,-.13)]));
 c.lineWidth=2;c.strokeStyle=tone(body,.65);c.beginPath();c.moveTo(x+27*v,y+h-24*v);c.quadraticCurveTo(x+w/2,y+h-17*v,x+w-27*v,y+h-24*v);c.stroke();
 if(hover){c.lineWidth=4;c.strokeStyle='#fff4b3';c.beginPath();c.roundRect(x+3,y+3,w-6,h-7,r-2);c.stroke();}
 if(selected){c.lineWidth=2;c.strokeStyle='#faffc5';c.beginPath();c.roundRect(x+7,y+7,w-14,h-17,r-4);c.stroke();}
 c.restore();
}
export function drawMenuIcon(c:C,id:string,x:number,y:number,size=48,color='#df7952'){
 c.save();c.translate(x,y);c.scale(size/100,size/100);c.lineWidth=5;c.lineCap='round';c.lineJoin='round';
 const line=(p:number[][])=>path(c,p),orb=(a:number,b:number,r:number,f:string)=>oval(c,a,b,r,r,f);
 if(['goal','hoop','window','cans','bowling','bricks','fair','climb','rain','balance','ricochet','rings'].includes(id)){
  // Illustrated mini scenes, each with a distinct setting, object and Dahrooj.
  c.save();c.globalAlpha=.3;oval(c,4,39,52,11,'#58422d','');c.restore();oval(c,0,34,53,10,'#a9c566','');c.lineWidth=2.5;
  if(id==='goal'){
   path(c,[[-44,27],[-44,-36],[26,-36],[43,-14],[43,27]],'#c4bcbc','#746768');
   c.lineWidth=1.5;for(let i=0;i<6;i++)path(c,[[-40+i*12,-32],[-36+i*12,25]],undefined,'#ecedf0');
   for(let i=0;i<5;i++)path(c,[[-41,-24+i*11],[29,-24+i*11]],undefined,'#ecedf0');
   c.lineWidth=8;path(c,[[-45,29],[-45,-36],[28,-36],[28,29]],undefined,'#7d828b');
   c.lineWidth=4;path(c,[[-46,27],[-46,-37],[27,-37],[27,28]],undefined,'#f8fafb');c.lineWidth=2.5;face(c,28,25,21,'#e75aac');
  }else if(id==='hoop'){
   box(c,-3,-26,9,66,'#b9966f',3);box(c,-43,-52,86,53,'#fffaf0',9);box(c,-14,-31,28,22,'#f4dabe',2);
   path(c,[[-26,4],[-16,31],[16,31],[26,4]],'#fff7e4','#ab9f86');
   for(const i of [-16,0,16])path(c,[[i,6],[i*.65,28]],undefined,'#ab9f86');oval(c,0,5,30,8,'#ef8854');face(c,36,-7,18,'#f2b667');
  }else if(id==='window'){
   box(c,-42,-43,81,80,'#a05e39',5);box(c,-32,-33,61,61,'#345b8d',2);
   path(c,[[-30,-31],[-3,-31],[-30,-3]],'#93c5e9','');path(c,[[2,3],[26,3],[2,26]],'#4778a6','');
   c.lineWidth=8;path(c,[[-2,-35],[-2,30]],undefined,'#71462d');path(c,[[-34,-3],[31,-3]],undefined,'#71462d');
   c.lineWidth=3;path(c,[[-3,-35],[-3,30]],undefined,'#cd9764');path(c,[[-34,-5],[31,-5]],undefined,'#cd9764');box(c,-49,31,94,9,'#c78a50',3);face(c,36,27,22,'#aa62cd');
  }else if(id==='cans'){
   box(c,-57,34,114,8,'#c99763',3);
   [[-36,1,'#69bad1'],[1,1,'#f1bd4a'],[-17,-35,'#ee857b']].forEach(([a,b,f])=>{box(c,a as number,b as number,33,35,f as string,5);oval(c,(a as number)+16.5,b as number,16.5,5,'#fff5e0');c.lineWidth=2;star(c,(a as number)+16,(b as number)+18,8);c.lineWidth=3;});
   face(c,42,23,18,'#8cbd89');
  }else if(id==='bowling'){
   for(const [a,b] of [[-30,-6],[4,-15],[29,0]]){path(c,[[a-8,b-11],[a-10,b+3],[a-15,b+20],[a-10,b+29],[a+10,b+29],[a+15,b+20],[a+10,b+3],[a+8,b-11]],'#fffcf0');orb(a,b-18,10,'#fffcf0');box(c,a-9,b-5,18,5,'#e98575',1,'');}
   face(c,-9,33,23,'#afa1db');
  }else if(id==='bricks'){
   for(let row=0;row<3;row++)for(let col=0;col<(row===0?2:3);col++){const a=-48+col*33+(row===0?16:row===1?0:6),b=-34+row*26;box(c,a,b,30,23,['#da9279','#e8af81','#db9b72'][row],4);path(c,[[a+5,b+5],[a+21,b+5]],undefined,'#f9d3a1');}
   face(c,39,31,19,'#70bdba');
  }else if(id==='fair'){
   c.lineWidth=3;c.beginPath();c.arc(30,0,25,0,Math.PI*2);c.strokeStyle='#9b6a36';c.stroke();
   for(let i=0;i<8;i++){const a=i*Math.PI/4,x=30+Math.cos(a)*25,y=Math.sin(a)*25;path(c,[[30,0],[x,y]],undefined,'#c89d64');orb(x,y,4,i%2?'#eebf55':'#7dbac2');}
   path(c,[[19,37],[30,0],[44,37]],undefined,'#795138');
   box(c,-49,-3,59,39,'#e1ba6d',3);for(const x of [-41,-25,-9])box(c,x,-3,8,40,'#a65694',2,'');
   path(c,[[-57,-3],[-20,-39],[18,-3]],'#e9c570');path(c,[[-38,-3],[-20,-39],[-17,-3]],'#b95c97');path(c,[[-8,-3],[-20,-39],[11,-3]],'#b95c97');
   path(c,[[-20,-39],[-20,-57]],undefined,'#765538');path(c,[[-18,-56],[-1,-51],[-18,-44]],'#ec8996');
   box(c,-28,12,17,26,'#593b51',8);face(c,18,31,20,'#df80be');
  }else if(id==='climb'){
   path(c,[[-54,39],[-12,-36],[16,0],[29,-20],[58,39]],'#858d83');path(c,[[-12,-36],[-11,39],[18,39]],'#666c68');path(c,[[-12,-36],[-29,-6],[-11,-15],[1,-5]],'#fff7e5');
   path(c,[[29,-20],[18,0],[30,-4],[38,5]],'#e8e8d5');line([[-12,-36],[-12,-54]]);path(c,[[-10,-54],[15,-47],[-10,-39]],'#d57758');
   path(c,[[-28,36],[-15,23],[-22,13],[-11,1]],undefined,'#c8c7a7');face(c,28,28,21,'#f0c24b');
  }else if(id==='balance'){
   path(c,[[-12,39],[3,10],[21,39]],'#c69667');c.save();c.rotate(-.15);box(c,-54,0,108,14,'#c59161',5);box(c,-49,-9,98,14,'#f9e8bd',5);oval(c,16,-2,10,4,'#7b624e');face(c,-18,-25,20,'#9ec4a1');star(c,40,-29,12);c.restore();
   line([[-62,6],[-62,-7]]);line([[62,-9],[62,-22]]);
  }else if(id==='ricochet'){
   box(c,-54,-43,108,82,'#cca070',8);c.lineWidth=9;path(c,[[-43,-25],[-22,-42]],undefined,'#855132');path(c,[[25,-40],[46,-23]],undefined,'#855132');c.lineWidth=3;
   path(c,[[-43,-28],[-24,-44]],undefined,'#f4d19a');path(c,[[27,-42],[48,-25]],undefined,'#f4d19a');
   c.setLineDash([4,6]);path(c,[[-35,25],[-35,-23],[34,-23],[34,18]],undefined,'#bd865d');c.setLineDash([]);star(c,34,24,13);face(c,-35,27,17,'#eca5be');box(c,-12,-9,24,35,'#bd916a',4);
  }else if(id==='rings'){
   box(c,-55,27,113,14,'#bd8a54',5);c.lineWidth=7;
   for(const [x,y,r,f] of [[29,-20,22,'#de9870'],[0,-8,27,'#e3bf63'],[-29,3,32,'#7fb8a5']] as [number,number,number,string][]){c.strokeStyle=f;c.beginPath();c.ellipse(x,y,r*.66,r,0,Math.PI,Math.PI*2);c.stroke();box(c,x-r*.66-6,y,12,8,'#a67d51',2);box(c,x+r*.66-6,y,12,8,'#a67d51',2);}
   c.lineWidth=3;face(c,-29,18,19,'#8ecbdd');star(c,46,-42,9);
  }else{for(let i=0;i<5;i++){const a=[-36,3,38,-23,25][i],b=[-22,-36,-18,22,28][i];path(c,[[a-8,b-27],[a-13,b-13],[a-5,b-14]],'#68ccdf','#488b9c');face(c,a,b,17,SPECTRUM[i+1]);}}
 }else if(id==='laurel'){
  c.lineWidth=4;c.strokeStyle='#8a9b54';c.beginPath();c.ellipse(0,-17,30,22,0,Math.PI*.1,Math.PI*.9);c.stroke();
  for(const side of [-1,1])for(let i=0;i<5;i++){c.save();c.translate(side*(13+i*4),-33+i*6);c.rotate(side*(.5+i*.15));oval(c,0,0,5,9,i%2?'#c5be63':'#8bb371');c.restore();}
 }else if(id==='woodhat'){
  oval(c,0,-10,39,10,'#b98551');path(c,[[-24,-11],[-20,-43],[19,-43],[25,-11]],'#cc9d65');box(c,-24,-20,49,8,'#785037',3);oval(c,0,-43,20,6,'#dfba87');
  for(const x of [-12,0,12])path(c,[[x,-39],[x+2,-24]],undefined,'#b58350');
 }else if(id==='starGlasses'){
  star(c,-21,4,24,'#efc557');star(c,21,4,24,'#efc557');star(c,-21,4,15,'#7a65ad');star(c,21,4,15,'#7a65ad');path(c,[[-6,1],[6,1]],undefined,'#d89d42');
 }else if(id==='character'||id==='appearance'||id==='mini'||id==='jelly'||id==='fur'||id==='bubble'){
  face(c,0,3,35,id==='fur'?'#e3ceb3':id==='bubble'?'#b9dfea':color,id==='fur');if(id==='bubble'){orb(29,-28,9,'#f8d3e2');}
 }else if(id==='modes'||id==='play'){box(c,-44,-26,88,58,'#bbc5d8',18);c.lineWidth=7;path(c,[[-29,-1],[-9,-1]],undefined,'#536273');path(c,[[-19,-11],[-19,9]],undefined,'#536273');c.lineWidth=2;orb(20,-10,5,'#e35c61');orb(30,0,5,'#eec547');orb(10,0,5,'#6bbec0');orb(20,10,5,'#80b974');}
 else if(id==='party'||id==='accessories'){
  path(c,[[-33,34],[10,-42],[38,34]],'#f8cb66');c.save();c.clip();for(let i=0;i<7;i++)box(c,-44,-43+i*12,91,12,SPECTRUM[i],0,'');c.restore();path(c,[[-33,34],[10,-42],[38,34],[-33,34]]);orb(10,-43,9,'#fff2cb');box(c,-35,28,76,10,'#ed9479',5);
 }else if(id==='challenges'||id==='trophy'){
  path(c,[[-26,-24],[-43,-24],[-41,-6],[-24,5]],undefined,'#b6833a');path(c,[[26,-24],[43,-24],[41,-6],[24,5]],undefined,'#b6833a');
  path(c,[[-26,-32],[26,-32],[22,0],[0,17],[-22,0]],'#efc85d');box(c,-5,15,10,17,'#dfac51',2);box(c,-24,30,48,10,'#ba8b52',4);star(c,0,-12,12,'#fff0b8');
 }else if(id==='world'){
  orb(0,0,38,'#42a9d7');c.lineWidth=1.5;
  path(c,[[-29,-23],[-18,-31],[-5,-25],[-8,-18],[-4,-10],[-12,-3],[-21,-12],[-30,-10]],'#91c94f','#5e953c');
  path(c,[[-14,-1],[-4,3],[-8,16],[-14,30],[-19,19],[-21,5]],'#87bf46','#5e953c');
  path(c,[[6,-29],[20,-27],[32,-18],[35,-5],[23,-1],[18,9],[8,5],[3,-4],[-2,-10],[5,-17]],'#a3d35d','#5e953c');
  path(c,[[5,7],[17,8],[19,19],[12,29],[5,18]],'#8bc34b','#5e953c');
  c.globalAlpha=.3;oval(c,-17,-23,12,6,'#ffffff','');
 }
 else if(id==='system'){for(let i=0;i<8;i++){c.save();c.rotate(i*Math.PI/4);box(c,-8,-44,16,22,'#b6c9c9',4);c.restore();}orb(0,0,30,'#b6c9c9');orb(0,0,12,'#fff6df');}
 else if(id==='about'){orb(0,0,37,'#67c5ef');c.lineWidth=7;path(c,[[0,-3],[0,22]],undefined,'#edfbff');orb(0,-20,5,'#f6fdff');}
 else if(id==='trigger'){box(c,-22,-32,44,65,'#d2dccc',15);orb(0,-17,19,'#faf1db');orb(0,-17,6,'#ed927c');line([[5,14],[14,21]]);}
 else if(id==='hand'){path(c,[[-29,19],[-36,0],[-29,-7],[-15,3],[-16,-30],[-7,-35],[-2,-9],[3,-39],[13,-38],[14,-9],[21,-29],[29,-27],[27,4],[32,-7],[39,-3],[34,23],[14,38],[-8,36]],'#f5c28c');}
 else if(id==='sling'){path(c,[[-8,37],[-7,-5],[-31,-31]],undefined,'#a37346');path(c,[[8,37],[8,-5],[31,-31]],undefined,'#a37346');path(c,[[-30,-31],[0,-13],[30,-31]],undefined,'#df866d');}
 else if(id==='bolt'){path(c,[[6,-42],[-29,5],[-3,5],[-12,43],[32,-12],[7,-12]],'#f3cc5f');}
 else if(id==='firework'){path(c,[[-12,12],[-21,33],[-3,28]],'#f3be62');c.save();c.rotate(.45);box(c,-13,-28,26,55,'#ed8b78',4);path(c,[[-19,-26],[0,-46],[19,-26]],'#87b9c4');box(c,-13,-9,26,10,'#f7d480',0,'');c.restore();star(c,36,-34,10);}
 else if(id==='auto'){
  orb(0,0,24,'#9cafcc');c.save();c.beginPath();c.rect(-30,-30,30,60);c.clip();orb(0,0,24,'#f1cf68');c.restore();
  c.lineWidth=5;c.strokeStyle='#816542';for(const a of [0,Math.PI]){c.beginPath();c.arc(0,0,38,a+.18,a+2.6);c.stroke();const x=Math.cos(a+.18)*38,y=Math.sin(a+.18)*38;path(c,[[x-10,y-5],[x+4,y],[x-7,y+10]],'#cfad66');}
 }
 else if(id==='day'||id==='clear'){orb(0,0,22,'#f1cb62');for(let i=0;i<8;i++){const a=i*Math.PI/4;line([[Math.cos(a)*31,Math.sin(a)*31],[Math.cos(a)*42,Math.sin(a)*42]]);}}
 else if(id==='night'){orb(0,0,33,'#bbc1df');oval(c,16,-14,26,26,'#fff9e9','');star(c,32,18,9);star(c,-31,-29,7);}
 else if(id==='dawn'||id==='dusk'){orb(0,7,27,id==='dawn'?'#f1c767':'#ed947f');box(c,-44,17,88,16,'#d3dcc2',4);line([[-36,38],[36,38]]);}
 else if(id==='weather-rain'||id==='snow'){oval(c,-17,-11,23,20,'#d0e2df');oval(c,11,-16,26,24,'#d0e2df');box(c,-39,-9,79,22,'#d0e2df',10);for(const a of [-25,0,25]){if(id==='snow'){line([[a,22],[a,39]]);line([[a-7,27],[a+7,34]]);line([[a+7,27],[a-7,34]]);}else path(c,[[a+3,23],[a-3,36]],undefined,'#6dacc5');}}
 else if(id==='place'){oval(c,0,26,39,13,'#d7dcb6');path(c,[[-21,-13],[0,22],[21,-13]],'#eb9c7f');orb(0,-17,23,'#eb9c7f');orb(0,-17,8,'#fff6df');}
 else if(id==='lang'){
  box(c,-43,-37,54,54,'#eac377',9);box(c,-9,-8,53,53,'#83bdd2',9);
  c.fillStyle='#5b3f29';c.textAlign='center';c.direction='ltr';c.font='500 37px "Dahrooj",Tahoma,sans-serif';c.fillText('A',-16,3);c.direction='rtl';c.fillText('ع',17,28);
 }
 else if(id==='reset'){c.beginPath();c.arc(0,0,30,-Math.PI*.4,Math.PI*1.1);c.strokeStyle=MENU_INK;c.stroke();path(c,[[-40,-2],[-29,-16],[-13,-8]],'#e59c7e');}
 else if(id==='exit'){box(c,-35,-38,46,76,'#d7b48a',5);orb(0,0,3,MENU_INK);path(c,[[4,0],[39,0]],undefined,MENU_INK);path(c,[[23,-16],[40,0],[23,16]]);}
 else if(id==='up'||id==='down'){const s=id==='up'?-1:1;path(c,[[-25,-s*10],[0,s*15],[25,-s*10]]);}
 else if(id==='close'){c.lineWidth=17;path(c,[[-24,-24],[24,24]],undefined,'#8d2c22');path(c,[[24,-24],[-24,24]],undefined,'#8d2c22');c.lineWidth=10;path(c,[[-24,-26],[24,22]],undefined,'#ffb09a');path(c,[[24,-26],[-24,22]],undefined,'#ffb09a');}
 else if(id==='lock'){c.beginPath();c.arc(0,-15,19,Math.PI,Math.PI*2);c.strokeStyle=MENU_INK;c.stroke();box(c,-27,-15,54,48,'#ceb994',8);orb(0,4,5,MENU_INK);line([[0,5],[0,17]]);}
 else if(id==='none'){orb(0,0,34,'#f3e6cf');line([[-22,24],[22,-24]]);}
 else if(id==='check'){c.lineWidth=4;orb(0,0,38,'#70d548');c.lineWidth=2;c.strokeStyle='#ddffb4';c.beginPath();c.arc(0,0,32,0,Math.PI*2);c.stroke();c.lineWidth=8;path(c,[[-18,0],[-4,14],[22,-17]],undefined,'#fffbea');}
 else if(id==='palette'){orb(0,0,36,'#f4deb6');SPECTRUM.slice(0,5).forEach((f,i)=>{const a=i*1.1-2.4;orb(Math.cos(a)*22,Math.sin(a)*22,7,f);});orb(5,14,10,'#fff9e9');}
 else star(c,0,0,32,color);
 c.restore();
}
