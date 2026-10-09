import {grayMenuOverrides} from './gray-menu-overrides.mjs';
import {menuWorldOverrides} from './menu-world-overrides.mjs';
import {opaqueMenuOverrides} from './opaque-menu-overrides.mjs';
import {fireworkOverrides} from './firework-overrides.mjs';
import {compactModesOverrides} from './compact-modes-overrides.mjs';
import {frontRainOverrides} from './front-rain-overrides.mjs';
import {fairDisplayOverrides} from './fair-display-overrides.mjs';
import {worldCleanupOverrides} from './world-cleanup-overrides.mjs';
import {rainScoreOverrides} from './rain-score-overrides.mjs';
import {summitOverrides} from './summit-overrides.mjs';
import {visibilityOverrides} from './visibility-overrides.mjs';
import {menuOverrides} from './menu-overrides.mjs';
import {challengeOverrides} from './challenge-overrides.mjs';
import {renderOverrides} from './render-overrides.mjs';
import fs from 'node:fs';import {styleOverrides} from './style-overrides.mjs';import * as espree from 'espree';import * as scope from 'eslint-scope';import ts from 'typescript';import crypto from 'node:crypto';
const root=process.argv[2]||'../legacy-reference';const read=p=>fs.readFileSync(`${root}/${p}`,'utf8');const header='/* Aboden Games reference implementation, owner-authorized complete port 2026-10-08. See COMPLETE-REFERENCE-PORT-AR.md. */\n';
const records=[];const write=(p,s,origin)=>{s=grayMenuOverrides(p,menuWorldOverrides(p,opaqueMenuOverrides(p,fireworkOverrides(p,compactModesOverrides(p,frontRainOverrides(p,fairDisplayOverrides(p,worldCleanupOverrides(p,rainScoreOverrides(p,summitOverrides(p,visibilityOverrides(p,menuOverrides(p,challengeOverrides(p,renderOverrides(p,styleOverrides(p,s)))))))))))))));fs.writeFileSync(p,header+s);records.push({path:p,origin,sha256:crypto.createHash('sha256').update(header+s).digest('hex')});};
const source=[...read('index.html').matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)].map(m=>m[1]).join('\n');const ast=ts.createSourceFile('ref.js',source,ts.ScriptTarget.Latest,true,ts.ScriptKind.JS),functions=new Map();function walk(n){if(ts.isFunctionDeclaration(n)&&n.name)functions.set(n.name.text,n.getText(ast));ts.forEachChild(n,walk)}walk(ast);
let s=read('assets/xr/nature.js');s=s.replace('(() => {',"export const createReferenceNature=(() => {").replace('const T=THREE,','const T=THREE,').replace("const BASE=(document.currentScript&&document.currentScript.src)?new URL('./motri/',document.currentScript.src).href:'./assets/xr/motri/';","const BASE='/assets/';").replace('window.createDahroojNature=','return ');
s=s.replaceAll("BASE+'slabs.png'","BASE+'textures/slabs.png'").replaceAll("BASE+'foliageSDF.png'","BASE+'textures/foliageSDF.png'").replaceAll('BASE+file',"BASE+'models/'+file");
write('src/reference/nature.js',"import * as Core from '@iwsdk/core';\nimport {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';\nconst THREE={...Core,GLTFLoader};\n"+s,'assets/xr/nature.js');
s=read('assets/xr/ambience.js').replace('(() => {','export const createReferenceAmbience=(() => {').replace('window.createDahroojAmbience=','return ');write('src/reference/ambience.js',s,'assets/xr/ambience.js');
s=read('assets/audio/background-music.js');s=s.slice(0,s.indexOf('  /* ---------- the player:'));s=s.replace('(() => {','export const createReferenceMusic=(() => {').replace('window.createDahroojMusic =','return ')+'\n})();\n';write('src/reference/music.js',s,'assets/audio/background-music.js: original synthesis without DOM player');
const soundNames=['sfxDest','sfxOut','playAt','setListener','ensureAudio','thump','squeak','pew','splash','boom','whoosh','swish','chime','startPopSound'];
write('src/reference/sounds.js',`import {createReferenceMusic} from './music.js';\nexport function createReferenceSounds(){let audio=null,soundAt=null,soundRef=1,sfxBus=null,music=null,musicGain=null;\n${soundNames.map(n=>functions.get(n)).join('\n')}\nreturn {${soundNames.join(',')},get context(){return audio;},unlock(){ensureAudio();if(audio&&!music){musicGain=audio.createGain();musicGain.gain.value=.067;musicGain.connect(audio.destination);music=createReferenceMusic(audio,musicGain);music.start();}},focus(on){if(audio)(on?audio.resume():audio.suspend()).catch(()=>{});}};}`, 'index.html:original sound functions');
s=read('assets/xr/xr.js').replace('(() => {','export const createReferenceXR=(() => {').replace('window.createDahroojXR=','return ');
s=s.replaceAll('window.createDahrooj3D','createReferenceCharacter').replaceAll('window.createDahroojNature','createReferenceNature').replaceAll('window.createDahroojAmbience','createReferenceAmbience').replaceAll('window.createDahroojClimb3D','createReferenceMountain');
s=s.replace('const rig=new T.Group();','const rig=g.player;');
s=s.replace('session=s;kind=mode;layoutMenu();','session=s;kind=mode;lang=g.language();layoutMenu();');
s=s.replace("const s=await navigator.xr.requestSession(mode,options);","const s=g.getSession();if(!s)throw new Error('IWSDK session required');");
s=s.replace('scene.add(rig);rig.add(camera);place();','place();').replace('await renderer.xr.setSession(s);','// IWSDK owns the XR session.').replace('lastTime=0;frames=0;renderer.setAnimationLoop(loop);','lastTime=0;frames=0;');
s=s.replace('renderer.setAnimationLoop(null);','// IWSDK keeps its render loop.').replace('rig.remove(camera);scene.remove(rig);','rig.scale.setScalar(1);rig.position.set(0,0,0);rig.quaternion.identity();').replace('renderer.xr.enabled=false;','');
s=s.replace('return {enter,get presenting()', 'return {enter,frame:loop,get presenting()');
s=s.replace("function press(h,how)","function press(h,how)");
// System-UI focus is an independent platform requirement absent in the legacy loop.
s=s.replace("function loop(time,frame){", "function loop(time,frame){if(!session||session.visibilityState!=='visible'||!frame.getViewerPose(renderer.xr.getReferenceSpace())){lastTime=time;for(const h of hands){release(h,true);h.line.visible=false;h.dot.visible=false;}g.focus(false);return;}g.focus(true);");
s=s.replace('function press(h,how){',"function press(h,how){if(!session||session.visibilityState!=='visible')return;");
s=s.replace('function release(h,lost){',"function release(h,lost){if(session?.visibilityState!=='visible')lost=true;");
s=s.replace('const kind_=styleFor(fromIntro),P=SHOT_STYLE[kind_];','if(blast.shots.length>=32)return;const kind_=styleFor(fromIntro),P=SHOT_STYLE[kind_];');

