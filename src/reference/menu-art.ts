/** Dahrooj's quiet, single-colour icon language. Everything stays on one opaque canvas. */
export const MENU_INK='#292a35';
export const MENU_PAPER='#efeee8';
export const MENU_LIGHT='#faf9f5';
export const MENU_CORNER=76;
type C=CanvasRenderingContext2D;
function round(c:C,x:number,y:number,w:number,h:number,r:number,fill:string){c.beginPath();c.roundRect(x,y,w,h,r);c.fillStyle=fill;c.fill();}
export function drawMenuPaper(c:C,english:boolean){
 // The geometry supplies the rounded silhouette. Keep even unused corner texels
 // opaque so mip filtering cannot introduce a dark/transparent edge fringe.
 c.save();c.fillStyle=MENU_PAPER;c.fillRect(0,0,1200,1000);
 c.strokeStyle='#d6d5ce';c.lineWidth=3;c.beginPath();c.roundRect(2,2,1196,996,MENU_CORNER-2);c.stroke();
 round(c,english?45:1017,155,138,770,64,MENU_LIGHT);
 c.strokeStyle='#d6d5ce';c.lineWidth=2;c.beginPath();c.moveTo(english?220:92,153);c.lineTo(english?1108:980,153);c.stroke();c.restore();
}
export function drawMenuFooter(c:C,cx:number){c.save();round(c,cx-410,916,820,64,32,MENU_LIGHT);c.restore();}
export function drawMenuCard(c:C,x:number,y:number,w:number,h:number,selected:boolean,hover:boolean,disabled:boolean){
 const r=Math.min(w-12,h-12,132)/2,cx=x+w/2,cy=y+h/2;
 c.save();c.beginPath();c.arc(cx,cy,r,0,Math.PI*2);c.fillStyle=selected?MENU_INK:MENU_LIGHT;c.fill();
 if(hover){c.strokeStyle=MENU_INK;c.lineWidth=3;c.beginPath();c.arc(cx,cy,r+5,0,Math.PI*2);c.stroke();}
 if(disabled){c.fillStyle=MENU_PAPER;c.fill();}c.restore();
}
/** Large, low-detail strokes avoid the tiny net/grain highlights of the illustrated menu. */
export function drawMenuIcon(c:C,id:string,x:number,y:number,size=48,color=MENU_INK){
 c.save();c.translate(x,y);c.scale(size/100,size/100);c.lineWidth=5.25;c.lineCap='round';c.lineJoin='round';c.strokeStyle=c.fillStyle=color;
 const line=(p:number[][],close=false)=>{c.beginPath();p.forEach(([a,b],i)=>i?c.lineTo(a,b):c.moveTo(a,b));if(close)c.closePath();c.stroke();};
 const oval=(x:number,y:number,rx:number,ry=rx,filled=false)=>{c.beginPath();c.ellipse(x,y,rx,ry,0,0,Math.PI*2);if(filled)c.fill();else c.stroke();};
 const box=(x:number,y:number,w:number,h:number,r=4)=>{c.beginPath();c.roundRect(x,y,w,h,r);c.stroke();};
 const arc=(x:number,y:number,r:number,a:number,b:number)=>{c.beginPath();c.arc(x,y,r,a,b);c.stroke();};
 const star=(x:number,y:number,r:number)=>line(Array.from({length:10},(_,i)=>{const a=i*Math.PI/5-Math.PI/2,s=i%2?r*.44:r;return [x+Math.cos(a)*s,y+Math.sin(a)*s];}),true);
 const bow=()=>{line([[-4,-32],[-23,-44],[-23,-21],[-4,-32],[4,-32],[23,-44],[23,-21],[4,-32]]);oval(0,-32,4,4,true);};
 const face=(x:number,y:number,r:number)=>{oval(x,y,r);oval(x-r*.3,y-r*.05,r*.09,r*.14,true);oval(x+r*.3,y-r*.05,r*.09,r*.14,true);};
 if(id==='goal'){
  line([[-43,31],[-43,-33],[27,-33],[27,5]]);line([[-43,-33],[-32,-20],[39,-20],[27,-33]]);line([[-32,-20],[-32,24],[5,24]]);
  for(const x of [-12,9])line([[x,-20],[x,5]]);line([[-32,2],[17,2]]);face(28,27,17);
 }else if(id==='hoop'){
  box(-38,-38,62,37,7);box(-18,-23,24,20,2);oval(-6,6,26,6);
  line([[-29,11],[-20,40],[8,40],[17,11]]);line([[-18,12],[3,38]]);line([[7,12],[-14,38]]);face(32,-15,14);
 }else if(id==='window'){
  box(-31,-38,62,70,6);line([[0,-38],[0,32]]);line([[-31,-4],[31,-4]]);box(-42,34,84,8,3);line([[-21,-26],[-11,-16]]);line([[12,9],[21,18]]);
 }else if(id==='bricks'){
  for(const [x,y] of [[-41,17],[-12,17],[17,17],[-32,-7],[-3,-7],[-16,-31]])box(x,y,26,20,3);line([[25,-26],[34,-36]]);line([[34,-13],[44,-15]]);
 }else if(id==='cans'){
  for(const [x,y] of [[-34,4],[6,4],[-14,-37]]){
   oval(x+14,y+6,14,5);c.beginPath();c.moveTo(x,y+6);c.lineTo(x,y+29);c.bezierCurveTo(x,y+37,x+28,y+37,x+28,y+29);c.lineTo(x+28,y+6);c.stroke();
  }
 }else if(id==='bowling'){
  c.beginPath();c.moveTo(-29,39);c.bezierCurveTo(-42,15,-22,3,-27,-15);c.bezierCurveTo(-34,-44,-4,-44,-11,-15);c.bezierCurveTo(-16,3,4,15,-9,39);c.closePath();c.stroke();line([[-26,-10],[-12,-10]]);line([[-26,-2],[-12,-2]]);
  oval(24,23,20);for(const [x,y] of [[20,14],[29,16],[22,24]])oval(x,y,2,2,true);
 }else if(id==='climb'){
  line([[-44,36],[-14,-22],[17,36],[-44,36]]);line([[2,5],[20,-15],[46,36],[17,36]]);line([[-23,-4],[-14,3],[-5,-4]]);line([[-14,-22],[-14,-45],[8,-37],[-14,-29]]);
 }else if(id==='fair'){
  line([[-42,-3],[0,-36],[42,-3],[-42,-3]]);line([[0,-36],[-16,-3]]);line([[0,-36],[16,-3]]);
  line([[-34,-3],[-37,37],[-13,37],[0,5],[13,37],[37,37],[34,-3]]);line([[0,-36],[0,-49],[18,-44],[0,-39]]);
 }else if(id==='rain'){
  face(-27,9,14);face(8,-16,16);face(28,30,12);line([[-27,-34],[-27,-15]]);line([[8,-45],[8,-39]]);line([[36,-18],[36,4]]);line([[-6,20],[-6,37]]);
 }else if(id==='balance'){
  c.save();c.rotate(-.16);box(-35,-19,70,52,9);line([[-24,10],[0,10],[0,-8],[24,-8]]);box(-47,-7,12,27,5);box(35,-7,12,27,5);face(-20,-28,13);c.restore();
 }else if(id==='ricochet'){
  face(-30,29,12);line([[-30,7],[-30,-25],[30,-25],[30,27]]);line([[19,15],[30,27],[41,15]]);
  line([[-44,-13],[-18,-39]]);line([[18,-39],[44,-13]]);line([[19,39],[41,39]]);
 }else if(id==='maze'){
  box(-41,-41,82,82,9);line([[-41,-15],[-13,-15],[-13,12],[12,12],[12,41]]);
  line([[12,-41],[12,-15],[41,-15]]);line([[-41,15],[-28,15]]);face(-26,-28,7);star(27,26,9);
 }else if(['character','appearance','mini','jelly','fur','bubble'].includes(id)){
  if(id==='fur'){const pts=Array.from({length:40},(_,i)=>{const a=i*Math.PI/20,r=i%2?32:37;return [Math.cos(a)*r,Math.sin(a)*r+3];});line(pts,true);bow();}
  else oval(0,3,35);
  oval(-12,4,4,6,true);oval(12,4,4,6,true);
  if(id==='jelly'){c.save();c.translate(19,-23);c.rotate(-.55);box(-17,-5,34,10,4);line([[-4,-5],[-4,5]]);line([[4,-5],[4,5]]);c.restore();}
  if(id==='bubble'){oval(-15,-19,7,4,true);oval(17,22,3,3,true);}
 }else if(id==='modes'||id==='palette'){
  for(const x of [-29,8])for(const y of [-29,8])box(x,y,22,22,4);
 }else if(id==='play'){
  box(-42,-26,84,57,18);line([[-29,1],[-9,1]]);line([[-19,-9],[-19,11]]);oval(17,-6,4,4,true);oval(28,7,4,4,true);
 }else if(id==='party'||id==='accessories'){
  line([[-31,35],[0,-39],[31,35]],true);line([[-36,39],[36,39]]);line([[-16,0],[15,0]]);line([[-23,17],[23,17]]);oval(0,-45,5);
 }else if(id==='cap'||id==='woodhat'){
  if(id==='cap'){arc(0,4,29,Math.PI,0);line([[-29,4],[39,4],[39,13],[-29,13]],true);}else{box(-23,-35,46,50);line([[-40,18],[40,18]]);line([[-23,2],[23,2]]);}
 }else if(id==='glasses'||id==='starGlasses'){
  if(id==='starGlasses'){star(-23,0,23);star(23,0,23);}else{box(-43,-15,35,30,8);box(8,-15,35,30,8);}line([[-8,-2],[8,-2]]);
 }else if(id==='flower'){
  for(let i=0;i<5;i++){const a=i*Math.PI*2/5;oval(Math.cos(a)*22,Math.sin(a)*22,13);}oval(0,0,8);
 }else if(id==='crown'){
  line([[-36,24],[-38,-22],[-17,-5],[0,-33],[17,-5],[38,-22],[36,24]],true);line([[-36,13],[36,13]]);
 }else if(id==='beanie'){
  arc(0,8,31,Math.PI,Math.PI*2);box(-36,8,72,23,6);oval(0,-35,11);
  for(const x of [-23,-8,8,23])line([[x,14],[x,25]]);
  line([[-17,-3],[-12,-14],[-8,-3]]);line([[8,-3],[12,-14],[17,-3]]);
 }else if(id==='original'){
  oval(0,3,32);oval(-11,4,4,6,true);oval(11,4,4,6,true);arc(0,3,43,Math.PI*.7,Math.PI*1.8);
  line([[16,-45],[30,-32],[14,-26]]);
 }else if(id==='aviator'){
  arc(0,0,33,Math.PI,Math.PI*2);line([[-33,0],[-33,26],[-23,26],[-23,4]]);line([[33,0],[33,26],[23,26],[23,4]]);
  box(-26,-13,23,19,7);box(3,-13,23,19,7);line([[-3,-5],[3,-5]]);line([[-29,11],[29,11]]);
 }else if(id==='headphones'){
  arc(0,0,33,Math.PI,Math.PI*2);box(-39,-4,14,32,6);box(25,-4,14,32,6);
 }else if(id==='scarf'){
  box(-35,-18,70,21,10);box(5,3,17,36,3);line([[10,30],[10,39]]);line([[17,30],[17,39]]);
 }else if(id==='challenges'||id==='trophy'){
  line([[-24,-34],[24,-34],[21,-2],[0,14],[-21,-2]],true);line([[-24,-23],[-40,-23],[-38,-3],[-19,5]]);line([[24,-23],[40,-23],[38,-3],[19,5]]);line([[0,14],[0,33]]);line([[-20,39],[20,39]]);
 }else if(id==='world'){
  oval(0,0,37);oval(0,0,17,37);line([[-35,-12],[35,-12]]);line([[-35,12],[35,12]]);
 }else if(id==='system'){
  line(Array.from({length:32},(_,i)=>{const a=(i+.5)*Math.PI/16,r=i%4<2?41:31;return [Math.cos(a)*r,Math.sin(a)*r];}),true);oval(0,0,13);
 }else if(id==='about'){
  oval(0,0,36);oval(0,-18,3,3,true);line([[0,-3],[0,22]]);
 }else if(id==='trigger'){
  box(-22,-35,44,74,17);oval(0,-15,11);line([[0,10],[12,20]]);
 }else if(id==='hand'){
  line([[-28,18],[-36,-2],[-28,-9],[-15,3],[-15,-30],[-7,-34],[-2,-9],[3,-39],[12,-37],[14,-9],[22,-28],[29,-25],[26,4],[33,-7],[40,-3],[33,24],[13,38],[-9,36]],true);
 }else if(id==='sling'){
  line([[-7,39],[-7,-3],[-32,-34]]);line([[7,39],[7,-3],[32,-34]]);line([[-32,-34],[0,-14],[32,-34]]);
 }else if(id==='bolt'){
  line([[8,-42],[-29,5],[-3,5],[-12,43],[32,-12],[7,-12]],true);
 }else if(id==='firework'){
  c.save();c.rotate(.6);box(-14,-21,28,52);line([[-19,-21],[0,-42],[19,-21]],true);line([[0,31],[0,46]]);c.restore();star(32,-31,9);
 }else if(id==='auto'||id==='reset'){
  arc(0,0,32,-Math.PI*.35,Math.PI*1.17);line([[-42,-9],[-28,-22],[-13,-12]]);if(id==='auto')arc(0,0,17,-Math.PI/2,Math.PI/2);
 }else if(id==='day'||id==='clear'){
  oval(0,0,22);for(let i=0;i<8;i++){const a=i*Math.PI/4;line([[Math.cos(a)*32,Math.sin(a)*32],[Math.cos(a)*42,Math.sin(a)*42]]);}
 }else if(id==='night'){
  c.beginPath();c.arc(0,0,34,Math.PI*1.48,Math.PI*.25,true);c.bezierCurveTo(-14,19,-19,-13,0,-34);c.stroke();star(28,-24,8);
 }else if(id==='dawn'||id==='dusk'){
  arc(0,13,25,Math.PI,Math.PI*2);line([[-41,14],[41,14]]);line([[-30,30],[30,30]]);line([[0,-18],[0,-38]]);line(id==='dawn'?[[-8,-29],[0,-38],[8,-29]]:[[-8,-27],[0,-18],[8,-27]]);
 }else if(id==='weather-rain'||id==='snow'){
  c.beginPath();c.moveTo(-29,5);c.bezierCurveTo(-55,0,-39,-30,-20,-22);c.bezierCurveTo(-12,-50,26,-40,27,-17);c.bezierCurveTo(51,-20,51,7,29,7);c.closePath();c.stroke();
  for(const x of [-26,0,26]){line([[x+3,21],[x-3,36]]);if(id==='snow'){line([[x-7,25],[x+7,33]]);line([[x+7,25],[x-7,33]]);}}
 }else if(id==='place'){
  c.beginPath();c.moveTo(0,33);c.bezierCurveTo(-55,-16,-22,-45,0,-40);c.bezierCurveTo(22,-45,55,-16,0,33);c.stroke();oval(0,-16,10);arc(0,30,38,0,Math.PI);
 }else if(id==='lang'){
  c.textAlign='center';c.font='500 44px "Dahrooj",Tahoma,sans-serif';c.direction='ltr';c.fillText('A',-19,6);c.direction='rtl';c.fillText('ع',22,24);line([[-37,26],[-10,26]]);
 }else if(id==='exit'){
  line([[5,-37],[-31,-37],[-31,37],[5,37]]);line([[-7,0],[39,0]]);line([[22,-17],[39,0],[22,17]]);
 }else if(id==='up'||id==='down'){
  const s=id==='up'?-1:1;line([[-25,-s*10],[0,s*15],[25,-s*10]]);
 }else if(id==='close'){
  line([[-24,-24],[24,24]]);line([[24,-24],[-24,24]]);
 }else if(id==='lock'){
  arc(0,-14,18,Math.PI,Math.PI*2);box(-26,-14,52,46,8);oval(0,4,3,3,true);line([[0,4],[0,17]]);
 }else if(id==='none'){
  oval(0,0,34);line([[-23,24],[23,-24]]);
 }else if(id==='check'){
  line([[-25,0],[-6,20],[29,-23]]);
 }else star(0,0,33);
 c.restore();
}
