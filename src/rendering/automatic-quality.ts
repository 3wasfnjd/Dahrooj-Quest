import type {World} from '@iwsdk/core';
import {AutoQualityPolicy} from './auto-quality-policy';
import {installQualityHooks,nativeQualityCeiling} from './auto-quality-bridge';
import {createEnvironmentQuality} from './environment-quality';

export function attachAutomaticQuality(world:World,mode:()=>string){
 const {renderer,scene}=world,xr=renderer.xr,environment=createEnvironmentQuality();
 let policy=new AutoQualityPolicy(),session:XRSession|null=null,lastMode='',lastTime=0;
 let nativeScale:number|null=null,ceiling=1,methodAvailable=false,requestFailed=false;
 let referenceArea=0,actualViewportRatio:number|null=null,lastSample=0;
 let lastLayer:{width:number;height:number}|null=null,targetHz=72;
 let entryKind='immersive-vr',entryRatio=1,sessionStart=0;
 const profiles:Record<string,number>={};
 try{
  const saved=JSON.parse(localStorage.getItem('dahrooj.auto-quality.v1')??'{}');
  for(const kind of ['immersive-vr','immersive-ar'])if(typeof saved?.[kind]==='number'&&Number.isFinite(saved[kind]))profiles[kind]=Math.max(.6,Math.min(1,saved[kind]));
 }catch{/* Storage can be unavailable; session adaptation still works. */}
 const reset=()=>{policy=new AutoQualityPolicy();session=null;lastMode='';referenceArea=0;actualViewportRatio=null;methodAvailable=false;requestFailed=false;lastSample=0;lastLayer=null;};
 const uninstall=installQualityHooks({
  layer(_requested,native){try{nativeScale=native();}catch{nativeScale=null;}ceiling=nativeQualityCeiling(nativeScale??NaN)*entryRatio;return ceiling;},
  views(views,current,time){
   if(session!==current){reset();session=current;sessionStart=time;policy.pause(time,4000);}
   lastTime=time;
   if(current.visibilityState!=='visible'){policy.pause(time);return;}
   const nowMode=mode();if(nowMode!==lastMode){lastMode=nowMode;policy.pause(time,4000);}
   policy.sample(time,current.frameRate);
   targetHz=current.frameRate??72;
   methodAvailable=views.length>0&&views.every(view=>typeof view.requestViewportScale==='function');
   if(methodAvailable&&!requestFailed){
    try{for(const view of views)view.requestViewportScale(policy.quality.viewport);}catch{
     requestFailed=true;
     // A partial failure must not leave one eye at a different requested scale.
     for(const view of views)try{view.requestViewportScale(1);}catch{/* Runtime rejected scaling; keep its own viewport. */}
    }
   }
  }
 });
 const original=renderer.render;
 const draw:typeof renderer.render=function(renderScene,camera){
  if(renderScene!==scene||!xr.isPresenting)return original.call(renderer,renderScene,camera);
  // Preserve the foveation=0 condition from the successful headset experiment.
  if(xr.getFoveation()!==0)xr.setFoveation(0);
  if(lastTime-lastSample>1000){
   lastSample=lastTime;
   const area=xr.getCamera().cameras.reduce((sum,c)=>sum+c.viewport.z*c.viewport.w,0);
   if(area>0&&policy.level===0)referenceArea=area;
   actualViewportRatio=referenceArea&&area?Math.sqrt(area/referenceArea):null;
   const layer=xr.getBaseLayer();if(layer)lastLayer={width:'textureWidth' in layer?layer.textureWidth:layer.framebufferWidth,height:'textureHeight' in layer?layer.textureHeight:layer.framebufferHeight};
  }
  return environment.draw(scene,policy.quality.environment,()=>original.call(renderer,renderScene,camera));
 };
 renderer.render=draw;
 const stop=world.onXRFrame(()=>{
  // A missing tracking pose skips the manager hook; discard the resulting gap.
  if(xr.getSession()?.visibilityState!=='visible')policy.pause(lastTime);
 });
 const end=()=>{
  // Unsupported/ignored dynamic scaling cannot change allocation mid-session.
  // Learn a lower entry resolution for the next VR/AR session instead.
  if(lastTime-sessionStart>8000){
   const ineffective=!methodAvailable||requestFailed||actualViewportRatio===null||actualViewportRatio>.98;
   if(policy.level>0&&ineffective)profiles[entryKind]=Math.max(.6,entryRatio*policy.quality.viewport);
   else if(policy.level===0&&lastTime-sessionStart>25000)profiles[entryKind]=Math.min(1,entryRatio+.1);
   try{localStorage.setItem('dahrooj.auto-quality.v1',JSON.stringify(profiles));}catch{/* Keep the current session usable. */}
  }
  session=null;policy.pause(lastTime);
 };xr.addEventListener('sessionend',end);
 const lost=()=>policy.pause(lastTime,5000);renderer.domElement.addEventListener('webglcontextlost',lost);
 function report(){return {mode:'automatic',level:policy.level,quality:policy.quality,nativeScale,layerScaleCeiling:ceiling,entryKind,entryRatio,nextEntryRatios:{...profiles},
  requestedViewportScale:policy.quality.viewport,observedViewportRatio:actualViewportRatio,
  dynamicViewportMethodAvailable:methodAvailable,viewportRequestFailed:requestFailed,
  viewportEffect:policy.quality.viewport===1?'not-tested':actualViewportRatio!==null&&actualViewportRatio<.98?'observed':'not-observed',
  targetHz,metric:'XR frame cadence, not GPU duration',changes:policy.changes,layer:lastLayer};}
 return {report,prepare(kind:string){if(!xr.isPresenting){entryKind=kind;entryRatio=profiles[kind]??1;}},dispose(){stop();uninstall();xr.removeEventListener('sessionend',end);renderer.domElement.removeEventListener('webglcontextlost',lost);if(renderer.render===draw)renderer.render=original;environment.dispose();}};
}
