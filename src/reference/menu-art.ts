/** Dahrooj's quiet, single-colour icon language. Everything stays on one opaque canvas. */
export const MENU_INK='#292a35';
export const MENU_PAPER='#efeee8';
export const MENU_LIGHT='#faf9f5';
type C=CanvasRenderingContext2D;
function round(c:C,x:number,y:number,w:number,h:number,r:number,fill:string){c.beginPath();c.roundRect(x,y,w,h,r);c.fillStyle=fill;c.fill();}
export function drawMenuPaper(c:C,english:boolean){
 c.save();c.fillStyle=MENU_PAPER;c.fillRect(0,0,1200,1000);
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
 c.save();c.translate(x,y);c.scale(size/100,size/100);c.lineWidth=5;c.lineCap='round';c.lineJoin='round';c.strokeStyle=c.fillStyle=color;
 const line=(p:number[][],close=false)=>{c.beginPath();p.forEach(([a,b],i)=>i?c.lineTo(a,b):c.moveTo(a,b));if(close)c.closePath();c.stroke();};
 const oval=(x:number,y:number,rx:number,ry=rx,filled=false)=>{c.beginPath();c.ellipse(x,y,rx,ry,0,0,Math.PI*2);if(filled)c.fill();else c.stroke();};
 const box=(x:number,y:number,w:number,h:number,r=4)=>{c.beginPath();c.roundRect(x,y,w,h,r);c.stroke();};
 const arc=(x:number,y:number,r:number,a:number,b:number)=>{c.beginPath();c.arc(x,y,r,a,b);c.stroke();};
 const star=(x:number,y:number,r:number)=>line(Array.from({length:10},(_,i)=>{const a=i*Math.PI/5-Math.PI/2,s=i%2?r*.44:r;return [x+Math.cos(a)*s,y+Math.sin(a)*s];}),true);
 const bow=()=>{line([[-4,-32],[-23,-44],[-23,-21],[-4,-32],[4,-32],[23,-44],[23,-21],[4,-32]]);oval(0,-32,4,4,true);};
 if(id==='goal'){
  line([[-38,34],[-38,-30],[38,-30],[38,34]]);for(const x of [-13,13])line([[x,-30],[x,30]]);for(const y of [-10,12])line([[-38,y],[38,y]]);
 }else if(id==='hoop'){
  box(-34,-39,68,37);box(-12,-25,24,22,0);line([[-27,10],[27,10]]);line([[-24,10],[-15,39],[15,39],[24,10]]);line([[-7,10],[-4,39]]);line([[7,10],[4,39]]);
 }else if(id==='window'){
  box(-33,-34,66,66,0);line([[0,-34],[0,32]]);line([[-33,-1],[33,-1]]);line([[-42,41],[42,41]]);
 }else if(id==='bricks'){
  for(const [x,y] of [[-41,17],[-12,17],[17,17],[-32,-7],[-3,-7],[-16,-31]])box(x,y,26,20,2);
 }else if(id==='cans'){
  for(const [x,y] of [[-36,7],[-9,7],[18,7],[-23,-28],[4,-28]])box(x,y,22,30,4);
 }else if(id==='bowling'){
  c.beginPath();c.moveTo(-27,39);c.bezierCurveTo(-41,16,-18,5,-24,-14);c.bezierCurveTo(-33,-46,0,-46,-9,-14);c.bezierCurveTo(-15,5,7,16,-6,39);c.closePath();c.stroke();line([[-24,-12],[-9,-12]]);oval(27,24,17);
 }else if(id==='climb'){
  line([[-44,36],[-14,-18],[4,14],[20,-10],[46,36],[-44,36]]);line([[20,-10],[20,-44],[41,-35],[20,-27]]);
 }else if(id==='fair'){
  line([[-39,-4],[0,-39],[39,-4],[-39,-4]]);line([[-33,-4],[-33,35],[33,35],[33,-4]]);line([[-10,35],[-10,10],[10,10],[10,35]]);line([[0,-39],[0,-49],[17,-44]]);
 }else if(id==='rain'){
  for(const [x,y] of [[-28,-2],[0,-25],[28,-2],[-14,29],[23,30]]){oval(x,y,10);oval(x-3,y,1.5,1.5,true);oval(x+3,y,1.5,1.5,true);}line([[-28,-36],[-28,-23]]);line([[28,-36],[28,-23]]);
 }else if(id==='balance'){
  line([[-43,3],[43,-9],[45,3],[-41,15]],true);line([[-13,39],[0,12],[13,39]],true);oval(-20,-21,12);line([[-49,1],[-49,18]]);line([[51,-14],[51,3]]);
 }else if(id==='ricochet'){
  line([[-39,34],[-39,-31],[37,-31],[37,14]]);line([[27,3],[37,14],[46,3]]);oval(-39,34,7);line([[-50,-17],[-25,-42]]);line([[25,-43],[49,-19]]);oval(37,34,8);
 }else if(id==='rings'){
  oval(-23,0,17,35);oval(8,0,13,28);oval(32,0,9,20);line([[-46,39],[43,39]]);
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
 }else if(id==='laurel'){
  arc(0,-1,31,0,Math.PI);for(const s of [-1,1])for(let i=0;i<4;i++){c.save();c.translate(s*(30-i*4),-16+i*13);c.rotate(s*.7);oval(0,0,5,9);c.restore();}
 }else if(id==='headphones'){
  arc(0,0,33,Math.PI,Math.PI*2);box(-39,-4,14,32,6);box(25,-4,14,32,6);
 }else if(id==='scarf'){
  box(-35,-18,70,21,10);box(5,3,17,36,3);line([[10,30],[10,39]]);line([[17,30],[17,39]]);
 }else if(id==='challenges'||id==='trophy'){
  line([[-24,-34],[24,-34],[21,-2],[0,14],[-21,-2]],true);line([[-24,-23],[-40,-23],[-38,-3],[-19,5]]);line([[24,-23],[40,-23],[38,-3],[19,5]]);line([[0,14],[0,33]]);line([[-20,39],[20,39]]);
 }else if(id==='world'){
  oval(0,0,37);oval(0,0,17,37);line([[-35,-12],[35,-12]]);line([[-35,12],[35,12]]);
 }else if(id==='system'){
  for(let i=0;i<8;i++){const a=i*Math.PI/4;line([[Math.cos(a)*29,Math.sin(a)*29],[Math.cos(a)*42,Math.sin(a)*42]]);}oval(0,0,28);oval(0,0,11);
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
