/* Aboden Games. Ported with owner authorization 2026-10-08 from quest@c7925b7cd7371b6bb87c44a0743721ad55f177dd. See docs/REFERENCE-REUSE-AR.md. */
export function drawReferenceFace(c,Rr,face,lx,ly,blushK,blinkOn,style,noEyes){
const COL={ink:'#2c2d3d'},ballStyle=style,time=0;
function drawEye(c,ex,ey,er,lx,ly,face,blinkOn){
  if(face==='closed'){
    c.strokeStyle=COL.ink; c.lineWidth=er*0.42; c.lineCap='round'; c.lineJoin='round';
    const s=ex<0?1:-1;
    c.beginPath(); c.moveTo(ex-er*0.6*s,ey-er*0.6); c.lineTo(ex+er*0.45*s,ey); c.lineTo(ex-er*0.6*s,ey+er*0.6); c.stroke();
    return;
  }
  if(face==='squint'||face==='laugh'){
    c.strokeStyle=COL.ink; c.lineWidth=er*0.42; c.lineCap='round'; c.lineJoin='round';
    c.beginPath(); c.moveTo(ex-er*0.75,ey+er*0.35); c.quadraticCurveTo(ex,ey-er*0.75,ex+er*0.75,ey+er*0.35); c.stroke();
    return;
  }
  const open = blinkOn ? 0.12 : face==='focus' ? 0.6 : 1;
  c.save(); c.translate(ex,ey); c.scale(1,open);
  c.fillStyle=ballStyle==='fabric'?'#f2ebdd':'#fffaf2';
  c.beginPath(); c.ellipse(0,0,er,er*1.12,0,0,Math.PI*2); c.fill();
  if(ballStyle==='fabric'){ c.save(); c.setLineDash([er*0.28,er*0.22]); c.strokeStyle='rgba(44,45,61,.45)'; c.lineWidth=Math.max(0.6,er*0.12); c.beginPath(); c.ellipse(0,0,er*1.08,er*1.2,0,0,Math.PI*2); c.stroke(); c.restore(); }
  if(face==='dizzy'){
    c.strokeStyle=COL.ink; c.lineWidth=er*0.2; c.lineCap='round';
    c.beginPath();
    const rot=time*9*(ex<0?1:-1);
    for(let t=0;t<Math.PI*4;t+=0.2){const rr=er*0.1+t*er*0.055; const x=Math.cos(t+rot)*rr, y=Math.sin(t+rot)*rr; t===0?c.moveTo(x,y):c.lineTo(x,y);}
    c.stroke();
  } else {
    const pr = face==='wide'? er*0.42 : face==='joy'? er*0.66 : er*0.55;
    c.fillStyle=COL.ink;
    c.beginPath(); c.arc(lx*er*0.42,ly*er*0.48,pr,0,Math.PI*2); c.fill();
    c.fillStyle=ballStyle==='fabric'?'rgba(255,255,255,.35)':'rgba(255,255,255,.9)';
    c.beginPath(); c.arc(lx*er*0.42-pr*0.35,ly*er*0.48-pr*0.4,pr*0.28,0,Math.PI*2); c.fill();
    if(face==='joy'){ c.beginPath(); c.arc(lx*er*0.42+pr*0.35,ly*er*0.48+pr*0.3,pr*0.14,0,Math.PI*2); c.fill(); }
  }
  c.restore();
}
function drawFace(c,Rr,face,lx,ly,blushK,blinkOn,noEyes){
  if(face==='none') return;
  const er=Rr*0.19, ex=Rr*0.31, ey=-Rr*0.08+ly*Rr*0.06, exo=lx*Rr*0.08;
  if(!noEyes){
    drawEye(c,-ex+exo,ey,er,lx,ly,face,blinkOn);
    drawEye(c,ex+exo,ey,er,lx,ly,face,blinkOn);
  }
  if(face==='wide'||face==='dizzy'){
    c.fillStyle=COL.ink;
    c.beginPath(); c.ellipse(exo,Rr*0.32+ly*Rr*0.05,Rr*0.07,Rr*0.09,0,0,Math.PI*2); c.fill();
  }
  if(face==='joy'){
    c.strokeStyle=COL.ink; c.lineWidth=Math.max(1.2,Rr*0.07); c.lineCap='round';
    c.beginPath(); c.arc(exo,Rr*0.1,Rr*0.24,Math.PI*0.18,Math.PI*0.82); c.stroke();
  }
  if(face==='laugh'){
    const my=Rr*0.2, mw=Rr*0.27, mh=Rr*0.24+Math.abs(Math.sin(time*16))*Rr*0.05;
    c.save();
    c.beginPath(); c.moveTo(exo-mw,my); c.lineTo(exo+mw,my); c.ellipse(exo,my,mw,mh,0,0,Math.PI); c.closePath();
    c.fillStyle='#4a1712'; c.fill(); c.clip();
    c.fillStyle='#d8505a'; c.beginPath(); c.ellipse(exo,my+mh*0.95,mw*0.6,mh*0.45,0,0,Math.PI*2); c.fill();
    c.restore();
  }
  if(face==='joy'||face==='laugh') blushK=Math.max(blushK,0.9);
  if(blushK>0){
    c.fillStyle=`rgba(200,60,50,${0.35*blushK})`;
    c.beginPath(); c.ellipse(-Rr*0.55+exo,Rr*0.2,Rr*0.13,Rr*0.07,0,0,Math.PI*2); c.fill();
    c.beginPath(); c.ellipse(Rr*0.55+exo,Rr*0.2,Rr*0.13,Rr*0.07,0,0,Math.PI*2); c.fill();
  }
}
return drawFace(c,Rr,face,lx,ly,blushK,blinkOn,noEyes);
}
