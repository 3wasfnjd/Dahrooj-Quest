type Hooks={layer:(requested:number,native:()=>number)=>number;views:(views:readonly XRView[],session:XRSession,time:number)=>void};
let hooks:Hooks|null=null;
export function installQualityHooks(value:Hooks){hooks=value;return ()=>{if(hooks===value)hooks=null;};}
// Called by a guarded build hook, before allocation / before either eye viewport
// is read. No renderer monkey-patching and no changes to projection matrices.
export function automaticLayerScale(requested:number,native:()=>number){return hooks?hooks.layer(requested,native):requested;}
export function automaticViews(views:readonly XRView[],session:XRSession,time:number){hooks?.views(views,session,time);}
export function automaticQualityEnabled(search:string){const query=new URLSearchParams(search);return query.get('xrquality')==='auto'&&query.get('xrdiag')!=='1';}
export function nativeQualityCeiling(native:number){return Number.isFinite(native)&&native>0?Math.min(2,Math.max(1,native)):1;}
