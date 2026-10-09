import {CanvasTexture,Group,Mesh,MeshBasicMaterial,NoBlending,PlaneGeometry,SRGBColorSpace,Vector3,type World,type PerspectiveCamera,type WebXRManager} from '@iwsdk/core';
import type {CompleteGame} from '../reference/complete-game.js';
import type {DiagnosticOptions} from './diagnostic-options';
import {DIAGNOSTIC_PRESETS,initialDiagnosticView,withRenderIsolation,type DiagnosticPreset} from './diagnostic-isolation';

type XRRenderer = WebXRManager & {isMultiview?:boolean};
type Observation = 'flicker-observed'|'no-flicker-observed'|'uncertain';
type Run = {key:string;preset:DiagnosticPreset;mode:string;menu:string;kind:string|null;weather:unknown;startedAt:string;intervals:number[];renderMs:number[];frames:number;drawCalls:number;triangles:number;xr:unknown};
const limit=720;
function summary(values:number[]){
 const sorted=[...values].sort((a,b)=>a-b);
 return {samples:values.length,mean:values.length?values.reduce((a,b)=>a+b,0)/values.length:null,p95:sorted.length?sorted[Math.floor(sorted.length*.95)]:null};
}

/** Imported only with ?xrdiag=1. No gameplay commands, storage or automatic upload. */
export function attachRenderDiagnostics(world:World,game:CompleteGame,options:DiagnosticOptions){
 const {renderer,scene,camera}=world,xr=renderer.xr as XRRenderer;
 const initial=initialDiagnosticView(location.search);
 let preset:DiagnosticPreset=initial.preset,badgeShown=initial.badgeShown,leftDown=false,rightDown=false,lastTime:number|undefined,lastBadge='',build:unknown=null,lastXR:unknown=null;
 const runs:Run[]=[],observations:unknown[]=[],errors:unknown[]=[];
 let lastState:ReturnType<typeof stateRecord>|null=null;
 void fetch('/build.json').then(r=>r.ok?r.json():null).then(value=>{build=value;}).catch(()=>{});
 const panel=document.createElement('section');panel.id='render-diagnostics';panel.dir='rtl';
 panel.style.cssText='max-width:780px;width:100%;padding:18px;margin:16px 0;border:1px solid #90949a;border-radius:12px;background:#34373d;color:#eee';
 panel.innerHTML=`<strong>تشخيص الرسم — اختياري</strong>
 <p>داخل النظارة: نقرة العصا اليسرى تغيّر المقارنة؛ نقرة العصا اليمنى تسجّل أنك شاهدت الوميض. أزرار Y وX وB للقوائم كالمعتاد. إخفاء العناصر بصري فقط؛ الاصطدامات مستمرة.</p>
 <label>المقارنة <select id="diag-preset"></select></label>
 <label>العينان <select id="diag-stereo"><option value="auto">تلقائي / Multiview إن توفر</option><option value="separate">رسم منفصل لكل عين</option></select></label>
 <label>تنعيم الحواف <select id="diag-aa"><option value="1">مفعّل</option><option value="0">معطّل</option></select></label>
 <button id="diag-reload">تطبيق إعدادات العينين والتنعيم وإعادة التحميل</button>
 <label><input id="diag-badge" type="checkbox" checked> إظهار شريط التشخيص في النظارة</label>
 <p>إخفاء الشريط لا يعطّل نقرتي العصا. لتغيير مسار العينين اخرج من جلسة XR أولًا. في AR لا نضيف ثلجًا أو طبيعة غير موجودة.</p>
 <button id="diag-flicker">شاهدت الوميض</button> <button id="diag-clear">لم أشاهد الوميض</button> <button id="diag-unknown">غير متأكد</button>
 <button id="diag-export">تنزيل تقرير التشخيص</button> <button id="diag-exit">إيقاف التشخيص وإعادة التحميل</button>
 <output id="diag-status" style="display:block;margin-top:12px"></output>`;
 panel.querySelectorAll('select,button').forEach(node=>(node as HTMLElement).style.cssText='font:inherit;font-size:16px;padding:7px;margin:5px;border-radius:6px;background:#ddd;color:#222;max-width:100%');
 document.getElementById('gate')!.append(panel);
 const find=<T extends HTMLElement>(id:string)=>panel.querySelector<T>('#'+id)!;
 const picker=find<HTMLSelectElement>('diag-preset');
 for(const item of DIAGNOSTIC_PRESETS){const option=document.createElement('option');option.value=item.id;option.textContent=item.label;picker.add(option);}
 find<HTMLSelectElement>('diag-stereo').value=options.stereo;
 find<HTMLSelectElement>('diag-aa').value=options.antialias?'1':'0';
 find<HTMLInputElement>('diag-badge').checked=badgeShown;

 const canvas=document.createElement('canvas');canvas.width=1200;canvas.height=180;
 const context=canvas.getContext('2d')!,texture=new CanvasTexture(canvas);texture.colorSpace=SRGBColorSpace;texture.generateMipmaps=false;
 const material=new MeshBasicMaterial({map:texture,transparent:true,blending:NoBlending,depthTest:false,depthWrite:false,toneMapped:false,fog:false});
 const badge=new Group();badge.name='xr-diagnostic-badge';badge.renderOrder=2000;
 const face=new Mesh(new PlaneGeometry(.85,.1275),material);face.frustumCulled=false;badge.add(face);badge.visible=false;scene.add(badge);
 const eye=new Vector3();
 function label(){return DIAGNOSTIC_PRESETS.find(p=>p.id===preset)!.label;}
 function updateBadge(){
  const state=game.inspectRendering(),text=`${label()} | ${state.mode} | ${state.menu}`;
  if(text!==lastBadge){lastBadge=text;context.fillStyle='#363a40';context.fillRect(0,0,1200,180);context.direction='rtl';context.textAlign='center';context.fillStyle='#ddd';context.font='700 38px Dahrooj, sans-serif';context.fillText(text,600,65);context.font='28px Dahrooj, sans-serif';context.fillText('نقرة اليسار: المقارنة التالية • نقرة اليمين: شاهدت الوميض',600,130);texture.needsUpdate=true;}
  camera.getWorldPosition(eye);camera.getWorldQuaternion(badge.quaternion);
  badge.position.set(0,.32,-1.1).applyQuaternion(badge.quaternion).add(eye);
  badge.visible=badgeShown&&xr.isPresenting;
 }
 function choose(id:string){
  if(!DIAGNOSTIC_PRESETS.some(item=>item.id===id))return;
  preset=id as DiagnosticPreset;picker.value=preset;lastTime=undefined;updateBadge();
  find('diag-status').textContent=label();
 }
 picker.onchange=()=>choose(picker.value);
 find<HTMLInputElement>('diag-badge').onchange=()=>{badgeShown=find<HTMLInputElement>('diag-badge').checked;updateBadge();};
 function reload(disable=false){
  if(xr.isPresenting){find('diag-status').textContent='اخرج من جلسة XR قبل إعادة التحميل.';return;}
  const url=new URL(location.href);
  if(disable){for(const key of ['xrdiag','xrdiagStereo','xrdiagAA','xrdiagPreset','xrdiagBadge'])url.searchParams.delete(key);}
  else{url.searchParams.set('xrdiag','1');url.searchParams.set('xrdiagStereo',find<HTMLSelectElement>('diag-stereo').value);url.searchParams.set('xrdiagAA',find<HTMLSelectElement>('diag-aa').value);url.searchParams.set('xrdiagPreset',preset);url.searchParams.set('xrdiagBadge',badgeShown?'1':'0');}
  location.assign(url.href);
 }
 find('diag-reload').onclick=()=>reload();find('diag-exit').onclick=()=>reload(true);
 function xrSnapshot(){
  const session=xr.getSession(),views=xr.getCamera().cameras,layer=xr.getBaseLayer();
  return {requestedStereo:options.stereo,actualMultiview:xr.isMultiview===true,oculusMultiviewAvailable:renderer.extensions.has('OCULUS_multiview'),viewCount:views.length,
   layerType:layer?.constructor.name??null,foveation:xr.getFoveation()??null,layerFoveation:layer&&'fixedFoveation' in layer?layer.fixedFoveation:null,environmentBlendMode:session?.environmentBlendMode??null,
   depthNear:session?.renderState.depthNear??null,depthFar:session?.renderState.depthFar??null,
   views:views.map((view,index)=>({index,viewport:view.viewport?.toArray()??null,position:new Vector3().setFromMatrixPosition(view.matrixWorld).toArray(),projection:view.projectionMatrix.toArray(),near:(view as PerspectiveCamera).near,far:(view as PerspectiveCamera).far})),
   context:renderer.getContext().getContextAttributes(),depthBits:renderer.getContext().getParameter(renderer.getContext().DEPTH_BITS),targetSamples:renderer.getRenderTarget()?.samples??null};
 }
 function stateRecord(){const {stage:_stage,nature:_nature,...state}=game.inspectRendering();return {preset,...state};}
 function observe(observation:Observation){
  if(!lastState){find('diag-status').textContent='ابدأ تجربة VR أو MR قبل تسجيل النتيجة.';return;}
  observations.push({time:new Date().toISOString(),observation,state:lastState,xr:lastXR});if(observations.length>96)observations.shift();
  find('diag-status').textContent=`حُفظت ملاحظتك محليًا في هذا التقرير (${observations.length}). نزّل التقرير قبل إعادة التحميل.`;
 }
 find('diag-flicker').onclick=()=>observe('flicker-observed');find('diag-clear').onclick=()=>observe('no-flicker-observed');find('diag-unknown').onclick=()=>observe('uncertain');
 const stopFrame=world.onXRFrame((frame,_delta,time)=>{
  const session=xr.getSession();
  if(session?.visibilityState!=='visible'||!frame.getViewerPose(xr.getReferenceSpace()!)){lastTime=undefined;leftDown=rightDown=false;return;}
  const sources=Array.from(session.inputSources);
  const left=!!sources.find(s=>s.handedness==='left')?.gamepad?.buttons[3]?.pressed,right=!!sources.find(s=>s.handedness==='right')?.gamepad?.buttons[3]?.pressed;
  if(left&&!leftDown)choose(DIAGNOSTIC_PRESETS[(DIAGNOSTIC_PRESETS.findIndex(p=>p.id===preset)+1)%DIAGNOSTIC_PRESETS.length].id);
  if(right&&!rightDown)observe('flicker-observed');leftDown=left;rightDown=right;
  const state=stateRecord(),key=JSON.stringify(state);let run=runs.at(-1);
  if(!run||run.key!==key){run={...state,key,startedAt:new Date().toISOString(),intervals:[],renderMs:[],frames:0,drawCalls:0,triangles:0,xr:null};runs.push(run);if(runs.length>80)runs.shift();lastTime=undefined;}
  if(lastTime!==undefined&&time>lastTime){run.intervals.push((time-lastTime)*1000);if(run.intervals.length>limit)run.intervals.shift();}lastTime=time;
 });
 const originalRender=renderer.render;
 // Instrumentation is installed only while explicitly opted in. Never render the
 // world twice or clear the shared XR depth buffer between the two eyes.
 const diagnosticRender:typeof renderer.render=function(renderScene,renderCamera){
  if(renderScene!==scene||!xr.isPresenting||xr.getSession()?.visibilityState!=='visible')return originalRender.call(renderer,renderScene,renderCamera);
  const start=performance.now(),state=game.inspectRendering();
  const foveation=preset==='no-foveation'?0:.6;if(xr.getFoveation()!==foveation)xr.setFoveation(foveation);
  updateBadge();
  const changed=JSON.stringify(lastState)!==JSON.stringify(stateRecord());lastState=stateRecord();
  try{return withRenderIsolation(scene,preset,{...state,menu:scene.getObjectByName('xr-menu-layer'),badge},()=>originalRender.call(renderer,renderScene,renderCamera));}
  finally{
   const run=runs.at(-1);if(run){run.frames++;run.renderMs.push(performance.now()-start);if(run.renderMs.length>limit)run.renderMs.shift();run.drawCalls=renderer.info.render.calls;run.triangles=renderer.info.render.triangles;}
   // Sample capability/eye matrices once per second, not gl.getParameter per draw.
   if(changed||!run||run.frames%72===1){lastXR=xrSnapshot();if(run)run.xr=lastXR;}
  }
 };
 renderer.render=diagnosticRender;
 const onEnd=()=>{badge.visible=false;lastTime=undefined;leftDown=rightDown=false;xr.setFoveation(.6);};
 xr.addEventListener('sessionend',onEnd);
 const recordError=(type:string,detail:string)=>{errors.push({time:new Date().toISOString(),type,detail:detail.slice(0,3000),state:lastState});if(errors.length>32)errors.shift();};
 const lost=()=>recordError('context-lost','WebGL context lost'),restored=()=>recordError('context-restored','WebGL context restored');
 renderer.domElement.addEventListener('webglcontextlost',lost);renderer.domElement.addEventListener('webglcontextrestored',restored);
 const previousShaderError=renderer.debug.onShaderError;
 const shaderError:NonNullable<typeof previousShaderError>=(gl,program,vertex,fragment)=>{
  recordError('shader-error',[gl.getProgramInfoLog(program),gl.getShaderInfoLog(vertex),gl.getShaderInfoLog(fragment)].join('\n'));
  if(previousShaderError)previousShaderError(gl,program,vertex,fragment);else console.error('XR diagnostic shader error',errors.at(-1));
 };
 renderer.debug.onShaderError=shaderError;
 function report(){return {schema:1,createdAt:new Date().toISOString(),build,options,userAgent:navigator.userAgent,
  hardwareConfirmation:null,conclusion:'No automatic claim about headset flicker. User observations are separate from software measurements.',
  sampleLimitPerRun:limit,runLimit:80,observationLimit:96,lastXR,runs:runs.map(({key:_key,intervals,renderMs,...run})=>({...run,frameIntervalMs:summary(intervals),cpuRenderMs:summary(renderMs)})),observations,errors};}
 function download(){const href=URL.createObjectURL(new Blob([JSON.stringify(report(),null,2)],{type:'application/json'})),a=document.createElement('a');a.href=href;a.download='dahrooj-render-diagnostics.json';a.click();setTimeout(()=>URL.revokeObjectURL(href),1000);}
 find('diag-export').onclick=download;
 choose(initial.preset);
 return {report,download,choose,observe,dispose(){stopFrame();xr.removeEventListener('sessionend',onEnd);if(renderer.render===diagnosticRender)renderer.render=originalRender;if(renderer.debug.onShaderError===shaderError)renderer.debug.onShaderError=previousShaderError;renderer.domElement.removeEventListener('webglcontextlost',lost);renderer.domElement.removeEventListener('webglcontextrestored',restored);xr.setFoveation(.6);scene.remove(badge);face.geometry.dispose();material.dispose();texture.dispose();panel.remove();}};
}
