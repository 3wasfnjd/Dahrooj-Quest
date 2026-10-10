import {createTabletopGame,TABLE_RADIUS,MAZE_LEVELS,MAZE_WALL_HEIGHT} from '../tabletop-games';

/** Original wooden tabletop games. All lettering is on the solid board itself. */
export default function tabletop(ctx,mode){
 const {T,V,scene}=ctx,grp=new T.Group(),board=new T.Group(),pieces=new T.Group();
 grp.name='mode-'+mode;grp.add(board);board.add(pieces);scene.add(grp);
 // Shared procedural grain: opaque painted wood, no downloaded textures or blended layers.
 const grainCanvas=document.createElement('canvas');grainCanvas.width=256;grainCanvas.height=512;
 const grainCtx=grainCanvas.getContext('2d');grainCtx.fillStyle='#f7e6ca';grainCtx.fillRect(0,0,256,512);
 for(let k=0;k<28;k++){grainCtx.strokeStyle=k%3?'#e1c6a3':'#c6a27b';grainCtx.lineWidth=k%3?1.5:2.8;grainCtx.beginPath();
  for(let y=0;y<=512;y+=16){const x=k*10+Math.sin(y*.018+k)*3+Math.sin(y*.041+k*.7);if(y)grainCtx.lineTo(x,y);else grainCtx.moveTo(x,y);}grainCtx.stroke();}
 const grain=new T.CanvasTexture(grainCanvas);grain.colorSpace=T.SRGBColorSpace;grain.anisotropy=4;
 const timber=color=>{const m=new T.MeshStandardMaterial({color,map:grain,roughness:.62,blending:T.NoBlending});m.name='tabletop-wood';return m;};
 const wood=timber(0xb98656),cream=timber(0xf5dbab),walnut=timber(0x835134),honey=timber(0xdca557);
 const gold=new T.MeshStandardMaterial({color:0xf6ca56,roughness:.4}),mint=new T.MeshStandardMaterial({color:0x77b7a4,roughness:.7});
 const violet=new T.MeshStandardMaterial({color:0xb29bd8,roughness:.7}),dark=new T.MeshStandardMaterial({color:0x694b40,roughness:.85});
 const materials=[wood,cream,walnut,honey,gold,mint,violet,dark],geometries=[];
 const wooden=mode==='ricochet',tilting=mode==='balance'||mode==='maze';
 function box(parent,w,h,d,x,y,z,mat){const geo=new T.BoxGeometry(w,h,d);geometries.push(geo);const m=new T.Mesh(geo,mat);m.position.set(x,y,z);parent.add(m);return m;}
 box(board,3.35,.16,3.77,0,-.35,0,walnut);
 box(board,3.30,.045,3.72,0,-.245,0,honey);
 for(const x of [-1.59,1.59]){box(board,.15,.27,3.78,x,-.13,0,wood);box(board,.19,.035,3.82,x,.022,0,cream);}
 for(const z of [-1.83,1.83]){box(board,3.32,.27,.15,0,-.13,z,wood);box(board,3.48,.035,.19,0,.022,z,cream);}
 const handles=[-1,1].map(s=>{const h=new T.Mesh(new T.TorusGeometry(.22,.055,8,24,Math.PI),cream);geometries.push(h.geometry);h.rotation.x=-Math.PI/2;h.rotation.z=s<0?Math.PI/2:-Math.PI/2;h.position.set(s*1.64,-.14,.9);h.name='balance-handle-'+s;board.add(h);return h;});
 // A single cutout surface for the bridges, with a recessed tray below it.
 const canvas=document.createElement('canvas');canvas.width=1024;canvas.height=1152;const c=canvas.getContext('2d');
 const map=new T.CanvasTexture(canvas);map.colorSpace=T.SRGBColorSpace;map.anisotropy=4;
 const surfaceMat=new T.MeshStandardMaterial({map,alphaTest:mode==='balance'?.5:0,transparent:false,blending:T.NoBlending,roughness:.9,side:T.DoubleSide});materials.push(surfaceMat);
 const surface=new T.Mesh(new T.PlaneGeometry(3,3.4),surfaceMat);geometries.push(surface.geometry);surface.name='tabletop-floor';surface.rotation.x=-Math.PI/2;board.add(surface);
 const signCanvas=document.createElement('canvas');signCanvas.width=1536;signCanvas.height=352;
 const signMap=new T.CanvasTexture(signCanvas);signMap.colorSpace=T.SRGBColorSpace;signMap.anisotropy=4;
 const signMat=new T.MeshBasicMaterial({map:signMap,toneMapped:false,blending:T.NoBlending});materials.push(signMat);
 const sign=box(board,3.28,.75,.12,0,.4,-1.9,[wood,wood,wood,wood,signMat,wood]);sign.name='tabletop-instructions';
 const goal=new T.Mesh(mode==='maze'?new T.CylinderGeometry(.21,.21,.026,36):new T.TorusGeometry(.24,.038,10,36),wooden?honey:mint);geometries.push(goal.geometry);goal.rotation.x=mode==='maze'?0:Math.PI/2;goal.position.y=.065;pieces.add(goal);
 const stars=[],mirrors=[],obstacles=[];
 // Shared boxes keep every maze divider and its cap in just two draw calls.
 let mazeWalls=null,mazeCaps=null;
 if(mode==='maze'){
  const geometry=new T.BoxGeometry(1,1,1),count=Math.max(...MAZE_LEVELS.map(l=>l.walls.length));geometries.push(geometry);
  mazeWalls=new T.InstancedMesh(geometry,wood,count);mazeCaps=new T.InstancedMesh(geometry,cream,count);
  mazeWalls.name='maze-walls';mazeCaps.name='maze-wall-caps';pieces.add(mazeWalls,mazeCaps);
 }
 for(let i=0;i<3;i++){
  const shape=new T.Shape();for(let k=0;k<10;k++){const a=k*Math.PI/5+Math.PI/2,r=k%2?.065:.14;if(k)shape.lineTo(Math.cos(a)*r,Math.sin(a)*r);else shape.moveTo(Math.cos(a)*r,Math.sin(a)*r);}shape.closePath();
  const geo=new T.ExtrudeGeometry(shape,{depth:.035,bevelEnabled:true,bevelThickness:.014,bevelSize:.012,bevelSegments:1});geometries.push(geo);
  const star=new T.Mesh(geo,gold);star.rotation.x=-Math.PI/2;pieces.add(star);stars.push(star);

 }
 for(let i=0;i<4;i++){
  const mirror=box(pieces,.91,.32,.09,0,.16,0,i%2?walnut:wood);mirror.name='ricochet-paddle-'+i;mirrors.push(mirror);
  // Inlaid maple strips, end grain caps and a wooden pivot make each rotating paddle legible.
  box(mirror,.91,.026,.108,0,.148,0,honey);box(mirror,.87,.024,.104,0,-.136,0,cream);
  for(const side of [-1,1])box(mirror,.035,.29,.113,side*.432,0,0,cream);
  const pivot=new T.Mesh(new T.CylinderGeometry(.07,.07,.038,16),honey);geometries.push(pivot.geometry);pivot.position.y=.179;mirror.add(pivot);
  box(mirror,.08,.012,.016,0,.204,0,walnut);

 }
 for(let i=0;i<2;i++){const block=box(pieces,1,.35,1,0,.175,0,walnut);block.name='ricochet-obstacle-'+i;box(block,.94,.045,.94,0,.183,0,wood);obstacles.push(block);}
 const gateMesh=box(pieces,.16,.27,.42,0,.135,0,violet);
 const dots=[];const dotGeo=new T.SphereGeometry(.025,8,6);geometries.push(dotGeo);
 for(let i=0;i<12;i++){const dot=new T.Mesh(dotGeo,wooden?honey:gold);pieces.add(dot);dots.push(dot);}
 let character=null,levelShown=-1,statusKey='',time=0;
 const grips=new Map(),aim={x:0,z:-1};let trigger=null;
 const game=createTabletopGame(mode,(_points,result)=>{ctx.tabletopWin?.(result);ctx.addCount(mode);ctx.chime();const at=V(game.ball.x,TABLE_RADIUS,game.ball.z);board.localToWorld(at);ctx.confetti.celebrate(at);});
 const localRay=new T.Ray(),raycaster=new T.Raycaster(),up=V(0,1,0),inverseQ=new T.Quaternion();
 function localInput(input){grp.updateWorldMatrix(true,true);grp.getWorldQuaternion(inverseQ).invert();return {q:inverseQ.clone().multiply(input.rotation),pos:grp.worldToLocal(input.position.clone())};}
 function aimAt(input){
  grp.updateWorldMatrix(true,true);localRay.origin.copy(board.worldToLocal(input.ray.origin.clone()));
  localRay.direction.copy(input.ray.dir).transformDirection(new T.Matrix4().copy(board.matrixWorld).invert());
  if(localRay.direction.y>=-.01)return;
  const t=(TABLE_RADIUS-localRay.origin.y)/localRay.direction.y;if(t<=0)return;
  const x=localRay.origin.x+localRay.direction.x*t-game.ball.x,z=localRay.origin.z+localRay.direction.z*t-game.ball.z,d=Math.hypot(x,z);
  if(d>.08){aim.x=x/d;aim.z=z/d;}
 }
 function paintFloor(){
  c.clearRect(0,0,1024,1152);c.save();c.scale(1024/3,1152/3.4);c.translate(1.5,1.7);
  if(mode==='balance'){
   const l=game.definition;c.strokeStyle='#faedc9';c.lineWidth=l.width*2;c.lineCap=c.lineJoin='round';c.beginPath();l.path.forEach((p,i)=>i?c.lineTo(p.x,p.z):c.moveTo(p.x,p.z));c.stroke();
   c.strokeStyle='#d5b285';c.lineWidth=.028;c.setLineDash([.06,.06]);c.stroke();c.setLineDash([]);
   c.globalCompositeOperation='destination-out';for(const h of l.holes){c.beginPath();c.arc(h.p.x,h.p.z,h.r,0,Math.PI*2);c.fill();}c.globalCompositeOperation='source-over';
  }else{
   c.fillStyle='#d4a16b';c.fillRect(-1.5,-1.7,3,3.4);
   for(let i=0;i<6;i++){const x=-1.5+i*.5;c.fillStyle=i%2?'#c69865':'#d7af7b';c.fillRect(x,-1.7,.496,3.4);
    for(let k=0;k<7;k++){c.strokeStyle=k%2?'#b98c5b':'#e1bc8e';c.lineWidth=.009;c.beginPath();for(let z=-1.7;z<=1.71;z+=.1){const xx=x+.035+k*.066+Math.sin(z*6+i+k)*.008;if(z===-1.7)c.moveTo(xx,z);else c.lineTo(xx,z);}c.stroke();}}
   c.strokeStyle='#f5dba9';c.lineWidth=.035;c.strokeRect(-1.43,-1.63,2.86,3.26);
  }
  const start=mode==='balance'?game.definition.path[0]:game.definition.start;c.fillStyle=wooden?'#f2d195':'#c5dbad';c.beginPath();c.arc(start.x,start.z,.23,0,Math.PI*2);c.fill();c.restore();map.needsUpdate=true;
 }
 function levelArt(){
  if(levelShown===game.level)return;levelShown=game.level;paintFloor();
  const l=game.definition,end=mode==='balance'?l.path[l.path.length-1]:l.goal;goal.position.set(end.x,.065,end.z);
  if(mazeWalls){
   const matrix=new T.Matrix4(),q=new T.Quaternion();mazeWalls.count=mazeCaps.count=l.walls.length;
   l.walls.forEach((w,i)=>{
    matrix.compose(V(w.x,MAZE_WALL_HEIGHT/2,w.z),q,V(w.hx*2,MAZE_WALL_HEIGHT,w.hz*2));mazeWalls.setMatrixAt(i,matrix);
    matrix.compose(V(w.x,MAZE_WALL_HEIGHT+.012,w.z),q,V(w.hx*2,.024,w.hz*2));mazeCaps.setMatrixAt(i,matrix);
   });
   for(const mesh of [mazeWalls,mazeCaps]){mesh.instanceMatrix.needsUpdate=true;mesh.computeBoundingSphere();}
  }
  stars.forEach((s,i)=>{s.visible=tilting;if(s.visible)s.position.set(l.stars[i].x,.13,l.stars[i].z);});
  mirrors.forEach((m,i)=>{m.visible=mode==='ricochet'&&i<l.mirrors.length;if(m.visible){m.position.set(l.mirrors[i].x,.16,l.mirrors[i].z);m.scale.x=l.mirrors[i].length/.91;}});
  obstacles.forEach((m,i)=>{m.visible=mode==='ricochet'&&i<l.obstacles.length;if(m.visible){const b=l.obstacles[i];m.scale.set(b.hx*2,1,b.hz*2);m.position.set(b.x,.175,b.z);}});
  gateMesh.visible=tilting&&!!l.gate;
 }
 function status(english){
  const key=[english,game.level,game.phase,game.stars.size,game.bounces.size,game.attempts,game.score,grips.size>0].join('|');if(key===statusKey)return;statusKey=key;
  const c=signCanvas.getContext('2d'),tr=(ar,en)=>english?en:ar,pair=(a,b)=>`\u2066${a} / ${b}\u2069`;
  c.fillStyle='#815635';c.fillRect(0,0,1536,352);c.fillStyle=wooden?'#d7ae7b':'#fff6df';c.fillRect(16,16,1504,320);c.fillStyle='#59402f';c.textAlign='center';c.direction=english?'ltr':'rtl';
  c.font='500 64px "Dahrooj",Tahoma,sans-serif';c.fillText(tr(mode==='balance'?'التوازن':mode==='ricochet'?'الارتداد':'المتاهة',mode==='balance'?'Balance':mode==='ricochet'?'Ricochet':'Maze')+' · '+tr(`المرحلة ${pair(game.level+1,game.levelCount)}` ,`Round ${game.level+1} / ${game.levelCount}`),768,101,1430);
  c.font='500 44px "Dahrooj",Tahoma,sans-serif';
  const hint=game.phase==='won'?tr('أحسنت! المرحلة التالية…','Nice! Next round…'):game.phase==='falling'?tr('جرّب مرة ثانية','Try again'):mode==='balance'?tr('امسك بالقبضة وأمل اللوح · اجمع النجوم','Hold grip and tilt the board · collect the stars'):mode==='ricochet'?tr('القبضة: تدوير بخطوات ٥° · الزناد: وجّه وأطلق','Grip: turn in 5° steps · Trigger: aim and release'):tr('امسك بالقبضة وأمل اللوح · اجمع النجوم ثم اتجه للهدف','Hold grip and tilt · collect the stars, then reach the goal');
  c.fillText(hint,768,187,1430);c.fillStyle='#62825c';c.font='500 43px "Dahrooj",Tahoma,sans-serif';
  c.fillText(tilting?tr(`النجوم ${pair(game.stars.size,3)} · النقاط ${game.score}`,`Stars ${game.stars.size} / 3 · Score ${game.score}`):tr(`ألواح ${pair(game.bounces.size,game.definition.required)} · محاولات ${game.attempts} · النقاط ${game.score}`,`Paddles ${game.bounces.size} / ${game.definition.required} · Throws ${game.attempts} · Score ${game.score}`),768,274,1430);signMap.needsUpdate=true;
 }
 function cancel(){grips.clear();trigger=null;game.setTilt(0,0);}
 function press(input,how){
  if(tilting){
   if(!grips.has(input.id)){const local=localInput(input);grips.set(input.id,{...local,buttons:new Set([how]),tilt:{...game.tilt}});}else grips.get(input.id).buttons.add(how);
  }else if(how==='grip'){
   if(mode!=='ricochet')return;
   if(game.phase!=='ready')return;raycaster.set(input.ray.origin,input.ray.dir);grp.updateWorldMatrix(true,true);
   const hit=raycaster.intersectObjects(mirrors.filter(m=>m.visible),false)[0];if(!hit)return;
   const local=localInput(input),index=mirrors.indexOf(hit.object);grips.set(input.id,{...local,index,angle:game.angles[index]});
  }else if(!trigger&&game.phase==='ready'&&!grips.size){trigger=input.id;aimAt(input);}
 }
 function release(id,lost=false,how){
  if(tilting){
   const grip=grips.get(id);if(grip&&how&&!lost){grip.buttons.delete(how);if(!grip.buttons.size)grips.delete(id);}else grips.delete(id);
   if(!grips.size)game.setTilt(0,0);
  }else{
   if(lost||!how||how==='grip')grips.delete(id);
   if(trigger===id&&(lost||!how||how==='trigger')){trigger=null;if(!lost&&game.launch(aim))ctx.whoosh(.5);}
  }
 }
 function frame(dt,{inputs,active,models,style,accessory,eye,english}){
  time+=active?dt:0;
  for(const [id] of grips)if(!inputs.some(h=>h.id===id))release(id,true);
  if(trigger&&!inputs.some(h=>h.id===trigger))release(trigger,true);
  const held=[];
  if(active)for(const input of inputs){const grip=grips.get(input.id);
   if(grip){const local=localInput(input);
    if(tilting){
     const delta=local.q.clone().multiply(grip.q.clone().invert()),normal=up.clone().applyQuaternion(delta);
     held.push({x:grip.tilt.x+Math.atan2(normal.x,normal.y),z:grip.tilt.z+Math.atan2(normal.z,normal.y),pos:local.pos,base:grip.pos});
    }else{
     const a=V(0,0,-1).applyQuaternion(grip.q),b=V(0,0,-1).applyQuaternion(local.q);
     if(Math.hypot(a.x,a.z)>.08&&Math.hypot(b.x,b.z)>.08){const angle=Math.atan2(b.z,b.x)-Math.atan2(a.z,a.x);game.turnMirror(grip.index,grip.angle+angle);}
    }
   }
   if(!tilting&&(!trigger||trigger===input.id)&&!grip&&game.phase==='ready')aimAt(input);
  }
  if(held.length){let x=held.reduce((s,h)=>s+h.x,0)/held.length,z=held.reduce((s,h)=>s+h.z,0)/held.length;
   if(held.length===2){const d=held[1].pos.clone().sub(held[0].pos),b=held[1].base.clone().sub(held[0].base),k=d.x*d.x+d.z*d.z;if(k>.04){x-=(d.y-b.y)*d.x/k;z-=(d.y-b.y)*d.z/k;}}
   game.setTilt(x,z);
  }
  game.step(dt,active&&(!tilting||grips.size>0||game.phase==='won'||game.phase==='falling'));
  if(levelShown!==game.level)cancel();board.rotation.set(game.tilt.z,0,-game.tilt.x);
  levelArt();status(english);
  stars.forEach((s,i)=>{if(tilting){s.visible=!game.stars.has(i);s.rotation.z=time*.6;}});
  mirrors.forEach((m,i)=>{if(m.visible){m.rotation.y=-game.angles[i];m.material=[...grips.values()].some(g=>g.index===i)||game.bounces.has(i)?honey:i%2?walnut:wood;}});

  const gate=game.gate;if(gateMesh.visible&&gate)gateMesh.position.set(gate.x,.135,gate.z);
  handles.forEach(h=>{h.material=grips.size?gold:cream;h.visible=tilting;});
  dots.forEach((d,i)=>{d.visible=!tilting&&game.phase==='ready'&&!grips.size;if(d.visible){const t=.24+i*.10;d.position.set(game.ball.x+aim.x*t,.07,game.ball.z+aim.z*t);d.visible=Math.abs(d.position.x)<1.45&&Math.abs(d.position.z)<1.65;}});
  if(models){
   if(!character||character.style!==style){character?.dispose();character=models.make(style,{face:true});board.add(character.group);}
   character.setAccessory(accessory);board.updateWorldMatrix(true,true);
   character.update({pos:V(game.ball.x,TABLE_RADIUS-game.fall,game.ball.z),toward:eye,faceName:game.phase==='won'?'joy':game.phase==='falling'?'wide':'focus'});
   character.group.scale.multiplyScalar(TABLE_RADIUS/ctx.BR);character.group.visible=game.fall<.45;
  }
 }
 levelArt();status(ctx.xrLang==='en');
 return {grp,tabletop:true,aimZ:-3,farZ:-5,game,
  collide(){},update(){},onRespawn(){cancel();if(game.phase!=='ready'&&game.phase!=='won')game.retry();},deactivate:cancel,
  xrPress:press,xrRelease:release,xrCancel:cancel,xrFrame:frame,
  dispose(){cancel();character?.dispose();mazeWalls?.dispose();mazeCaps?.dispose();grain.dispose();map.dispose();signMap.dispose();for(const m of materials)m.dispose();for(const g of geometries)g.dispose();grp.removeFromParent();},
 };
}