s=s.replaceAll('Baloo Bhaijaan 2','Dahrooj');
s=s.replace('get placing(){',"...(import.meta.env.DEV?{action:menuAction,choosePlaza}:{}),get placing(){");
s=s.replace(',addTestPlane,',',...(import.meta.env.DEV?{addTestPlane}:{}),');
s=s.replace('      testDrop(P,v){','      ...(import.meta.env.DEV?{testDrop(P,v){').replace('get anchor(){return anchor;}', '}:{}),get anchor(){return anchor;}');
s=s.replace('inspect:()=>hands.map', '...(import.meta.env.DEV?{inspect:()=>hands.map').replace('velocity:velocity(h).toArray()}))};','velocity:velocity(h).toArray()}))}:{} )};');
write('src/reference/xr-runtime.js',"import {createReferenceCharacter} from './character.js';\nimport {createReferenceNature} from './nature.js';\nimport {createReferenceAmbience} from './ambience.js';\nimport {createReferenceMountain} from './mountain-complete.js';\n"+s,'assets/xr/xr.js: session/render ownership adapted to IWSDK');
// Keep the original main/volley state evolution and exact gameplay bookkeeping.
const coreNames=['react','success','miss','ooh','respawn','throwWith','ballFace','ballStepAt','snapBall','loadBall','another','stepVolley','update3'];
let core=coreNames.map(n=>functions.get(n)).join('\n');core=core.replace('skin.reset();','').replace('ballStep(dt,false);','ballStepAt(dt,false);').replace('ballStep(dt,true);','ballStepAt(dt,true);');
core=core.replace('skin.step(fdt);','').replace("if(stageName==='hoop') hoopStreak=0;","if(stageName==='hoop'){hoopStreak=0;ctx.onHoopMiss?.();}");

