import {AlwaysDepth,LessEqualDepth,type Material,type Object3D,type Scene} from '@iwsdk/core';

export const DIAGNOSTIC_PRESETS = [
 {id:'baseline',label:'المرجع: الرسم المعتاد'},
 {id:'no-particles',label:'إخفاء الثلج والمطر المتساقط'},
 {id:'no-snow-ground',label:'إخفاء طبقة الثلج الأرضية'},
 {id:'no-nature',label:'إخفاء الطبيعة فقط'},
 {id:'no-stage',label:'إخفاء مجسمات النمط فقط'},
 {id:'no-stage-lines',label:'إخفاء الشبك وخطوط الحواف فقط'},
 {id:'no-menus',label:'إخفاء القوائم فقط'},
 {id:'menus-only',label:'القوائم وحدها'},
 {id:'world-depth',label:'القوائم بعمق العالم العادي'},
 {id:'no-menu-depth',label:'تعطيل عمق القوائم مؤقتًا'},
 {id:'no-foveation',label:'إلغاء خفض دقة أطراف الصورة'},
] as const;
export type DiagnosticPreset = typeof DIAGNOSTIC_PRESETS[number]['id'];
export interface RenderTargets {stage?:Object3D; nature?:Object3D; menu?:Object3D; badge?:Object3D}
type Renderable = Object3D & {material?:Material|Material[];isLine?:boolean;isSprite?:boolean;isMesh?:boolean;isPoints?:boolean};

export function belongsTo(object:Object3D,root?:Object3D):boolean{
 if(!root)return false;
 for(let node:Object3D|null=object;node;node=node.parent)if(node===root)return true;
 return false;
}

// Apply ONLY during the render call, then restore in finally. Simulation, input,
// mode transitions and visibility set by the game never inherit a diagnostic mask.
export function withRenderIsolation<T>(scene:Scene,preset:DiagnosticPreset,targets:RenderTargets,draw:()=>T):T{
 const hidden=new Map<Object3D,boolean>(),materials=new Map<Material,{depthTest:boolean;depthWrite:boolean;depthFunc:Material['depthFunc']}>();
 const hide=(object?:Object3D)=>{if(object&&!hidden.has(object)){hidden.set(object,object.visible);object.visible=false;}};
 try{
  if(preset==='no-particles')hide(scene.getObjectByName('xr-weather-particles'));
  if(preset==='no-snow-ground')hide(scene.getObjectByName('xr-snow-ground'));
  if(preset==='no-nature')hide(targets.nature);
  if(preset==='no-stage')hide(targets.stage);
  if(preset==='no-menus')hide(targets.menu);
  if(preset==='no-stage-lines')targets.stage?.traverse(object=>{if((object as Renderable).isLine)hide(object);});
  if(preset==='menus-only')scene.traverse(object=>{
   const item=object as Renderable;
   if((item.isMesh||item.isLine||item.isPoints||item.isSprite)&&!belongsTo(item,targets.menu)&&!belongsTo(item,targets.badge))hide(item);
  });
  if(preset==='world-depth'||preset==='no-menu-depth')targets.menu?.traverse(object=>{
   const source=(object as Renderable).material;
   for(const material of source?(Array.isArray(source)?source:[source]):[]){
    if(materials.has(material))continue;
    materials.set(material,{depthTest:material.depthTest,depthWrite:material.depthWrite,depthFunc:material.depthFunc});
    if(preset==='no-menu-depth')material.depthTest=material.depthWrite=false;
    else if(material.depthFunc===AlwaysDepth)material.depthFunc=LessEqualDepth;
   }
  });
  return draw();
 }finally{
  for(const [object,visible] of hidden)object.visible=visible;
  for(const [material,values] of materials)Object.assign(material,values);
 }
}
