import * as Core from '@iwsdk/core';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {createReferenceXR} from './xr-runtime.js';
import {createReferenceSounds} from './sounds.js';
import {createReferenceState} from './game-state.js';
import {createReferenceConfetti,challenges} from './celebration.js';
import {stageArt} from './stage-art.js';
import {drawReferenceFace} from './face.js';
import climbCore from './summit-core.js';
import goal from './stages/goal.js';import hoop from './stages/hoop.js';import windowStage from './stages/window.js';import cans from './stages/cans.js';import bowling from './stages/bowling.js';import bricks from './stages/bricks.js';import fair from './stages/fair.js';
const T={...Core,GLTFLoader},builders={goal,hoop,window:windowStage,cans,bowling,bricks,fair};
export function createCompleteGame(world,store){
 const {scene,camera,renderer}=world,V=(x=0,y=0,z=0)=>new T.Vector3(x,y,z),UP=V(0,1,0),BR=.24,GRAV=13;
 const S={pos:V(0,BR+1.2,0),vel:V(),side:V(),axis:UP.clone(),d:0,dv:0,shot:false,shotT:0,zMax:6,xMax:16,scoredT:0,missT:0,mood:null,moodT:0,moodNext:null,idle:0,restT:0,hitT:0,blink:0,nextBlink:2,grounded:false,lastHit:0,prevZ:0,prevY:0};
 const hemi=new T.HemisphereLight(0xfff8ee,0xd8cbb8,.95),sun=new T.DirectionalLight(0xffffff,.75);sun.position.set(3,10,-4);sun.target.position.set(0,0,-9);scene.add(hemi,sun,sun.target);
 const ground=new T.Mesh(new T.PlaneGeometry(80,80),new T.ShadowMaterial({opacity:.17}));ground.rotation.x=-Math.PI/2;ground.receiveShadow=true;scene.add(ground);
 const sound=createReferenceSounds(),confetti=createReferenceConfetti({T,scene,camera,V,BR}),counts={goal:0,hoop:0,window:0,cans:0,bowling:0,bricks:0,fair:0,climb:0};
 let mode='goal',style=store.data.style,stage=null,runtime=null,toastMessage='',toastUntil=0,hoopStreak=0,focused=false,requested='immersive-vr';const cache=new Map(),samples=[],dtSamples=[];
 const toast=text=>{toastMessage=text;toastUntil=performance.now()+2300;};
 const chProgress=(id,value)=>{const c=challenges.find(c=>c.id===id);if(!c)return;const before=store.data.challenges[id]||0;if(value<=before)return;store.data.challenges[id]=Math.min(c.goal,value);store.touch();if(before<c.goal&&value>=c.goal){toast('✓ '+(store.data.language==='en'?c.en:c.title));sound.chime();}};
 const ctx={T,scene,camera,V,UP,BR,GRAV,S,confetti,INK:0x2c2d3d,COL:{ink:'#2c2d3d',coral:'#e2603f'},time:0,xrLang:store.data.language,counts,chState:store.data.challenges,xrOnNow:()=>!!runtime?.presenting,ar:n=>String(n).replace(/\d/g,d=>'٠١٢٣٤٥٦٧٨٩'[d]),toast,chProgress,...sound,
 addCount(m,reset){counts[m]=reset?0:counts[m]+1;if(m==='goal'&&!reset)chProgress('keeper3',(store.data.challenges.keeper3||0)+1);if(m==='hoop')chProgress('hoop3',++hoopStreak);},pushBody(){} };
 const state=createReferenceState(ctx);Object.assign(ctx,state,stageArt({...ctx,hit:state.hit}));const miss=state.miss;ctx.miss=()=>{if(mode==='hoop')hoopStreak=0;miss();};
 function setMode(id){if(!builders[id])return;state.clearVolley();if(stage)stage.grp.visible=false;mode=id;if(!cache.has(id)){ctx.audio=sound.context;cache.set(id,builders[id](ctx));}stage=cache.get(id);stage.grp.visible=true;state.setStage(stage,id);}
 function setStyle(id){if(!['jelly','fabric','clay','fur','bubble'].includes(id))return;style=id;store.data.style=id;if(!store.data.stylesUsed.includes(id))store.data.stylesUsed.push(id);chProgress('styles5',store.data.stylesUsed.length);store.touch();}
 ctx.onHoopMiss=()=>{hoopStreak=0;};
 function focus(on){if(focused===on)return;focused=on;sound.focus(on);if(!on)void store.flush();}
 const g={T,scene,camera,renderer,player:world.player,getSession:()=>renderer.xr.getSession(),S,V,UP,BR,GRAV,ground,hemi,sun,lineMat:ctx.lineMat,...sound,...state,focus,
 language:()=>store.data.language,stage:()=>stage,stageName:()=>mode,mode:()=>mode,style:()=>style,setMode,setStyle,drawFace:drawReferenceFace,
 step(dt){ctx.xrLang=store.data.language;state.step(dt);confetti.update(dt);},render(){},resize(){},bump:sound.thump,audio:()=>sound.context,
 shootStage:(o,p,d)=>!!stage?.shoot?.(o,p,d),toast,climbCore,
 climbEvent(e){if(['pop','stomp','kill'].includes(e.type))sound.startPopSound();if(['stomp','kill'].includes(e.type))chProgress('monsters15',(store.data.challenges.monsters15||0)+1);if(e.type==='checkpoint'){sound.chime();toast('نقطة حفظ ✓');}if(e.type==='summit'){sound.chime();ctx.addCount('climb');chProgress('summit1',1);const m=Math.floor(e.time/60),s=Math.round(e.time%60);toast(`وصلت القمة في ${m?ctx.ar(m)+' د ':''}${ctx.ar(s)} ث`);}},
 recall(){if(S.shot&&S.scoredT<=0&&S.missT<=0&&mode==='hoop')hoopStreak=0;state.respawn();},canHold:()=>!S.shot&&!S.scoredT&&!S.missT,
 challenges:()=>challenges.map(c=>({...c,value:Math.min(c.goal,store.data.challenges[c.id]||0)})),chAdd:id=>chProgress(id,(store.data.challenges[id]||0)+1),
 resetChallenges(){for(const k of Object.keys(store.data.challenges))delete store.data.challenges[k];store.data.stylesUsed=[];hoopStreak=0;store.touch();},
 setLang(lang){store.data.language=lang;store.touch();},texts:()=>({count:counts[mode],toast:performance.now()<toastUntil?toastMessage:'',title:''}),paper:()=>({jelly:'#ddd2c1',fabric:'#bccab1',clay:'#dcae88',fur:'#e3bcae',bubble:'#b1cade'}[style]),
 onExit(){focus(false);for(const s of cache.values())s.grp.visible=false;document.getElementById('gate').hidden=false;void store.flush();},popSound:sound.startPopSound};
 runtime=createReferenceXR(g);
 world.onXRFrame((frame,delta,time)=>{
  if(!runtime.presenting){setMode(mode);void runtime.enter(requested).catch(e=>{console.error(e);void renderer.xr.getSession()?.end();});document.getElementById('gate').hidden=true;}
  runtime.frame(time*1000,frame);
  for(const side of ['left','right']){const a=world.input.xr.visualAdapters.controller[side];if(a.visual)a.visual.model.visible=false;}
  if(focused){dtSamples.push(delta*1000);if(dtSamples.length>720)dtSamples.shift();if(samples.length%72===0){samples.push({time:performance.now(),drawCalls:renderer.info.render.calls,triangles:renderer.info.render.triangles});}else samples.push(null);if(samples.length>720)samples.shift();}
 });
 function report(){const sorted=[...dtSamples].sort((a,b)=>a-b),mean=dtSamples.reduce((a,b)=>a+b,0)/(dtSamples.length||1);return {hardwareTested:false,renderer:'WebGL2',physics:'Original reference solvers',samples:dtSamples.length,meanFrameMs:mean,p95FrameMs:sorted[Math.floor(sorted.length*.95)]??null,fps:mean?1000/mean:null,drawCalls:renderer.info.render.calls,triangles:renderer.info.render.triangles,memory:performance.memory?.usedJSHeapSize??null};}
 return {world,store,S,state,g,ctx,runtime,counts,setMode,setStyle,report,get focused(){return focused;},start(mode){requested=mode;sound.unlock();world.launchXR({sessionMode:mode,features:{hitTest:mode==='immersive-ar',planeDetection:mode==='immersive-ar',anchors:mode==='immersive-ar',handTracking:false,layers:true}});},export(){const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([JSON.stringify(report(),null,2)],{type:'application/json'}));a.download='dahrooj-performance.json';a.click();setTimeout(()=>URL.revokeObjectURL(a.href),1000);}};
}
