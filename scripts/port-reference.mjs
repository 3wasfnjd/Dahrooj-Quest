import {renderOverrides} from './render-overrides.mjs';
/** Reproducible, selective port. Input is a read-only checkout of quest@c7925b7. */
import fs from 'node:fs';
import {styleOverrides} from './style-overrides.mjs';
import path from 'node:path';
import crypto from 'node:crypto';
import ts from 'typescript';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url),espree=require('espree'),scope=require('eslint-scope');
const root=process.argv[2]||'../legacy-reference';
const html=fs.readFileSync(path.join(root,'index.html'),'utf8');
const source=[...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)].map(m=>m[1]).join('\n');
const ast=ts.createSourceFile('reference.js',source,ts.ScriptTarget.Latest,true,ts.ScriptKind.JS);
const functions=new Map();function visit(n){if(ts.isFunctionDeclaration(n)&&n.name)functions.set(n.name.text,n.getText(ast));ts.forEachChild(n,visit)}visit(ast);
const prefix='/* Aboden Games. Ported with owner authorization 2026-10-08 from quest@c7925b7cd7371b6bb87c44a0743721ad55f177dd. See docs/REFERENCE-REUSE-AR.md. */\n';
const records=[];
function write(file,text,origin){text=renderOverrides(file,styleOverrides(file,text));fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,prefix+text+'\n');records.push({file,origin,sha256:crypto.createHash('sha256').update(prefix+text+'\n').digest('hex')})}
function replace(s,a,b){if(!s.includes(a))throw Error('Missing source marker '+a.slice(0,80));return s.replace(a,b)}
function body(file,marker){const s=fs.readFileSync(path.join(root,file),'utf8'),start=s.indexOf(marker);if(start<0)throw Error(marker);return s.slice(start+marker.length,s.lastIndexOf('\n  };'))}
const faces=functions.get('drawEye')+'\n'+functions.get('drawFace');
write('src/reference/face.js',`export function drawReferenceFace(c,Rr,face,lx,ly,blushK,blinkOn,style,noEyes){\nconst COL={ink:'#2c2d3d'},ballStyle=style,time=0;\n${faces}\nreturn drawFace(c,Rr,face,lx,ly,blushK,blinkOn,noEyes);\n}`, 'index.html:drawEye/drawFace');
let character=body('assets/xr/dahrooj3d.js','window.createDahrooj3D=(T,{radius,drawFace,renderer})=>{');
character=character.replace('outer.add(inner);','outer.add(inner);outer.userData.referenceCharacter=true;');
character=character.replace('dispose(){outer.traverse(o=>{if(o.isMesh&&o.material!==undefined&&!o.geometry.isShared)o.material.dispose?.();});}', 'dispose(){if(cap)cap.material.dispose();jellyModels.delete(outer);outer.removeFromParent();}');
character=character.replace('r,64,40','r,32,20').replace('t.anisotropy=4;return t;','t.anisotropy=4;t.colorSpace=T.SRGBColorSpace;return t;');
character=character.replace('pm.dispose();','pm.dispose();room.dispose();');
character=character.replace("if(m.sheen!==undefined)m.sheen=new T.Color(0xc77d93);","m.sheen=.35;m.sheenColor.set(0xc77d93);");
character=character.replace('scleraFelt.sheen=new T.Color(0x8a8070)', '{scleraFelt.sheen=.35;scleraFelt.sheenColor=new T.Color(0x8a8070);}') ;
character=character.replace('sheen:new T.Color(0xff9a80)','sheen:.5,sheenColor:new T.Color(0xff9a80)');
character=replace(character,'// Place a part on the surface',`const sharedMaterials=Object.fromEntries(Object.entries(MATERIALS).map(([id,make])=>[id,make()]));\n    const decorations={};\n    function decoration(id){ if(!decorations[id])decorations[id]=batchReferenceMeshes(({bandaid,stitches,bow})[id]()); return decorations[id].clone(true); }\n    // Place a part on the surface`);
character=character.replace('MATERIALS[style]?.()||MATERIALS.jelly()','sharedMaterials[style]||sharedMaterials.jelly').replace('inner.add(bandaid())',"inner.add(decoration('bandaid'))").replace('inner.add(stitches())',"inner.add(decoration('stitches'))").replace('bowMesh=bow()',"bowMesh=decoration('bow')");
character=character.replace('const qx=Math.round(lx*2)/2,qy=Math.round(ly*2)/2,key=[style,face,qx,qy,blink?1:0,noEyes?1:0]', 'const qx=0,qy=0,key=[style,face,noEyes?1:0]');
character=character.replace('drawFace(c,R,face,qx,qy,0,blink,style,noEyes)','drawFace(c,R,face,qx,qy,.25,false,style,noEyes)');
character=character.replace("if(faces.size>160){const first=faces.keys().next().value;faces.get(first).dispose();faces.delete(first);}", '');
character=character.replace("m.frustumCulled=false;m.renderOrder=order;",'m.frustumCulled=true;m.renderOrder=order;');
character=character.replace('for(const m of group.children)m.instanceMatrix.needsUpdate=true;', 'for(const m of group.children){m.instanceMatrix.needsUpdate=true;m.computeBoundingSphere();}');
character=replace(character,'return {make,crowd,updateProbe,forget(group){jellyModels.delete(group);}};',`for(const style of Object.keys(MATERIALS))for(const name of ['open','focus','wide','joy','closed','squint','laugh','dizzy','hurt'])faceTexture(style,name,0,0,false,EYE_FACES.has(name));\n    return {make,crowd,updateProbe,mats:sharedMaterials,time:bubbleTime,forget(group){jellyModels.delete(group);}};`);
write('src/reference/character.js',`import {batchReferenceMeshes} from './mesh-batch';\nexport function createReferenceCharacter(T,{radius,drawFace,renderer}){${character}\n}`, 'assets/xr/dahrooj3d.js');
const climb=fs.readFileSync(path.join(root,'assets/climb/climb.js'),'utf8');
const core=climb.slice(climb.indexOf('  const G=60'),climb.indexOf('  globalThis.DahroojClimbCore=api;'));
write('src/reference/summit-core.js',core+'\nexport default api;', 'assets/climb/climb.js:core only, no mobile UI');
let mountain=body('assets/xr/climb3d.js','window.createDahroojClimb3D=(T,{core:C,models,BR,renderer,width=16.25,unit=.022})=>{');
// Effects use the application pool; no per-impact material/mesh allocations.
const mtast=ts.createSourceFile('m.js','function mountain(){'+mountain+'}',ts.ScriptTarget.Latest,true,ts.ScriptKind.JS);let burstText='';function scan(n){if(ts.isFunctionDeclaration(n)&&n.name?.text==='burst')burstText=n.getText(mtast);ts.forEachChild(n,scan)}scan(mtast);
mountain=replace(mountain,burstText,'function burst(x,y,colors,count,speed){onBurst?.(world.localToWorld(V(X(x),y,.3)),colors,count,speed*unit);}');
mountain=mountain.replace('if(hero)world.remove(hero.group);','if(hero)hero.dispose();').replace('if(m)world.remove(m.group);','if(m)m.dispose();');
mountain=mountain.replace('      group,','      group,dispose(){hero?.dispose();for(const m of shotModels)m?.dispose();const gs=new Set(),ms=new Set();group.traverse(o=>{if(o.isMesh){gs.add(o.geometry);for(const m of Array.isArray(o.material)?o.material:[o.material])ms.add(m);}});for(const g of gs)g.dispose();for(const m of ms)m.dispose();},');
mountain=mountain.replace('C.step(state,dt);','// Fixed-step simulation is owned by the TypeScript system.');
write('src/reference/summit-world.js',`const THEMES=[0x7f9a5b,0xa38b74,0x77728a,0xe8f1f5],DEPTH=3,VIEW=24,BELOW=2;\nexport function createReferenceMountain(T,{core:C,models,BR,renderer,width=16.25,unit=.022,onBurst}){${mountain}\n}`, 'assets/xr/climb3d.js');
// Keep original stage factories, physics and expose their render objects to a typed adapter.
for(const name of ['Goal','Hoop','Window','Cans','Bowling','Bricks','Fair']){
 let text=functions.get('build'+name);
 // The owner subsequently requested the original physics as well (2026-10-08).
 // Restore the reference solvers; only module/asset/storage boundaries change.
 text=functions.get('build'+name);
 if(name==='Goal')text=text.replace('grp, aimZ:GZ-0.3,','grp, bridge:{kinematics:[kBall,...kHands.map(h=>h.h)]}, aimZ:GZ-0.3,');
 if(name==='Window')text=text.replace('W.pop=0;','W.pop=0;ctx.changed();');
 if(name==='Cans'||name==='Bowling'){
  const list=name==='Cans'?'cans':'pins';
  text=text.replace('grp, aimZ:',`grp, bridge:{bodies:${list},radius:CR,height:CH}, aimZ:`);
  if(name==='Bowling'){
   text=text.replace("if(T.GLTFLoader) new T.GLTFLoader().load('assets/xr/motri/bowlingPin.glb',gltf=>{", "ctx.loadPin(gltf=>{");
   text=text.replace('if(mat.map) mat.map.encoding=T.sRGBEncoding;', 'if(mat.map)mat.map.colorSpace=T.SRGBColorSpace;');
  }
 }
 if(name==='Bricks'){
  text=text.replace('grp, aimZ:FACE+BD,','grp, bridge:{get bricks(){return B.bricks;}}, aimZ:FACE+BD,');
  text=text.replace('buildTowers(B.level);','buildTowers(B.level);ctx.changed();');
  const start=text.indexOf('      const star=new T.Mesh(starGeo,starMat);'),end=text.indexOf("      addCount('bricks');",start);
  text=text.slice(0,start)+'      ctx.breakBrick(b,n,speed);\n'+text.slice(end);
 }
 if(name==='Fair'){
  text=text.replace('grp, aimZ:FZ,','grp, bridge:{ducks,balloons,bell:bellM,stall}, aimZ:FZ,');
  text=text.replace("try{ F.best=+localStorage.getItem('dahrooj-fair-best')||0; }catch(_){}",'F.best=ctx.best();');
  text=text.replace("try{ localStorage.setItem('dahrooj-fair-best',String(F.best)); }catch(_){}",'ctx.best(F.best);');
  text=text.replaceAll('d.g.getWorldPosition(wp);','grp.worldToLocal(d.g.getWorldPosition(wp));').replaceAll('bellM.getWorldPosition(wp);','grp.worldToLocal(bellM.getWorldPosition(wp));');
  text=text.replace('const owns=root=>','if(!F.on) return false; const owns=root=>');
  text=text.replace('"Baloo Bhaijaan 2",Tahoma','"Dahrooj",Tahoma');
 }
 // Observable adapters replace WebAudio/global UI and never move the XR camera.
 const parsed=espree.parse(text,{ecmaVersion:'latest',sourceType:'module',range:true});
 const deps=[...new Set(scope.analyze(parsed,{ecmaVersion:2022,sourceType:'module'}).globalScope.through.map(r=>r.identifier.name))].filter(x=>!['Math','Array','Float32Array','Object','Set','Map','String','Number','document','ctx'].includes(x));
 const dynamic=deps.filter(x=>['time','xrLang'].includes(x)),fixed=deps.filter(x=>!dynamic.includes(x));
 const wrapper=`export default function create(ctx){\nconst {${fixed.join(',')}}=ctx;\n${dynamic.length?'let {'+dynamic.join(',')+'}=ctx;':''}\n${text}\nconst stage=build${name}(),update=stage.update;stage.update=function(dt){${dynamic.map(x=>`${x}=ctx.${x};`).join('')}update.call(stage,dt);};return stage;\n}`;
 write('src/reference/stages/'+name.toLowerCase()+'.js',wrapper,'index.html:build'+name);
 console.log(name,deps.join(','));
}
write('src/reference/stage-art.js',`export function stageArt(ctx){const {T,V,UP,scene,S,BR,hit}=ctx;const INK=0x2c2d3d;const lineMat=new T.MeshBasicMaterial({color:INK,transparent:true,opacity:.18}),postMat=new T.MeshStandardMaterial({color:INK,roughness:.7}),netMat=new T.LineBasicMaterial({color:INK,transparent:true,opacity:.3});\n${['groundLine','groundArc','bar','netGrid','rbox','bodyOf','shove','segCollide','pointCollide'].map(n=>functions.get(n)).join('\n').replace('m.castShadow=true; grp.add(m); return m;',"m.castShadow=true;m.userData.collider='Cylinder';grp.add(m);return m;").replace('b.sleep=false; }','b.sleep=false;ctx.pushBody(b); }')}\nreturn {lineMat,postMat,netMat,groundLine,groundArc,bar,netGrid,rbox,bodyOf,shove,segCollide,pointCollide};\n}`, 'index.html:shared stage art helpers');
fs.writeFileSync('docs/reference-port-manifest.json',JSON.stringify({source:'3wasfnjd/quest',commit:'c7925b7cd7371b6bb87c44a0743721ad55f177dd',authorization:'Owner explicitly requested reuse of mode, projectile, style code and assets on 2026-10-08.',files:records},null,2)+'\n');