write('src/reference/game-state.js',`export function createReferenceState(ctx){const {T,V,UP,BR,GRAV,S,confetti,whoosh,thump,splash,addCount}=ctx;let stage=ctx.stage,time=0,stageName='goal',hoopStreak=0,restHook=null,waterHook=null;const xrOn=()=>true,outsideView=()=>false,aim={down:false},splats3=[],fxDash=[],VOLLEY_KEYS=['zMax','xMax','shot','shotT','scoredT','missT','mood','moodT','moodNext','idle','restT','hitT','blink','nextBlink','grounded','lastHit','prevZ','prevY','d','dv','wet'],VOLLEY_VECS=['pos','vel','side','axis'],volley=[],VOLLEY_MAX=6;function hit(n,speed,contact){const s=Math.min(1,speed/14);if(s<.05)return;S.axis.copy(n);if(S.d<0)S.d*=.3;S.dv+=4+s*16;S.lastHit=time;thump(s);if(s>.55)S.hitT=.28;}\n${core}\nreturn {react,success,miss,ooh,respawn,throwWith,ballFace,hit,another,volley:()=>volley,clearVolley:()=>{volley.length=0;},setRestHook:fn=>{restHook=fn;},setWater:h=>{waterHook=h;},setStage(s,id){stage=s;stageName=id;volley.length=0;respawn();},step(dt){time+=dt;ctx.time=time;for(let i=0;i<3;i++)update3(dt/3);},get time(){return time;}};}`, 'index.html:headset main ball / volleys / scoring');
// Restore full stage effects and original interaction/audio instead of the selective bridge.
for(const name of ['Goal','Hoop','Window','Cans','Bowling','Bricks','Fair']){
 let text=functions.get('build'+name).replaceAll('assets/xr/motri/bowlingPin.glb','/assets/models/bowlingPin.glb').replaceAll('mat.map.encoding=T.sRGBEncoding','mat.map.colorSpace=T.SRGBColorSpace').replaceAll('"Baloo Bhaijaan 2",Tahoma','"Dahrooj",Tahoma');
 const parsed=espree.parse(text,{ecmaVersion:'latest',sourceType:'module',range:true});
 const deps=[...new Set(scope.analyze(parsed,{ecmaVersion:2022,sourceType:'module'}).globalScope.through.map(r=>r.identifier.name))].filter(x=>!['Math','Array','Float32Array','Object','Set','Map','String','Number','document','localStorage'].includes(x));
 const dynamic=deps.filter(x=>['time','xrLang'].includes(x)),fixed=deps.filter(x=>!dynamic.includes(x));
 write('src/reference/stages/'+name.toLowerCase()+'.js',`export default function create(ctx){const {${fixed.join(',')}}=ctx;${dynamic.length?'let {'+dynamic.join(',')+'}=ctx;':''}\n${text}\nconst stage=build${name}(),update=stage.update;stage.update=function(dt){${dynamic.map(x=>`${x}=ctx.${x};`).join('')}update.call(stage,dt);};return stage;}`, 'index.html:build'+name);
}
s=read('assets/xr/climb3d.js').replace('(() => {','export const createReferenceMountain=(() => {').replace('window.createDahroojClimb3D=','return ');
write('src/reference/mountain-complete.js',s,'assets/xr/climb3d.js');
let confettiNode,challengeNode;function vars(n){if(ts.isVariableDeclaration(n)){if(n.name.getText(ast)==='confetti')confettiNode=n.initializer;if(n.name.getText(ast)==='CHALLENGES')challengeNode=n.initializer;}ts.forEachChild(n,vars)}vars(ast);
write('src/reference/celebration.js',`export function createReferenceConfetti({T,scene,camera,V,BR}){return ${confettiNode.getText(ast)};}\nexport const challenges=${challengeNode.getText(ast)};`,'index.html:confetti/CHALLENGES');
fs.writeFileSync('docs/complete-reference-port-manifest.json' ,JSON.stringify({commit:'c7925b7cd7371b6bb87c44a0743721ad55f177dd',files:records},null,2)+'\n');
