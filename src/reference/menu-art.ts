/** Original Dahrooj menu artwork. All ink is baked into the existing opaque canvas. */
export const MENU_INK='#59402f';
export const SPECTRUM=['#f66b83','#f58b49','#f3ca4f','#78b777','#69bad1','#718ccd','#b184c6'];
type C=CanvasRenderingContext2D;
function path(c:C,points:number[][],fill?:string,stroke=MENU_INK){
 c.beginPath();points.forEach(([x,y],i)=>i?c.lineTo(x,y):c.moveTo(x,y));if(fill)c.closePath();
 if(fill){c.fillStyle=fill;c.fill();}if(stroke){c.strokeStyle=stroke;c.stroke();}
}
function oval(c:C,x:number,y:number,rx:number,ry:number,fill:string,stroke=MENU_INK){c.beginPath();c.ellipse(x,y,rx,ry,0,0,Math.PI*2);c.fillStyle=fill;c.fill();if(stroke){c.strokeStyle=stroke;c.stroke();}}
function box(c:C,x:number,y:number,w:number,h:number,fill:string,r=8,stroke=MENU_INK){c.beginPath();c.roundRect(x,y,w,h,r);c.fillStyle=fill;c.fill();if(stroke){c.strokeStyle=stroke;c.stroke();}}
function star(c:C,x:number,y:number,r:number,fill='#f3ca4f'){
 const p=Array.from({length:10},(_,i)=>{const a=i*Math.PI/5-Math.PI/2,s=i%2?r*.46:r;return [x+Math.cos(a)*s,y+Math.sin(a)*s];});path(c,p,fill);
}
function face(c:C,x:number,y:number,r:number,color='#f58aad',fur=false){
 if(fur){const p=Array.from({length:48},(_,i)=>{const a=i*Math.PI/24,s=r*(i%2?1:1.08);return [x+Math.cos(a)*s,y+Math.sin(a)*s];});path(c,p,color);}
 else oval(c,x,y,r,r,color);
 c.lineWidth=2;oval(c,x-r*.32,y-r*.38,r*.27,r*.12,'#fff3e4','');
 for(const s of [-1,1]){oval(c,x+s*r*.31,y-r*.06,r*.23,r*.29,'#fffefa');oval(c,x+s*r*.31+r*.05,y,r*.085,r*.14,MENU_INK,'');}
 c.beginPath();c.arc(x,y+r*.15,r*.24,.2,Math.PI-.2);c.strokeStyle=MENU_INK;c.stroke();
}
export function drawMenuPaper(c:C,english:boolean){
 c.save();c.fillStyle='#805434';c.fillRect(0,0,1200,1000);c.lineWidth=2;
 // Fixed woodgrain: no time/random input, shimmer, transparency or extra geometry.
 for(let i=0;i<6;i++){const p=4+i*3;c.strokeStyle=i%2?'#b9844f':'#68442e';c.strokeRect(p,p,1200-p*2,1000-p*2);}
 box(c,20,20,1160,960,'#fff9e9',18,'#503929');
 c.strokeStyle='#ecdfc3';c.lineWidth=1;
 for(let y=28;y<975;y+=13)for(let x=28+(y%5)*11;x<1170;x+=71){c.beginPath();c.moveTo(x,y);c.lineTo(x+4+(y%7),y+1);c.stroke();}
 box(c,english?24:936,151,240,804,'#efdfbd',14,'#dcc79e');
 // Folded paper corner and stitched rule tie every category together.
 path(c,[[1137,21],[1178,61],[1137,61]],'#eddbb5','#cbb388');
 c.setLineDash([7,8]);c.strokeStyle='#c5a277';c.beginPath();c.moveTo(41,137);c.lineTo(1158,137);c.stroke();c.setLineDash([]);
 for(const [x,y] of [[12,12],[1188,12],[12,988],[1188,988]]){oval(c,x,y,4,4,'#e3b46f','#513622');}
 c.restore();
}
export function drawMenuCard(c:C,x:number,y:number,w:number,h:number,fill:string,accent:string,selected:boolean,hover:boolean,disabled:boolean){
 c.save();c.lineWidth=3;
 box(c,x,y+3,w,h-3,'#c9ae85',16,'');
 box(c,x,y,w,h-5,fill,16,disabled?'#cbbda7':selected||hover?accent:'#ad8c63');
 c.lineWidth=2;c.strokeStyle=selected?accent:'#eadbbf';c.beginPath();c.roundRect(x+7,y+7,w-14,h-19,11);c.stroke();
 if(hover){c.lineWidth=3;c.strokeStyle=accent;c.beginPath();c.roundRect(x+3,y+3,w-6,h-11,13);c.stroke();}
 c.restore();
}
export function drawMenuIcon(c:C,id:string,x:number,y:number,size=48,color='#df7952'){
 c.save();c.translate(x,y);c.scale(size/100,size/100);c.lineWidth=5;c.lineCap='round';c.lineJoin='round';
 const line=(p:number[][])=>path(c,p),orb=(a:number,b:number,r:number,f:string)=>oval(c,a,b,r,r,f);
 if(['goal','hoop','window','cans','bowling','bricks','fair','climb','rain'].includes(id)){
  // Illustrated mini scenes, each with a distinct setting, object and Dahrooj.
  oval(c,0,35,57,12,'#cad8a1','');c.lineWidth=3;
  if(id==='goal'){
   path(c,[[-49,29],[-49,-33],[26,-33],[44,-17],[44,29]],'#e6f2e4');
   for(let i=0;i<5;i++)path(c,[[-43+i*15,-30],[-43+i*15,28]],undefined,'#9fb9ae');
   for(let i=0;i<3;i++)path(c,[[-46,-17+i*16],[28,-17+i*16]],undefined,'#9fb9ae');
   c.lineWidth=7;path(c,[[-49,29],[-49,-33],[28,-33],[28,29]],undefined,'#fffdf2');c.lineWidth=3;face(c,25,26,19);
  }else if(id==='hoop'){
   box(c,-3,-26,9,66,'#b9966f',3);box(c,-43,-52,86,53,'#fffaf0',9);box(c,-14,-31,28,22,'#f4dabe',2);
   path(c,[[-26,4],[-16,31],[16,31],[26,4]],'#fff7e4','#ab9f86');
   for(const i of [-16,0,16])path(c,[[i,6],[i*.65,28]],undefined,'#ab9f86');oval(c,0,5,30,8,'#ef8854');face(c,36,-7,18,'#f2b667');
  }else if(id==='window'){
   box(c,-45,-44,90,86,'#d8a271',7);box(c,-32,-31,64,60,'#b9dce2',3);
   c.lineWidth=6;line([[0,-30],[0,30]]);line([[-32,0],[32,0]]);box(c,-51,34,102,10,'#e8b981',4);
   path(c,[[-28,-27],[-10,-27],[-28,-9]],'#f2faf5','');face(c,40,30,18,'#a9a4e7');
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
   box(c,-44,-5,88,43,'#f9d69a',4);path(c,[[-51,-5],[0,-46],[51,-5]],'#f18b79');
   for(const a of [-32,-10,12,34])box(c,a-8,-4,16,16,a%3?'#fff1cc':'#ef977c',3);
   for(const a of [-24,1,27])orb(a,23,9,['#79b8cc','#9bbe76','#efae75'][(a+24)/25|0]);
   star(c,0,-31,9);face(c,43,37,16,'#eaa1ce');
  }else if(id==='climb'){
   path(c,[[-54,39],[-12,-41],[16,0],[29,-23],[58,39]],'#83ada1');path(c,[[-12,-41],[-29,-10],[-11,-18],[1,-9]],'#fff7e5');
   line([[-12,-42],[-12,-62]]);path(c,[[-10,-62],[15,-55],[-10,-47]],'#eb8a68');
   path(c,[[-20,36],[-8,23],[-18,13],[-3,-4]],undefined,'#f3dbaa');face(c,27,30,18,'#f4cc73');
  }else{for(let i=0;i<5;i++){const a=[-36,3,38,-23,25][i],b=[-28,-40,-21,17,26][i];path(c,[[a-3,b-32],[a-7,b-23]],undefined,'#83b7c5');face(c,a,b,16,SPECTRUM[i+1]);}}
 }else if(id==='character'||id==='appearance'||id==='mini'||id==='jelly'||id==='fur'||id==='bubble'){
  face(c,0,3,35,id==='fur'?'#e3ceb3':id==='bubble'?'#b9dfea':color,id==='fur');if(id==='bubble'){orb(29,-28,9,'#f8d3e2');}
 }else if(id==='modes'||id==='play'){box(c,-44,-26,88,55,'#c9d9b1',17);line([[-29,0],[-9,0]]);line([[-19,-10],[-19,10]]);orb(20,-7,5,'#ef957c');orb(29,9,5,'#f1c654');}
 else if(id==='party'||id==='accessories'){
  path(c,[[-33,34],[10,-42],[38,34]],'#f8cb66');c.save();c.clip();for(let i=0;i<7;i++)box(c,-44,-43+i*12,91,12,SPECTRUM[i],0,'');c.restore();path(c,[[-33,34],[10,-42],[38,34],[-33,34]]);orb(10,-43,9,'#fff2cb');box(c,-35,28,76,10,'#ed9479',5);
 }else if(id==='challenges'||id==='trophy'){
  path(c,[[-26,-24],[-43,-24],[-41,-6],[-24,5]],undefined,'#b6833a');path(c,[[26,-24],[43,-24],[41,-6],[24,5]],undefined,'#b6833a');
  path(c,[[-26,-32],[26,-32],[22,0],[0,17],[-22,0]],'#efc85d');box(c,-5,15,10,17,'#dfac51',2);box(c,-24,30,48,10,'#ba8b52',4);star(c,0,-12,12,'#fff0b8');
 }else if(id==='world'){orb(0,0,38,'#9acddb');path(c,[[-22,-31],[-4,-21],[-11,-4],[-31,6],[-37,-9]],'#a4bf7b');path(c,[[19,-20],[35,-4],[18,10],[7,31],[-7,20],[0,6]],'#91b976');}
 else if(id==='system'){for(let i=0;i<8;i++){c.save();c.rotate(i*Math.PI/4);box(c,-8,-44,16,22,'#b6c9c9',4);c.restore();}orb(0,0,30,'#b6c9c9');orb(0,0,12,'#fff6df');}
 else if(id==='about'){box(c,-34,-36,68,74,'#f6d49a',10);orb(0,-17,4,MENU_INK);line([[0,-3],[0,20]]);line([[-6,20],[8,20]]);}
 else if(id==='trigger'){box(c,-22,-32,44,65,'#d2dccc',15);orb(0,-17,19,'#faf1db');orb(0,-17,6,'#ed927c');line([[5,14],[14,21]]);}
 else if(id==='hand'){path(c,[[-29,19],[-36,0],[-29,-7],[-15,3],[-16,-30],[-7,-35],[-2,-9],[3,-39],[13,-38],[14,-9],[21,-29],[29,-27],[27,4],[32,-7],[39,-3],[34,23],[14,38],[-8,36]],'#f5c28c');}
 else if(id==='sling'){path(c,[[-8,37],[-7,-5],[-31,-31]],undefined,'#a37346');path(c,[[8,37],[8,-5],[31,-31]],undefined,'#a37346');path(c,[[-30,-31],[0,-13],[30,-31]],undefined,'#df866d');}
 else if(id==='bolt'){path(c,[[6,-42],[-29,5],[-3,5],[-12,43],[32,-12],[7,-12]],'#f3cc5f');}
 else if(id==='firework'){path(c,[[-12,12],[-21,33],[-3,28]],'#f3be62');c.save();c.rotate(.45);box(c,-13,-28,26,55,'#ed8b78',4);path(c,[[-19,-26],[0,-46],[19,-26]],'#87b9c4');box(c,-13,-9,26,10,'#f7d480',0,'');c.restore();star(c,36,-34,10);}
 else if(id==='day'||id==='clear'||id==='auto'){orb(0,0,22,'#f1cb62');for(let i=0;i<8;i++){const a=i*Math.PI/4;line([[Math.cos(a)*31,Math.sin(a)*31],[Math.cos(a)*42,Math.sin(a)*42]]);}if(id==='auto'){box(c,8,17,40,24,'#fff5dc',10);}}
 else if(id==='night'){orb(0,0,33,'#bbc1df');oval(c,16,-14,26,26,'#fff9e9','');star(c,32,18,9);star(c,-31,-29,7);}
 else if(id==='dawn'||id==='dusk'){orb(0,7,27,id==='dawn'?'#f1c767':'#ed947f');box(c,-44,17,88,16,'#d3dcc2',4);line([[-36,38],[36,38]]);}
 else if(id==='weather-rain'||id==='snow'){oval(c,-17,-11,23,20,'#d0e2df');oval(c,11,-16,26,24,'#d0e2df');box(c,-39,-9,79,22,'#d0e2df',10);for(const a of [-25,0,25]){if(id==='snow'){line([[a,22],[a,39]]);line([[a-7,27],[a+7,34]]);line([[a+7,27],[a-7,34]]);}else path(c,[[a+3,23],[a-3,36]],undefined,'#6dacc5');}}
 else if(id==='place'){oval(c,0,26,39,13,'#d7dcb6');path(c,[[-21,-13],[0,22],[21,-13]],'#eb9c7f');orb(0,-17,23,'#eb9c7f');orb(0,-17,8,'#fff6df');}
 else if(id==='lang'){orb(0,0,38,'#e6d5af');c.beginPath();c.ellipse(0,0,16,38,0,0,Math.PI*2);c.strokeStyle=MENU_INK;c.stroke();line([[-36,0],[36,0]]);line([[-30,-20],[30,-20]]);line([[-30,20],[30,20]]);}
 else if(id==='reset'){c.beginPath();c.arc(0,0,30,-Math.PI*.4,Math.PI*1.1);c.strokeStyle=MENU_INK;c.stroke();path(c,[[-40,-2],[-29,-16],[-13,-8]],'#e59c7e');}
 else if(id==='exit'){box(c,-35,-38,46,76,'#d7b48a',5);orb(0,0,3,MENU_INK);path(c,[[4,0],[39,0]],undefined,MENU_INK);path(c,[[23,-16],[40,0],[23,16]]);}
 else if(id==='up'||id==='down'){const s=id==='up'?-1:1;path(c,[[-25,-s*10],[0,s*15],[25,-s*10]]);}
 else if(id==='close'){line([[-22,-22],[22,22]]);line([[22,-22],[-22,22]]);}
 else if(id==='lock'){c.beginPath();c.arc(0,-15,19,Math.PI,Math.PI*2);c.strokeStyle=MENU_INK;c.stroke();box(c,-27,-15,54,48,'#ceb994',8);orb(0,4,5,MENU_INK);line([[0,5],[0,17]]);}
 else if(id==='none'){orb(0,0,34,'#f3e6cf');line([[-22,24],[22,-24]]);}
 else if(id==='check'){orb(0,0,34,'#96bd7b');path(c,[[-18,0],[-4,14],[22,-17]],undefined,'#fffbea');}
 else if(id==='palette'){orb(0,0,36,'#f4deb6');SPECTRUM.slice(0,5).forEach((f,i)=>{const a=i*1.1-2.4;orb(Math.cos(a)*22,Math.sin(a)*22,7,f);});orb(5,14,10,'#fff9e9');}
 else star(c,0,0,32,color);
 c.restore();
}