let physics=functions.get('ballStepAt');
physics=physics.replace('if(restHook&&xrOn()) restHook(P.clone(),v.clone()); if(extra) return true; respawn(); return false;', 'S.shot=false;return false;');
write('src/reference/ball-physics.js',`export function referenceBallPhysics(ctx){const {S,GRAV,BR,UP,V,hit,waterHook,splash,miss}=ctx;const xrOn=()=>true;const outsideView=()=>false;return function step(dt){const stage=ctx.stage;${physics}return ballStepAt(dt,true);};}`, 'index.html:ballStepAt');
const xr=fs.readFileSync(path.join(root,'assets/xr/xr.js'),'utf8');
const drop=xr.slice(xr.indexOf('    function dropBall(delay)'),xr.indexOf('    function spawnIntro()'));
let rain=xr.slice(xr.indexOf('      for(const b of live){'),xr.indexOf('      for(let k=I.sparks.length-1;k>=0;k--){'));
write('src/reference/rain-physics.js',`export function createReferenceRain(T,capacity){const V=(x=0,y=0,z=0)=>new T.Vector3(x,y,z),clamp=(v,a,b)=>Math.max(a,Math.min(b,v)),REAL_G=9.8,INTRO_R=.11,INTRO_STYLES=['jelly','fabric','clay','fur','bubble'];let ballIds=0;const intro={balls:[],t:0,centre:V()},crowdSize=()=>({R:4.4}),g={},at=()=>{},roomPoint=p=>p;${drop}\nfor(let i=0;i<capacity;i++)dropBall(Math.random()*2.6);return {balls:intro.balls,step(dt,head,count){intro.t+=dt;const ROOM=4.4,c=intro.centre,live=intro.balls.slice(0,count).filter(b=>intro.t>=b.born);${rain}\nreturn live;},reset(b){const index=intro.balls.indexOf(b);dropBall(.3+Math.random()*1.5);const next=intro.balls.pop();Object.assign(intro.balls[index],next);}};}`, 'assets/xr/xr.js:dropBall/stepIntro room physics');
write('src/reference/projectile-spec.js',`export const SHOT_STYLE=${xr.slice(xr.indexOf('    const SHOT_STYLE={')+'    const SHOT_STYLE='.length,xr.indexOf('    let shotChosen')).trim().replace(/;$/,'')};\nexport const FIRE_COLS=[0xe2603f,0xf2c14e,0x6fa8d6,0x7bbf8a,0xc9a2e6,0xfffaf2];\nexport function advanceShot(s,dt,k){s.v.y-=9.8*k*SHOT_STYLE[s.kind].grav*dt;if(s.kind==='bubble'){s.wob+=dt*3;s.v.x+=Math.sin(s.wob)*.25*k*dt;s.v.z+=Math.cos(s.wob*.8)*.25*k*dt;}s.p.addScaledVector(s.v,dt);}\nexport function groundMini(s,dt,floor,k){s.p.y=floor+s.r;if(s.v.y<-.8*k)s.v.y*=-.45;else s.v.y=0;const f=Math.pow(.55,dt);s.v.x*=f;s.v.z*=f;}`, 'assets/xr/xr.js:SHOT_STYLE/stepBlast');
// Refresh all port hashes only after every extracted module has been written.
fs.writeFileSync('docs/reference-port-manifest.json',JSON.stringify({source:'3wasfnjd/quest',commit:'c7925b7cd7371b6bb87c44a0743721ad55f177dd',authorization:'Owner requested reference code, assets AND physics on 2026-10-08.',files:records},null,2)+'\n');
